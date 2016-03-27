use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.18

use Test::More 0.88;
use Test::EOL;

my @files = (
    'bin/isa-splain',
    'lib/App/Isa/Splain.pm',
    'lib/Devel/Isa/Explainer.pm',
    't/00-compile/lib_App_Isa_Splain_pm.t',
    't/00-compile/lib_Devel_Isa_Explainer_pm.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
