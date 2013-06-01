package Apache2::HTML::Detergent::Config;

use strict;
use warnings FATAL => 'all';

use Apache2::Const -compile => qw(OR_ALL ITERATE TAKE1 TAKE12 TAKE2);

use Apache2::CmdParms   ();
use Apache2::Module     ();
use Apache2::Directive  ();
use Apache2::ServerRec  ();
use Apache2::Log        ();
use APR::Table          ();

use Moose;
use namespace::autoclean;

use MooseX::Types::Moose qw(Maybe Str HashRef);

extends 'HTML::Detergent::Config';

# Apache stuff

BEGIN {
    my @DIRECTIVES = (
        {
            name         => 'DetergentTypes',
            req_override => Apache2::Const::OR_ALL,
            args_how     => Apache2::Const::ITERATE,
            errmsg       => 'DetergentTypes type/1 [ type/2 ...]',
            func         => '_set_type',
            #         func         => sub {
            #             my ($self, $params, $type) = @_;
            #             #$self->{types}{$type} = 1;
            #         },
        },
        {
            name         => 'DetergentXSLT',
            req_override => Apache2::Const::OR_ALL,
            args_how     => Apache2::Const::TAKE1,
            errmsg       => 'DetergentXSLT /path/to.xsl',
            func         => '_set_xslt',
        },
        {
            name         => 'DetergentMatch',
            req_override => Apache2::Const::OR_ALL,
            args_how     => Apache2::Const::TAKE12,
            errmsg       => 'DetergentMatch /xpath [ /uri/path/of.xsl ]',
            func         => '_add_match',
            #         func         => sub {
            #             warn 'lol';

            #             my ($self, $params, $xpath, $xsl) = @_;
            #             #$self->{match}{$xpath} = $xsl;
            #         },
        },
        {
            name         => 'DetergentLink',
            req_override => Apache2::Const::OR_ALL,
            args_how     => Apache2::Const::TAKE2,
            errmsg       => 'DetergentLink rel href',
            func         => '_add_link',
            #         func         => sub {
            #             my ($self, $params, $rel, $href) = @_;
            #             my $x = $self->{link}{$rel} ||= [];
            #             push @$x, $href;
            #         },
        },
        {
            name         => 'DetergentMeta',
            req_override => Apache2::Const::OR_ALL,
            args_how     => Apache2::Const::TAKE2,
            errmsg       => 'DetergentMeta name content',
            func         => '_add_meta',
            #         func         => sub {
            #             my ($self, $params, $name, $content) = @_;
            #             my $x = $self->{meta}{$name} ||= [];
            #             push @$x, $content;
            #         },
        },
    );

    # XXX there might be a more 'correct' way to trigger this
    if ($ENV{MOD_PERL}) {
        Apache2::Module::add(__PACKAGE__, \@DIRECTIVES);
    }
}

# GRRR

sub _set_type {
    my ($self, undef, @rest) = @_;
    $self->set_type(@rest);
}

sub _set_xslt {
    my ($self, undef, $path) = @_;
    $self->xslt($path);
}

sub _add_match {
    my ($self, undef, @rest) = @_;
    $self->add_match(@rest);
}

sub _add_link {
    my ($self, undef, @rest) = @_;
    $self->add_link(@rest);
}

sub _add_meta {
    my ($self, undef, @rest) = @_;
    $self->add_meta(@rest);
}

sub DIR_CREATE {
    my ($class, $params) = @_;
    $params->server->log->debug('Creating a new instance of config object');
    #HTML::Detergent::Config->new;
    $class->new;
}

sub DIR_MERGE {
    my ($old, $new) = @_;
    __PACKAGE__->merge($old, $new);
}

*SERVER_CREATE = \&DIR_CREATE;
*SERVER_MERGE  = \&DIR_MERGE;

# Moose stuff

has types => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    default => sub { { 'text/html' => 1, 'application/xhtml+xml' => 1 } },
);

# apache stuff

sub set_type {
    my ($self, $params, $type) = @_;
    $type =~ s!^\s*([^/]+/[^/;]+).*!\L$1!;
    $self->types->{$type} = 1;
}

sub type_matches {
    my ($self, $type) = @_;
    return unless defined $type;
    $type =~ s!^\s*([^/]+/[^/;]+).*!\L$1!;
    # ok so i'm not on crack
    #warn $type;
    #require Data::Dumper;
    #warn Data::Dumper::Dumper($self->types);
    return $self->types->{$type};
}

has xslt => (
    is      => 'rw',
    isa     => Maybe[Str],
    lazy    => 1,
    default => sub { undef },
);


__PACKAGE__->meta->make_immutable;

1;
