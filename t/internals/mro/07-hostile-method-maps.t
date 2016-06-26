use strict;
use warnings;

use Test::More;
use Test::Differences qw( eq_or_diff );
use MRO::Compat qw();

# DFS shadow stack
@Foo::ISA              = ('Foo::Parent');
@Foo::Parent::ISA      = ('Foo::Grandparent');
@Foo::Grandparent::ISA = ('Foo::GreatGrandparent');

sub Foo::GreatGrandparent::meth { }
sub Foo::Grandparent::meth      { }
sub Foo::Parent::meth           { }

BEGIN {
  *Foo::meth = *Foo::meth = \&Foo::Grandparent::meth;
}

use Devel::Isa::Explainer::_MRO qw(get_linear_method_map);
{
  my $methods = get_linear_method_map( 'Foo', 'meth' );

  eq_or_diff(
    [ map { [ $_->[0], defined $_->[1] ? 1 : 0 ] } @{$methods} ],    #
    [                                                                #
      [ 'Foo',                   1 ],
      [ 'Foo::Parent',           1 ],
      [ 'Foo::Grandparent',      1 ],
      [ 'Foo::GreatGrandparent', 1 ],                                #
      [ 'UNIVERSAL',             0 ],
    ],                                                               #
    'Prelinearised isa with subs at every level show'
  );
}
{
  my $methods = get_linear_method_map( 'Foo', 'can' );

  eq_or_diff(
    [ map { [ $_->[0], defined $_->[1] ? 1 : 0 ] } @{$methods} ],    #
    [                                                                #
      [ 'Foo',                   0 ],
      [ 'Foo::Parent',           0 ],
      [ 'Foo::Grandparent',      0 ],
      [ 'Foo::GreatGrandparent', 0 ],                                #
      [ 'UNIVERSAL',             1 ],
    ],                                                               #
    'can is only found in universal in a prelinearised graph'
  );
}

# C3 Torture case
@Consumer::ISA           = ( 'SomeParentClass', 'AnotherParentClass' );
@SomeParentClass::ISA    = ('BaseOfBases');
@AnotherParentClass::ISA = ('BaseOfBases');
@BaseOfBases::ISA        = ();

sub AnotherParentClass::meth { 1 }
sub BaseOfBases::meth        { 0 }

mro::set_mro( 'Consumer', 'c3' );

{
  my $methods = get_linear_method_map( 'Consumer', 'meth' );

  eq_or_diff(
    [ map { [ $_->[0], defined $_->[1] ? 1 : 0 ] } @{$methods} ],    #
    [                                                                #
      [ 'Consumer',           0 ],
      [ 'SomeParentClass',    0 ],
      [ 'AnotherParentClass', 1 ],
      [ 'BaseOfBases',        1 ],                                   #
      [ 'UNIVERSAL',          0 ],
    ],
    'C3 MRO + Confusing graph reports only subs where they should be'    #
  );
}
done_testing;

