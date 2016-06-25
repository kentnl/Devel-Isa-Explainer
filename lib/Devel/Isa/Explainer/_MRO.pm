use 5.006;    # our
use strict;
use warnings;

package Devel::Isa::Explainer::_MRO;

# ABSTRACT: Method-resolution-order Utilities for DIE

# AUTHORITY

our $VERSION = '0.002900';

use MRO::Compat ();
use Exporter    ();

BEGIN {
  ## no critic (ProhibitCallsToUnexportedSubs)
  *import              = \&Exporter::import;
  *_mro_get_linear_isa = \&mro::get_linear_isa;
  *_mro_is_universal   = \&mro::is_universal;
}

# yes, this is evil

our @EXPORT_OK = qw(
  get_linear_isa
);

use namespace::clean -except => 'import';

=func get_linear_isa

  my $isa = get_linear_isa( $class );

This function is like C<< mro::get_linear_isa()|mro/get_linear_isa >>, with
the exception that it includes C<UNIVERSAL> and any parents of C<UNIVERSAL>
where relevant.

If pointed at C<UNIVERSAL>, will include C<UNIVERSAL>s parents.

If pointed at a L<< parent of C<UNIVERSAL>|mro/is_univeral >>, will B<not>
show C<UNIVERSAL>, despite the fact calling C<< ->can() >> on a parent of
C<UNIVERSAL> still works, despite the fact its actually defined in C<UNIVERSAL>.

=cut

sub get_linear_isa {
  [
    @{ _mro_get_linear_isa( $_[0] ) },
    #<<<
    _mro_is_universal( $_[0] )
      ? ()
      : @{ _mro_get_linear_isa('UNIVERSAL') },
    #>>>
  ];
}

1;
