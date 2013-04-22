use inc::Module::Install;

name     'Apache2-HTML-Detergent';
all_from 'lib/Apache2/HTML/Detergent.pm';
author   q{Dorian Taylor <dorian@cpan.org>};
license  'apache';

build_requires 'Test::More';
build_requires 'Apache::Test';

clean_files 't/TEST t/SMOKE'

requires 'HTML::Detergent';

require Apache::TestMM;
Apache::TestMM->import(qw(test clean));

Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

auto_install;

WriteAll;

