package Apache2::HTML::Detergent;

use 5.010;
use strict;
use warnings FATAL => 'all';

# Apache stuff

use base qw(Apache2::Filter);

use Apache2::Const -compile => qw(OK DECLINED HTTP_BAD_GATEWAY);

use Apache2::Log         ();
use Apache2::FilterRec   ();
use Apache2::RequestRec  ();
use Apache2::RequestUtil ();
use Apache2::Connection  ();
use Apache2::Response    ();
use Apache2::ServerRec   ();
use Apache2::CmdParms    ();
use Apache2::Module      ();
use Apache2::Directive   ();
use Apache2::ModSSL      ();

use APR::Table   ();
use APR::Bucket  ();
use APR::Brigade ();

# my contribution
use Apache2::TrapSubRequest ();

# non-Apache stuff

use URI             ();
use IO::Scalar      ();
use HTML::Detergent ();
use Apache2::HTML::Detergent::Config;

=head1 NAME

Apache2::HTML::Detergent - Clean the gunk off HTML documents on the fly

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    # httpd.conf or .htaccess

    # The + prefix forces the module to preload
    PerlOutputFilterHandler +Apache2::HTML::Detergent

    # These default matching content types can be overridden
    DetergentTypes text/html application/xhtml+xml

    # This invocation just pulls the matching element into a new document
    DetergentMatch /xpath/statement

    # An optional second argument can specify an XSLT stylesheet
    DetergentMatch /other/xpath/statement /path/to/transform.xsl

    # Configure <link> and <meta> tags

    DetergentLink relvalue http://href

    DetergentMeta namevalue "Content"

    # that's it!

=head1 DESCRIPTION

=cut

sub handler : FilterRequestHandler {
    my $f  = shift;
    my $r = $f->r;
    my $c = $r->connection;

    my $class = __PACKAGE__ . '::Config';

    my $config = Apache2::Module::get_config
        ($class, $r->server, $r->per_dir_config) ||
            Apache2::Module::get_config($class, $r->server);

    unless ($config) {
        $r->log->crit("Cannot find config from $class!");
        return Apache2::Const::DECLINED;
    }

    # store the context; initial content type, payload
    my $ctx;
    unless ($ctx = $f->ctx) {
        # turns out some things don't have a type!
        $ctx = [$r->content_type || 'application/octet-stream', ''];
        $f->ctx($ctx);
    }

    # get this before changing it
    my $type = $ctx->[0];

    unless ($config->type_matches($type)) {
        $r->log->debug("$type doesn't match");
        return Apache2::Const::DECLINED;
    }

    # application/xml is the most reliable content type to
    # deliver to browsers that use XSLT.
    if ($config->xslt) {
        $r->log->debug("forcing $type -> application/xml");
        $r->content_type('application/xml; charset=utf-8');
    }

    if ($r->is_initial_req and $r->status == 200) {

        my $content = $ctx->[1];
        $content    = '' unless defined $content;
        while ($f->read(my $buf, 4096)) {
            $content .= $buf;
        }

        if ($f->seen_eos) {

            # this is where we hack the content

            # set up the input callbacks with subreq voodoo
            my $icb = $config->callback;
            $icb->register_callbacks([
                sub {
                    # MATCH
                    return $_[0] =~ m!^/!;
                },
                sub {
                    # OPEN
                    my $uri  = shift;
                    $r->log->debug("opening XML at $uri");
                    my $subr = $r->lookup_uri($uri);
                    my $data = '';
                    $subr->run_trapped(\$data);
                    my $io = IO::Scalar->new(\$data);
                    # HACK
                    \$io;
                },
                sub {
                    # READ
                    my ($io, $len) = @_;
                    # HACK
                    my $fh = $$io;
                    my $buf;
                    $fh->read($buf, $len);
                    $buf;
                },
                sub {
                    # CLOSE
                    1;
                },
            ]);

            my $scrubber = HTML::Detergent->new($config);

            #$r->log->debug($content);

            # $r->headers_in->get('Host') || $r->get_server_name;
            my $host   = $r->hostname;
            my $scheme = $c->is_https ? 'https' :  'http';
            my $port   = $r->get_server_port;

            my $uri = URI->new
                (sprintf '%s://%s:%d%s', $scheme,
                 $host, $port, $r->unparsed_uri)->canonical;
            $r->log->debug($uri);

            if ($type =~ m!/.*xml!i) {
                $r->log->debug("Attempting to use XML parser for $uri");
                $content = eval {
                    XML::LibXML->load_xml
                          (string => $content, recover => 1, no_network => 1) };
                if ($@) {
                    $r->log->error($@);
                    return Apache2::Const::HTTP_BAD_GATEWAY;
                }
            }

            my $doc = $scrubber->process($content, $uri);
            $doc->setEncoding('utf-8');

            if (defined $config->xslt) {
                my $pi = $doc->createProcessingInstruction
                    ('xml-stylesheet', sprintf 'type="text/xsl" href="%s"',
                     $config->xslt);

                if ($doc->documentElement) {
                    $doc->insertBefore($pi, $doc->documentElement);
                }
            }
            else {
                $r->content_type(sprintf '%s; charset=utf-8', $type);
            }
            #$r->log->debug($r->content_encoding || 'identity');
            #$r->log->debug($r->headers_in->get('Content-Encoding'));

            # reuse content
            $content = $doc->toString(1);
            use bytes;
            #        $r->log->debug(bytes::length($buf));
            $r->set_content_length(bytes::length($content));

            $f->print($content);
        }
        else {
            # XXX probably not necessary
            $ctx->[1] = $content;
        }

        Apache2::Const::OK;
    }

    #$f->print($doc->toString(1));
    Apache2::Const::DECLINED;
}

=head1 AUTHOR

Dorian Taylor, C<< <dorian at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-apache2-html-detergent at rt.cpan.org>, or through the web
interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Apache2-HTML-Detergent>.
I will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Apache2::HTML::Detergent


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Apache2-HTML-Detergent>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Apache2-HTML-Detergent>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Apache2-HTML-Detergent>

=item * Search CPAN

L<http://search.cpan.org/dist/Apache2-HTML-Detergent/>

=back


=head1 SEE ALSO

=over 4

=item L<HTML::Detergent>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Dorian Taylor.

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License.  You may
obtain a copy of the License at
L<http://www.apache.org/licenses/LICENSE-2.0>.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.

=cut

1; # End of Apache2::HTML::Detergent
