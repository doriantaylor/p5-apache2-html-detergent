package Apache2::HTML::Detergent;

use 5.010;
use strict;
use warnings FATAL => 'all';

# Apache stuff

use Apache2::Const -compile => qw(OK OR_ALL ITERATE TAKE12 TAKE2 );

use Apache2::Filter     ();
use Apache2::RequestRec ();
use Apache2::CmdParms   ();
use Apache2::Module     ();
use Apache2::Directive  ();
use APR::Table          ();

# non-Apache stuff

use HTML::Detergent         ();
use HTML::Detergent::Config ();

=head1 NAME

Apache2::HTML::Detergent - Clean the gunk off HTML documents on the fly

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

our @DIRECTIVES = (
    {
        name         => 'DetergentTypes',
        req_override => Apache2::Const::OR_ALL,
        args_how     => Apache2::Const::ITERATE,
        errmsg       => 'DetergentTypes type/1 [ type/2 ...]',
        func         => sub {
            my ($self, $params, $type) = @_;
            $self->{types}{$type} = 1;
        },
    },
    {
        name         => 'DetergentMatch',
        req_override => Apache2::Const::OR_ALL,
        args_how     => Apache2::Const::TAKE12,
        errmsg       => 'DetergentMatch /xpath [ /uri/path/of.xsl ]',
        func         => sub {
            my ($self, $params, $xpath, $xsl) = @_;
            $self->{match}{$xpath} = $xsl;
        },
    },
    {
        name         => 'DetergentLink',
        req_override => Apache2::Const::OR_ALL,
        args_how     => Apache2::Const::TAKE2,
        errmsg       => 'DetergentLink rel href',
        func         => sub {
            my ($self, $params, $rel, $href) = @_;
            my $x = $self->{link}{$rel} ||= [];
            push @$x, $href;
        },
    },
    {
        name         => 'DetergentMeta',
        req_override => Apache2::Const::OR_ALL,
        args_how     => Apache2::Const::TAKE2,
        errmsg       => 'DetergentMeta name content',
        func         => sub {
            my ($self, $params, $name, $content) = @_;
            my $x = $self->{meta}{$name} ||= [];
            push @$x, $content;
        },
    },
);

sub DIR_CREATE {
    my ($class, $params) = @_;

    HTML::Detergent::Config->new;
}

sub DIR_MERGE {
    my ($old, $new) = @_;

    HTML::Detergent::Config->merge($old, $new);
}

Apache2::Module::add(__PACKAGE__ . '::Config', \@DIRECTIVES);

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
    my $f = shift;
    my $r = $f->r;

    $f->print($doc->toString(1));
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
