use strict;
use warnings;

use Test::More;
use Devel::Isa::Explainer::_MRO;
use Test::Differences qw( eq_or_diff );

sub deq_diff {

  # Make Test::Differences deeply compare subs.

  local $Data::Dumper::Deparse = 1;
  local $Test::Builder::Level  = $Test::Builder::Level + 1;
  eq_or_diff(@_);
}

my $unikeys = Devel::Isa::Explainer::_MRO::get_package_subs('UNIVERSAL');
my $unihash = {};
{
  for my $key ( keys %{$unikeys} ) {
    $unihash->{$key} = {
      parents => [],
      ref     => $unikeys->{$key},
      via     => 'UNIVERSAL',
    };
  }
}

@My::Example::A::ISA = ( 'My::Example::C', 'My::Example::B' );
@My::Example::B::ISA = ('My::Example::C');
@My::Example::C::ISA = ('My::Example::D');
@My::Example::D::ISA = ();
sub My::Example::D::x_meth { 'd' }
sub My::Example::C::y_meth { 'c' }
sub My::Example::A::y_meth { 'a' }

deq_diff(
  Devel::Isa::Explainer::_MRO::get_flattened_class('My::Example::A'),
  {
    y_meth => {
      ref     => \&My::Example::A::y_meth,
      via     => 'My::Example::A',
      parents => [ [ 'My::Example::C' => \&My::Example::C::y_meth ] ],
    },
    x_meth => {
      ref     => \&My::Example::D::x_meth,
      via     => 'My::Example::D',
      parents => [],
    },
    %{$unihash},
  },
  'dfs lookup works'
);
@My::Example::E::ISA = ( 'My::Example::F', 'My::Example::G' );
@My::Example::F::ISA = ('My::Example::H');
@My::Example::G::ISA = ('My::Example::H');
@My::Example::H::ISA = ();
sub My::Example::H::x_meth { 'h' }
sub My::Example::G::x_meth { 'g' }
sub My::Example::G::y_meth { 'g' }
sub My::Example::E::y_meth { 'e' }

deq_diff(
  Devel::Isa::Explainer::_MRO::get_flattened_class('My::Example::E'),
  {
    y_meth => {
      ref     => \&My::Example::E::y_meth,
      via     => 'My::Example::E',
      parents => [ [ 'My::Example::G' => \&My::Example::G::y_meth ] ],
    },
    x_meth => {
      ref     => \&My::Example::H::x_meth,
      via     => 'My::Example::H',
      parents => [ [ 'My::Example::G' => \&My::Example::G::x_meth ] ],
    },
    %{$unihash},
  },
  'dfs lookup works (v2)'
);

use MRO::Compat;
mro::set_mro( "My::Example::E", "c3" );

deq_diff(
  Devel::Isa::Explainer::_MRO::get_flattened_class('My::Example::E'),
  {
    y_meth => {
      ref     => \&My::Example::E::y_meth,
      via     => 'My::Example::E',
      parents => [ [ 'My::Example::G' => \&My::Example::G::y_meth ] ],
    },
    x_meth => {
      ref     => \&My::Example::G::x_meth,
      via     => 'My::Example::G',
      parents => [ [ 'My::Example::H' => \&My::Example::H::x_meth ] ],
    },
    %{$unihash}
  },
  'c3 lookup works'
);

done_testing;

