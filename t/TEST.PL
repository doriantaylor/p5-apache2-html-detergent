#!perl

use strict;
use warnings FATAL => 'all';

use lib qw(lib);

use base qw(Apache::TestRunPerl);

__PACKAGE__->new->run(@ARGV);
