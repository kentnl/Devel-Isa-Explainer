use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.18

use Test::More 0.88;
use Test::EOL;

my @files = (
    'bin/isa-splain',
    'lib/App/Isa/Splain.pm',
    'lib/Devel/Isa/Explainer.pm',
    'lib/Devel/Isa/Explainer/_MRO.pm',
    't/00-compile/lib_App_Isa_Splain_pm.t',
    't/00-compile/lib_Devel_Isa_Explainer__MRO_pm.t',
    't/00-compile/lib_Devel_Isa_Explainer_pm.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/01-basic.t',
    't/02-shadowing.t',
    't/cli/basic.t',
    't/cli/dash-m.t',
    't/internals/02-isacache-hide.t',
    't/internals/04-blessed_subs.t',
    't/internals/max-width.t',
    't/internals/mro/01-get-linear-isa.t',
    't/internals/mro/02-get-package-sub.t',
    't/internals/mro/03-get-package-subs.t',
    't/internals/mro/04-get-linear-class-shadows.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
