use strict;
use warnings;

use Test::More;
use Devel::Isa::Explainer::_MRO;

BEGIN {
  *getsubs = sub {
    Devel::Isa::Explainer::_MRO::get_package_subs('KENTNL::Example');
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

my $hash = getsubs();

ok( defined( my $foo   = delete $hash->{'foo'} ),   'Got foo' );
ok( defined( my $bar   = delete $hash->{'bar'} ),   'Got bar' );
ok( defined( my $indef = delete $hash->{'indef'} ), 'Got indef' );
is( $bar->(), 'bar', 'Bar runs' );
is( $foo->(), 'foo', 'Foo runs' );
ok( !defined &$indef, 'indef is a stub' );
ok( !keys %{$hash}, "No residual keys in hash" ) or diag explain $hash;

done_testing;

