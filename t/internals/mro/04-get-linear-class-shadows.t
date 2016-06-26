use strict;
use warnings;

use Test::More;
use Devel::Isa::Explainer::_MRO;
use Test::Differences qw( eq_or_diff );

my $expected_UNIVERSAL = Devel::Isa::Explainer::_MRO::get_package_subs('UNIVERSAL');
for my $sub ( keys %{$expected_UNIVERSAL} ) {
  $expected_UNIVERSAL->{$sub} = {
    shadowed  => 0,
    shadowing => 0,
    ref       => $expected_UNIVERSAL->{$sub},
  };
}

@My::Example::A::ISA = ( 'My::Example::C', 'My::Example::B' );
@My::Example::B::ISA = ('My::Example::C');
@My::Example::C::ISA = ('My::Example::D');
@My::Example::D::ISA = ();
sub My::Example::D::x_meth { 'd' }
sub My::Example::C::y_meth { 'c' }
sub My::Example::A::y_meth { 'a' }

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_class_shadows('My::Example::A'),
  [
    { class => 'My::Example::A', subs => { y_meth => { shadowed => 0, shadowing => 1, ref => \&My::Example::A::y_meth } } },
    { class => 'My::Example::C', subs => { y_meth => { shadowed => 1, shadowing => 0, ref => \&My::Example::C::y_meth } } },
    { class => 'My::Example::D', subs => { x_meth => { shadowed => 0, shadowing => 0, ref => \&My::Example::D::x_meth } } },
    { class => 'My::Example::B', subs => {} },
    { class => 'UNIVERSAL', subs => $expected_UNIVERSAL },
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
  Devel::Isa::Explainer::_MRO::get_linear_class_shadows('My::Example::E'),
  [
    { class => 'My::Example::E', subs => { y_meth => { shadowed => 0, shadowing => 1, ref => \&My::Example::E::y_meth } } },
    { class => 'My::Example::F', subs => {} },
    { class => 'My::Example::H', subs => { x_meth => { shadowed => 0, shadowing => 0, ref => \&My::Example::H::x_meth } } },
    { class => 'My::Example::G', subs => { y_meth => { shadowed => 1, shadowing => 0, ref => \&My::Example::G::y_meth } } },
    { class => 'UNIVERSAL', subs => $expected_UNIVERSAL },
  ],
  'dfs lookup works (v2)'
);

use MRO::Compat;
mro::set_mro( "My::Example::E", "c3" );

eq_or_diff(
  Devel::Isa::Explainer::_MRO::get_linear_class_shadows('My::Example::E'),
  [
    { class => 'My::Example::E', subs => { y_meth => { shadowed => 0, shadowing => 1, ref => \&My::Example::E::y_meth } } },
    { class => 'My::Example::F', subs => {} },
    { class => 'My::Example::G', subs => { y_meth => { shadowed => 1, shadowing => 0, ref => \&My::Example::G::y_meth } } },
    { class => 'My::Example::H', subs => { x_meth => { shadowed => 0, shadowing => 0, ref => \&My::Example::H::x_meth } } },
    { class => 'UNIVERSAL', subs => $expected_UNIVERSAL },
  ],
  'c3 lookup works'
);

done_testing;

