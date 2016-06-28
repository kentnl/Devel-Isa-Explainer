use strict;
use warnings;

use Test::More;
use Test::Differences;

use B                     ();
use Devel::Isa::Explainer ();

*get_sub_properties = \&Devel::Isa::Explainer::_get_sub_properties;

sub My::Test::stub;
sub My::Test::constant() { 1 }

my @tests = (
  {
    name   => 'B::svref_2object',
    ref    => \&B::svref_2object,
    wanted => {
      constant => 0,
      stub     => 0,
      sub_name => 'B::svref_2object',
      xsub     => 1,
    },
  },
  {
    name   => 'Devel::Isa::Explainer::explain_isa',
    ref    => \&Devel::Isa::Explainer::explain_isa,
    wanted => {
      constant => 0,
      stub     => 0,
      sub_name => 'Devel::Isa::Explainer::explain_isa',
      xsub     => 0,
    },
  },
  {
    name   => 'My::Test::stub',
    ref    => \&My::Test::stub,
    wanted => {
      constant => 0,
      stub     => 1,
      sub_name => 'My::Test::stub',
      xsub     => 0,
    },
  },
  {
    name   => 'My::Test::constant',
    ref    => \&My::Test::constant,
    wanted => {
      constant => 1,
      stub     => 0,
      sub_name => 'My::Test::constant',
      xsub     => 0,
    },
  },
);

unless ( exists get_sub_properties( \&get_sub_properties )->{sub_name} ) {
  if ( $ENV{RELEASE_TESTING} ) {
    fail("RELEASE TESTING requires either Sub::Util or Sub::Identify");
  }
  note "sub naming comparisons elided";
  delete $_->{wanted}->{sub_name} for @tests;
}
for my $test (@tests) {
  eq_or_diff( get_sub_properties( $test->{ref} ), $test->{wanted}, $test->{name} . ' is expected', );
}

done_testing;