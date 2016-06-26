use strict;
use warnings;

use Test::More;
use B qw();
{
  package My::Test;
  sub constant_sub() { 'Hello' }
  BEGIN {
    bless \&My::Test::constant_sub, 'My::Test';
    *My::Test::xsub = \&B::svref_2object;
    bless \&My::Test::xsub, 'B';
  };
}

use Devel::Isa::Explainer ();

*extract_mro = \&Devel::Isa::Explainer::_extract_mro;
{
  my $mro  = extract_mro("My::Test");
  my $fail = 0;
  for my $class ( @{$mro} ) {
    next unless $class->{class} eq 'My::Test';
    $fail = 1 unless ok( exists $class->{subs}->{'constant_sub'},  "constant_sub discovered in class" );
    $fail = 1 unless ok( $class->{subs}->{'constant_sub'}->{constant}, "constant_sub is a constant sub" );
    $fail = 1 unless ok( exists $class->{subs}->{'xsub'},  "xsub discovered in class" );
    $fail = 1 unless ok( $class->{subs}->{'xsub'}->{xsub}, "xsub is an XSUB" );
  }
  diag explain $mro if $fail;

}
done_testing;
