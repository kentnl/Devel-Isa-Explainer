use strict;
use warnings;

use Test::More;
{

  package My::Test;
  sub constant_sub() { 'Hello' }
}
use Devel::Isa::Explainer ();

*get_sub_properties = \&Devel::Isa::Explainer::_get_sub_properties;
*extract_mro        = \&Devel::Isa::Explainer::_extract_mro;

ok( get_sub_properties( \&My::Test::constant_sub )->{constant}, 'My::Test::constant_sub is a constant sub' );
ok(
  !get_sub_properties( \&Devel::Isa::Explainer::explain_isa )->{constant},
  'Devel::Isa::Explainer::explain_isa is not a constant sub'
);
{
  my $mro  = extract_mro("My::Test");
  my $fail = 0;
  for my $class ( @{$mro} ) {
    next unless $class->{class} eq 'My::Test';
    $fail = 1 unless ok( exists $class->{subs}->{'constant_sub'},      "constant_sub discovered in class" );
    $fail = 1 unless ok( $class->{subs}->{'constant_sub'}->{constant}, "constant_sub is a constant sub" );
  }
  diag explain $mro if $fail;

}
{
  my $mro  = extract_mro("Devel::Isa::Explainer");
  my $fail = 0;
  for my $class ( @{$mro} ) {
    next unless $class->{class} eq 'Devel::Isa::Explainer';
    $fail = 1 unless ok( exists $class->{subs}->{'explain_isa'},       "explain_isa discovered in class" );
    $fail = 1 unless ok( !$class->{subs}->{'explain_isa'}->{constant}, "explain_isa is NOT a constant sub" );
  }
  diag explain $mro if $fail;
}

done_testing;
