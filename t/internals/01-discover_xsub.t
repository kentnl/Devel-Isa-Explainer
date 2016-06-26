use strict;
use warnings;

use Test::More;
use B ();

use Devel::Isa::Explainer ();

*extract_mro = \&Devel::Isa::Explainer::_extract_mro;
{
  my $mro  = extract_mro("B");
  my $fail = 0;
  for my $class ( @{$mro} ) {
    next unless $class->{class} eq 'B';
    $fail = 1 unless ok( exists $class->{subs}->{'svref_2object'},  "svref_2object discovered in class" );
    $fail = 1 unless ok( $class->{subs}->{'svref_2object'}->{xsub}, "svref_2object is an XSUB" );
  }
  diag explain $mro if $fail;

}
{
  my $mro  = extract_mro("Devel::Isa::Explainer");
  my $fail = 0;
  for my $class ( @{$mro} ) {
    next unless $class->{class} eq 'Devel::Isa::Explainer';
    $fail = 1 unless ok( exists $class->{subs}->{'explain_isa'},   "explain_isa discovered in class" );
    $fail = 1 unless ok( !$class->{subs}->{'explain_isa'}->{xsub}, "explain_isa is NOT an XSUB" );
  }
  diag explain $mro if $fail;
}

done_testing;
