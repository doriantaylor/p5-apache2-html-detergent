#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Apache2::HTML::Detergent' ) || print "Bail out!\n";
}

diag( "Testing Apache2::HTML::Detergent $Apache2::HTML::Detergent::VERSION, Perl $], $^X" );
