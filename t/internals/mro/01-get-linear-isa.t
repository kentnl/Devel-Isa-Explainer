use strict;
use warnings;

use Test::More;
use Devel::Isa::Explainer::_MRO;
use Test::Differences qw( eq_or_diff );

# A -> C
#     -> D
# A <-
#     -> B
@My::Example::A::ISA = ( 'My::Example::C', 'My::Example::B' );
@My::Example::B::ISA = ('My::Example::C');
@My::Example::C::ISA = ('My::Example::D');
@My::Example::D::ISA = ();

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_isa('My::Example::A'),
  [ 'My::Example::A', 'My::Example::C', 'My::Example::D', 'My::Example::B', 'UNIVERSAL' ],
  'dfs lookup works'
);

# DFS:
# E -> F
#      -> H
#   <------
#   -> G
#     -> UNIVERSAL
# C3:
# E ->
#     -> F
#     -> G
#         -> H
#           -> UNIVERSAL
@My::Example::E::ISA = ( 'My::Example::F', 'My::Example::G' );
@My::Example::F::ISA = ('My::Example::H');
@My::Example::G::ISA = ('My::Example::H');
@My::Example::H::ISA = ();

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_isa('My::Example::E'),
  [ 'My::Example::E', 'My::Example::F', 'My::Example::H', 'My::Example::G', 'UNIVERSAL' ],
  'dfs lookup works v2'
);

use MRO::Compat;
mro::set_mro( "My::Example::E", "c3" );

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_isa('My::Example::E'),
  [ 'My::Example::E', 'My::Example::F', 'My::Example::G', 'My::Example::H', 'UNIVERSAL' ],
  'c3 lookup works and changes MRO'
);

eq_or_diff( Devel::Isa::Explainer::_MRO::get_linear_isa('UNIVERSAL'), ['UNIVERSAL'], 'UNIVERSAL contains only itself' );

@My::EVIL::ISA = ();
push @UNIVERSAL::ISA, "My::EVIL";

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_isa('My::Example::A'),
  [ 'My::Example::A', 'My::Example::C', 'My::Example::D', 'My::Example::B', 'UNIVERSAL', 'My::EVIL' ],
  'Tweaking UNIVERSAL::ISA shows up'
);

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_isa('My::Example::E'),
  [ 'My::Example::E', 'My::Example::F', 'My::Example::G', 'My::Example::H', 'UNIVERSAL', 'My::EVIL' ],
  'tweaking UNIVERSAL::ISA shows up in c3'
);

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_isa('UNIVERSAL'),
  [ 'UNIVERSAL', 'My::EVIL' ],
  'UNIVERSAL  contains evil when extended'
);

eq_or_diff( Devel::Isa::Explainer::_MRO::get_linear_isa('My::EVIL'),
  ['My::EVIL'], 'Parents of Universal dont inherit from UNIVERSAL' );

done_testing;
