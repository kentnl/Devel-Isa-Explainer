use strict;
use warnings;

use Test::More;
use Devel::Isa::Explainer::_MRO;

BEGIN {
  *getsub = sub {
    Devel::Isa::Explainer::_MRO::get_package_sub( 'KENTNL::Example', $_[0] );
  };
}

{
  package    # hide
    KENTNL::Example;

  sub foo { 'foo' }
  sub bar { 'bar' }
  sub indef;

  our %HASHV;
  our @ARRAYV;
  our $SCALARV;
  *SYMV = *SYMV;
}

ok( defined getsub('foo'),      "foo is a sub" );
ok( defined getsub('bar'),      "bar is a sub" );
ok( defined getsub('indef'),    "indef is a sub" );
ok( !defined getsub('HASHV'),   "HASHV is not a sub" );
ok( !defined getsub('ARRAYV'),  "ARRAYV is not a sub" );
ok( !defined getsub('SCALARV'), "SCALARV is not a sub" );
ok( !defined getsub('SYMV'),    "SYMV is not a sub" );
ok( !defined getsub('missing'), "missing is not a sub" );
is( getsub('foo')->(), 'foo', "foo sub returned ok" );
is( getsub('bar')->(), 'bar', "bar sub returned ok" );

done_testing;

