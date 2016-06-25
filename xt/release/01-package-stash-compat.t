
use strict;
use warnings;

use Test::Needs {
  'Package::Stash::PP' => 0,
  'Scalar::Util'       => 0,
};

use Test::More;
use Devel::Isa::Explainer::_MRO qw( get_package_sub );

use Scalar::Util qw( reftype refaddr );

{

  package Foo;
  use constant CSCALAR    => 1;
  use constant CSCALARREF => \1;
  use constant CARRAYREF  => [];
  use constant CHASHREF   => {};
  use constant CSUB       => sub { };
  sub subnormal { }
  sub substub;
  sub subnormalproto () { }
  sub substubproto ();

  our @OURARRAY;
  our %OURHASH;
  our $OURSCALAR;

  *EMPTYGLOB = *EMPTYGLOB;

  our @GLOBCOLLISION;
  our %GLOBCOLLISION;
  sub GLOBCOLLISION { }

  do { no strict 'refs'; my $var = 'Foo'; \%{ $var . '::' } }
    ->{'stubUNDEF'} = undef;
  do { no strict 'refs'; my $var = 'Foo'; \%{ $var . '::' } }
    ->{'stubDSCALAR'} = 1;

  package Foo::SubPackage;
  *CHILDGLOB = *CHILDGLOB;
}

my (@cases);
push @cases, qw( CSCALAR CSCALARREF CARRAYREF CHASHREF CSUB );
push @cases, qw( subnormal substub subnormalproto substubproto );
push @cases, qw( OURARRAY OURHASH OURSCALAR );
push @cases, qw( EMPTYGLOB GLOBCOLLISION stubUNDEF stubDSCALAR );
push @cases, qw( SubPackage );

# using PP because PS:XS and PS:PP return undef or empty string depending on which you get ...
my ( $ps1, $ps2 ) = ( Package::Stash::PP->new('Foo'), Package::Stash::PP->new('Foo') );

for my $case (@cases) {
  note("$case");

  # Note, its important we run first, because Package::Stash vivifies slots into globs
  # in order to get the symbol.
  #
  # We will try not to do this one day, but until then, we have to run first
  # to make sure the "not a glob" path is exercised.
  my $local_result = get_package_sub( 'Foo', $case );

  # We do this twice for consistency, in the event Package::Stash ever ends up returning
  # different things between runs.
  #
  # Explicit has_symbol is used to try (and fail) to guard against symtable changes.
  my $ps1_result = $ps1->has_symbol( '&' . $case ) ? $ps1->get_symbol( '&' . $case ) : undef;
  my $ps2_result = $ps2->has_symbol( '&' . $case ) ? $ps2->get_symbol( '&' . $case ) : undef;

  if ( 0 == grep { defined } ( $ps1_result, $ps2_result, $local_result ) ) {
    pass("Package::Stash and _MRO agree, \&$case is undefined");
    next;
  }
  if ( 3 == grep { defined } ( $ps1_result, $ps2_result, $local_result ) ) {
    pass("Package::Stash and _MRO agree, \&$case is defined");
  }
  else {
    fail("Missmatch on definedness for \&$case");
    next;
  }
  if ( 2 == grep { reftype $ps1_result eq reftype $_ } ( $ps2_result, $local_result ) ) {
    pass( "PS and _MRO agree, \&$case is a " . reftype $ps1_result );
  }
  else {
    fail("PS and _MRO agree on reftype of \&$case");
    diag("PS and _MRO reftypes disagree");

    diag explain {
      ps_1 => reftype $ps1_result,
      ps_2 => reftype $ps2_result,
      _mro => reftype $local_result,
    };
  }
  if ( 2 == grep { refaddr $ps1_result eq refaddr $_ } ( $ps2_result, $local_result ) ) {
    pass( "PS and _MRO agree, \&$case has refaddr " . refaddr $ps1_result );
  }
  else {
    fail("PS and _MRO agree on refaddr of \&$case");
    diag("PS and _MRO refaddrs disagree");
    diag explain {
      ps_1 => refaddr $ps1_result,
      ps_2 => refaddr $ps2_result,
      _mro => refaddr $local_result,
    };
  }
  if ( 'CODE' eq reftype $ps1_result ) {
    if ( $case =~ /stub/ ) {
      ok( !defined &$ps1_result, "&$case is a stub" );
    }
    elsif ( $case =~ /normal/ ) {
      ok( defined &$ps1_result, "&$case is not a stub" );
    }
  }
}

done_testing;
