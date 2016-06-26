use strict;
use warnings;

use Test::More;
use Devel::Isa::Explainer::_MRO;
use Test::Differences qw( eq_or_diff );

@My::Example::A::ISA = ( 'My::Example::C', 'My::Example::B' );
@My::Example::B::ISA = ('My::Example::C');
@My::Example::C::ISA = ('My::Example::D');
@My::Example::D::ISA = ();
sub My::Example::D::x_meth { 'd' }
sub My::Example::C::y_meth { 'c' }
sub My::Example::A::y_meth { 'a' }

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_class_map('My::Example::A'),
  [
    [ 'My::Example::A', { y_meth => \&My::Example::A::y_meth } ],
    [ 'My::Example::C', { y_meth => \&My::Example::C::y_meth } ],
    [ 'My::Example::D', { x_meth => \&My::Example::D::x_meth } ],
    [ 'My::Example::B', {} ],
    [ 'UNIVERSAL', Devel::Isa::Explainer::_MRO::get_package_subs('UNIVERSAL') ],
  ],
  'dfs lookup works'
);

@My::Example::E::ISA = ( 'My::Example::F', 'My::Example::G' );
@My::Example::F::ISA = ('My::Example::H');
@My::Example::G::ISA = ('My::Example::H');
@My::Example::H::ISA = ();
sub My::Example::H::x_meth { 'h' }
sub My::Example::G::y_meth { 'g' }
sub My::Example::E::y_meth { 'e' }

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_class_map('My::Example::E'),
  [
    [ 'My::Example::E', { y_meth => \&My::Example::E::y_meth } ],
    [ 'My::Example::F', {} ],
    [ 'My::Example::H', { x_meth => \&My::Example::H::x_meth } ],
    [ 'My::Example::G', { y_meth => \&My::Example::G::y_meth } ],
    [ 'UNIVERSAL', Devel::Isa::Explainer::_MRO::get_package_subs('UNIVERSAL') ]
  ],
  'dfs lookup works (v2)'
);

use MRO::Compat;
mro::set_mro( "My::Example::E", "c3" );

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_class_map('My::Example::E'),
  [
    [ 'My::Example::E', { y_meth => \&My::Example::E::y_meth } ],
    [ 'My::Example::F', {} ],
    [ 'My::Example::G', { y_meth => \&My::Example::G::y_meth } ],
    [ 'My::Example::H', { x_meth => \&My::Example::H::x_meth } ],
    [ 'UNIVERSAL', Devel::Isa::Explainer::_MRO::get_package_subs('UNIVERSAL') ]

  ],
  'c3 lookup works'
);

done_testing;

