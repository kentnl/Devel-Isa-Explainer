use 5.006;    # our
use strict;
use warnings;

package Devel::Isa::Explainer::_MRO;

# ABSTRACT: Method-resolution-order Utilities for DIE

# AUTHORITY

our $VERSION = '0.002901';

use MRO::Compat ();
use Exporter    ();
use Scalar::Util qw(reftype);

BEGIN {
  ## no critic (ProhibitCallsToUnexportedSubs)
  *import              = \&Exporter::import;
  *_mro_get_linear_isa = \&mro::get_linear_isa;
  *_mro_is_universal   = \&mro::is_universal;
}

our @EXPORT_OK = qw(
  is_mro_proxy
  get_linear_isa
  get_package_sub
  get_package_subs
  get_linear_class_shadows
  get_parents
  get_linear_method_map
  get_linear_class_map
  get_flattened_class
);

BEGIN {
  # MRO Proxies removed since 5.009_005
  *MRO_PROXIES = ( $] <= 5.009005 ) ? sub() { 1 } : sub() { 0 };
}

use namespace::clean -except => 'import';

=func is_mro_proxy

  if ( MRO_PROXIES and is_mro_proxy( $package, $sub ) ) {
    // its a proxy
  } else {
    // anything else
  }

Prior to 5.009_005, L<< backwards-compatibility support for C<MRO>|MRO::Compat >> for
5.8 has to install "proxy" subs at various levels that I<emulate> alternative
resolution orders by hiding relevant nodes in the gaps in tree.

This detects those nodes so that we can pretend they don't exist.

=cut

sub is_mro_proxy {

  # Note: this sub should be optimised out from calling anyway
  # but this is just a failsafe
  MRO_PROXIES ? !!( $Class::C3::MRO{ $_[0] } || {} )->{methods}{ $_[1] } : 0;
}

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

=func get_package_sub

  my $sub = get_package_sub($package, $sub);

Fetch a directly defined C<CodeRef> from C<$package> named C<$sub>

Fake proxy methods (such as Class::C3 proxies) and stubs are ignored by this
and instead return C<undef>

  $result = undef / CODEREF

=cut

sub get_package_sub {
  return undef if MRO_PROXIES and is_mro_proxy(@_);
  my ( $package, $sub ) = @_;

  # this is counter intuitive, but literally
  # everything in a stash that is not a glob *is* a sub.
  #
  # Though they're usually constant-subs.
  #
  # Globs however can /contain/ subs in their {CODE} slot,
  # but globs are not subs.
  my $namespace = do {
    no strict 'refs';
    \%{"${package}::"};
  };
  return undef unless exists $namespace->{$sub};
  if ( 'GLOB' eq reftype \$namespace->{$sub} ) {

    # Autoviv guard.
    return defined *{ \$namespace->{$sub} }{'CODE'} ? *{ \$namespace->{$sub} }{'CODE'} : undef;
  }

  # Note: This vivifies the stash slot into a glob...
  # there's not much that can be done about this at present.
  # Package::Stash does the same.
  #
  # This means the first of us or Package::Stash to traverse a symtable turns
  # everything into globs in order to get coderefs out.
  #
  # Ideally, we don't do this, but ENEEDINFO
  return \&{"${package}::${sub}"};
}

=func get_package_subs

  my $hashref = get_package_subs( $packagename );

Returns a hash of the packages directly defined C<sub>'s.

  $result = { SUBNAME => CODEREF, ... };

=cut

# like get_package_sub, but does a whole class at once and returns a hashref
# of { name => CODEREF }
sub get_package_subs {
  my ($package)   = @_;
  my ($namespace) = do {
    no strict 'refs';
    \%{"${package}::"};
  };
  my (@symnames) = do {
    no strict 'refs';
    keys %{"${package}::"};
  };
  my $subs = {};
  for my $symname (@symnames) {

    my $reftype = reftype \$namespace->{$symname};

    # Globs are only subs if they contain a CODE slot
    # all non-globs vivify to subs.
    # Order can't be changed though, because the second test requires the
    # first to be true to test, so defined is only tested when eq.
    next if ( 'GLOB' eq $reftype ) and not defined *{ \$namespace->{$symname} }{'CODE'};
    next if MRO_PROXIES and is_mro_proxy( $package, $symname );
    $subs->{$symname} =
      'GLOB' eq $reftype
      ? *{ \$namespace->{$symname} }{'CODE'}
      : \&{"${package}::${symname}"};
  }
  $subs;
}

=func get_linear_class_shadows

  my $arrayref = get_linear_class_shadows( $classname )

Combines C<get_linear_isa()> and C<get_package_subs()>,
traversing the inheritance bottom up, computing shadowing
as it goes.

Returns:

  $result     = [ $hashref, $hashref, $hashref,   ... ]
  $hashrefref = { class => CLASSNAME, subs => $submap }
  $submap     = { SUBNAME => $subrecord,          ... }
  $subrecord  = { shadowing => BOOLEAN,
                  shadowed  => BOOLEAN,
                  ref       => CODEREF,               }

=cut

sub get_linear_class_shadows {
  my ($class) = @_;

  # Contains the "image" made bottom up
  # for comparison/detecting shadows.
  my $methods = {};
  my @isa_out;
  for my $package ( reverse @{ get_linear_isa($class) } ) {
    my $subs = get_package_subs($package);
    my $node = {};
    for my $subname ( keys %{$subs} ) {

      # first node is never shadowing
      if ( not exists $methods->{$subname} ) {
        $node->{$subname} = { shadowing => 0, shadowed => 0, ref => $subs->{$subname} };

        # Contains a reference to the previous incarnation
        # for later modification
        $methods->{$subname} = $node->{$subname};
        next;
      }
      $node->{$subname} = { shadowing => 1, shadowed => 0, ref => $subs->{$subname} };
      $methods->{$subname}->{shadowed} = 1;        # mark previous version shadowed
      $methods->{$subname} = $node->{$subname};    # update current
    }
    unshift @isa_out, { class => $package, subs => $node };
  }
  \@isa_out;
}

=func get_parents

  my $parents = get_parents( $package );

This utility finds the effective "depth 1" parents of a given class.
That is, in normal conditions, it just returns the contents of C<@ISA> verbatim.

However, if C<@ISA> is empty, it returns the effective parent, C<UNIVERSAL>
unless of course, the given class is a parent of C<UNIVERSAL> itself (insert drugs here)
at which point it will return an empty list.

Because despite the fact a parent of C<UNIVERSAL> can call C<UNIVERSAL> methods,
reporting C<< UNIVERSAL->parent->parent == UNIVERSAL >> will of course create cycles
for anyone who touches it.

=cut

sub get_parents {
  my ($package) = @_;
  my $namespace = do {
    no strict 'refs';
    \%{"${package}::"};
  };

  if ( exists $namespace->{ISA} ) {
    my $entry_ref = \$namespace->{ISA};
    if (  'GLOB' eq reftype $entry_ref
      and defined *{$entry_ref}{ARRAY}
      and @{ *{$entry_ref}{ARRAY} } )
    {
      return [ @{ *{$entry_ref}{ARRAY} } ];
    }
  }
  return [] if _mro_is_universal($package);
  ['UNIVERSAL'];
}

=func get_linear_method_map

  my $arrayref = get_linear_method_map( $classname, $method )

Returns an C<ArrayRef> describing the vertical stack of a given method.

C<ISA> levels without defined C<CodeRefs> are represented as C<undef>

  $result   = [ $arrayref, $arrayref, $arrayref, ... ]
  $arrayref = [ CLASSNAME, undef / CODEREF           ]

=cut

sub get_linear_method_map {
  my ( $class, $method ) = @_;
  return [ map { [ $_, get_package_sub( $_, $method ) ] } @{ get_linear_isa($class) } ];
}

=func get_linear_class_map

  my $arrayref = get_linear_class_map( $classname )

Returns C<CodeRef> stashes for all packages in C<$classname>'s inheritance (including C<UNIVERSAL>s)
in method-resolution-order.

Returns:

  $result   = [ $arrayref, $arrayref, $arrayref,  ... ]
  $arrayref = [ CLASSNAME, $submap                    ]
  $submap   = { SUBNAME => CODEREF,               ... }

=cut

sub get_linear_class_map {
  my ($class) = @_;
  [ map { [ $_, get_package_subs($_) ] } @{ get_linear_isa($class) } ];
}

=func get_flattened_class

  my $hashref = get_flattened_class( $class_name );

Returns a fully expanded "Flat" representation of a classes hierarchy,
with still enough data present to trace method resolution.

Returns:

  $result = { SUBNAME => $entry, ... }
  $entry  = { ref     => CODEREF,
              via     => CLASSNAME,
              parents => $parentrefs, }

  $parentrefs      = [ $parentref_entry, ... ]
  $parentref_entry = [ CLASSNAME, CODEREF    ]

=cut

sub get_flattened_class {
  my ($class) = @_;
  my $methods = {};
  for my $package ( reverse @{ get_linear_isa($class) } ) {
    my $subs = get_package_subs($package);
    for my $subname ( keys %{$subs} ) {
      $methods->{$subname}->{parents} ||= [];
      unshift @{ $methods->{$subname}->{parents} }, [ $methods->{$subname}->{via}, $methods->{$subname}->{ref} ]
        if exists $methods->{$subname}->{ref};
      $methods->{$subname}->{ref} = $subs->{$subname};
      $methods->{$subname}->{via} = $package;
    }
  }
  $methods;
}

1;
