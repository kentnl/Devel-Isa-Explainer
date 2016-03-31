use 5.006;    # our
use strict;
use warnings;

package Devel::Isa::Explainer;

our $VERSION = '0.001001';

# ABSTRACT: Pretty Print Hierarchies of Subs in Packages

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Exporter ();
use Term::ANSIColor 3.00 ('colored');    # bright_
use Carp           ('croak');
use Package::Stash ();
use MRO::Compat    ();

BEGIN { *import = \&Exporter::import }    ## no critic (ProhibitCallsToUnexportedSubs)

our @EXPORT_OK = qw( explain_isa );

# Perl critic is broken. This is not a void context.
## no critic (BuiltinFunctions::ProhibitVoidMap)
use constant 1.03 ( { map { ( ( sprintf '_E%x', $_ ), ( sprintf ' (id: %s#%d)', __PACKAGE__, $_ ), ) } 1 .. 5 } );

{
  no strict 'refs';                       # namespace clean
  delete ${ __PACKAGE__ . q[::] }{ sprintf '_E%x', $_ } for 1 .. 5;
}

# These exist for twiddling, but are presently undocumented as their interface
# is not deemed even remotely stable. Use at own risk.

our @TYPE_UTIL        = qw( cyan );
our @TYPE             = qw( yellow );
our @PRIVATE          = qw( reset );
our @PUBLIC           = qw( bold bright_green );
our @SHADOWED_PRIVATE = qw( magenta );
our @SHADOWED_PUBLIC  = qw( red );

our $MAX_WIDTH       = 80;
our $SHOW_SHADOWED   = 1;
our $INDENT          = q[ ] x 4;
our $SHADOW_SUFFIX   = q{(^)};
our $SHADOWED_SUFFIX = q{};                # TBD
our $CLUSTERING      = 'type_clustered';









sub explain_isa {
  my $nargs = scalar( my ( $target, ) = @_ );
  1 == $nargs     or croak "Passed $nargs arguments, Expected 1" . _E1;
  defined $target or croak 'Expected defined target' . _E2;
  length $target  or croak 'Expected target with non-zero length' . _E3;
  ref $target and croak 'Expected scalar target' . _E4;
  return _pp_key() . _pp_class($target);
}

# -- no user servicable parts --
sub _class_subs { return Package::Stash->new( $_[0] )->list_all_symbols('CODE') }

sub _sub_type {
  my ($sub) = @_;
  return 'PRIVATE'   if $sub =~ /\A_/sx;
  return 'TYPE_UTIL' if $sub =~ /\A(is_|assert_|to_)[[:upper:]]/sx;
  return 'PRIVATE'   if $sub =~ /\A[[:upper:]][[:upper:]]/sx;
  return 'TYPE'      if $sub =~ /\A[[:upper:]]/sx;
  return 'PUBLIC';
}

sub _hl_TYPE_UTIL {
  if ( $_[0] =~ /\A([^_]+_)(.*\z)/sx ) {
    return colored( \@TYPE_UTIL, $1 ) . colored( \@TYPE, $2 );
  }
  return $_[0];
}

sub _hl_suffix {
  return colored( $_[0], $SHADOW_SUFFIX )   if $_[2];
  return colored( $_[0], $SHADOWED_SUFFIX ) if $_[1];
  return q[];
}

sub _hl_TYPE { return colored( \@TYPE, $_[0] ) }

sub _hl_PUBLIC {
  return ( $_[1] ? colored( \@SHADOWED_PUBLIC, $_[0] ) : colored( \@PUBLIC, $_[0] ) )
    . _hl_suffix( \@SHADOWED_PUBLIC, $_[1], $_[2] );
}

sub _hl_PRIVATE {
  return ( $_[1] ? colored( \@SHADOWED_PRIVATE, $_[0] ) : colored( \@PRIVATE, $_[0] ) )
    . _hl_suffix( \@SHADOWED_PRIVATE, $_[1], $_[2] );
}

sub _pp_sub {
  return __PACKAGE__->can( '_hl_' . _sub_type( $_[0] ) )->(@_);
}

sub _pp_key {
  my @tokens;
  push @tokens, 'Public Sub: ' . _hl_PUBLIC('foo_example');
  push @tokens, 'Type Constraint: ' . _hl_TYPE('TypeName');
  push @tokens, 'Type Constraint Utility: ' . _hl_TYPE_UTIL('typeop_TypeName');
  push @tokens, 'Private/Boring Sub: ' . _hl_PRIVATE('foo_example');
  if ($SHOW_SHADOWED) {
    push @tokens, 'Public Sub shadowing another: ' . _hl_PUBLIC( 'shadowing_example', 0, 1 );
    push @tokens, 'Public Sub shadowed by higher scope: ' . _hl_PUBLIC( 'shadowed_example', 1 );
    push @tokens, 'Public Sub shadowing another and shadowed itself: ' . _hl_PUBLIC( 'shadowed_shadowing_example', 1, 1 );

    push @tokens, 'Private/Boring Sub shadowing another: ' . _hl_PRIVATE( 'shadowing_example', 0, 1 );
    push @tokens, 'Private/Boring Sub shadowed by higher scope: ' . _hl_PRIVATE( 'shadowed_example', 1 );
    push @tokens, 'Private/Boring Sub another and shadowed itself: ' . _hl_PRIVATE( 'shadowing_shadowed_example', 1, 1 );
  }
  push @tokens, 'No Subs: ()';
  return sprintf "Key:\n$INDENT%s\n\n", join qq[\n$INDENT], @tokens;
}

sub _mg_sorted {
  my (%subs) = @_;
  if ($SHOW_SHADOWED) {
    return ( [ sort { lc $a cmp lc $b } keys %subs ] );
  }
  return ( [ grep { !$subs{$_} } sort { lc $a cmp lc $b } keys %subs ] );
}

sub _mg_type_shadow_clustered {
  my (%subs) = @_;
  my %clusters;
  for my $sub ( keys %subs ) {
    my $shadow = '.shadowed' x !!$subs{$sub};
    $clusters{ _sub_type($sub) . $shadow }{$sub} = $subs{$sub};
  }
  my @out;
  for my $type ( map { ( $_, "$_.shadowed" ) } qw( PUBLIC PRIVATE TYPE TYPE_UTIL ) ) {
    next unless exists $clusters{$type};
    push @out, _mg_sorted( %{ $clusters{$type} } );
  }
  return @out;
}

sub _mg_type_clustered {
  my (%subs) = @_;
  my %clusters;
  for my $sub ( keys %subs ) {
    $clusters{ _sub_type($sub) }{$sub} = $subs{$sub};
  }
  my @out;
  for my $type (qw( PUBLIC PRIVATE TYPE TYPE_UTIL )) {
    next unless exists $clusters{$type};
    push @out, _mg_sorted( %{ $clusters{$type} } );
  }
  return @out;
}

sub _mg_aleph {
  my (%subs) = @_;
  my %clusters;
  for my $sub ( keys %subs ) {
    $clusters{ lc( substr $sub, 0, 1 ) }{$sub} = $subs{$sub};
  }
  my @out;
  for my $key ( sort keys %clusters ) {
    push @out, _mg_sorted( %{ $clusters{$key} } );
  }
  return @out;

}

sub _pp_subs {
  my (%subs)     = @_;
  my (@clusters) = __PACKAGE__->can( '_mg_' . $CLUSTERING )->(%subs);
  my (@out_clusters);
  for my $cluster (@clusters) {
    my $cluster_out = q[];

    my @subs = @{$cluster};
    while (@subs) {
      my $line = $INDENT;
      while ( @subs and length $line < $MAX_WIDTH ) {
        my $sub = shift @subs;
        $line .= $sub . q[, ];
      }
      $cluster_out .= "$line\n";
    }

    # Suck up trailing ,
    $cluster_out =~ s/,[ ]\n\z/\n/sx;
    $cluster_out =~ s{(\w+)}{ _pp_sub($1, $subs{$1}->{shadowed}, $subs{$1}->{shadowing} ) }gsex;
    push @out_clusters, $cluster_out;
  }
  return join qq[\n], @out_clusters;
}

sub _pp_class {
  my ($class)   = @_;
  my $out       = q[];
  my $mro_order = _extract_mro($class);
  for my $mro_entry ( @{$mro_order} ) {
    $out .= colored( ['green'], $mro_entry->{class} ) . q[:];
    my (%subs) = %{ $mro_entry->{subs} };
    if ( not keys %subs ) {
      $out .= " ()\n";
      next;
    }
    else { $out .= "\n" }
    $out .= _pp_subs(%subs) . "\n";

    next;
  }
  return $out;
}

sub _extract_mro {
  my ($class) = @_;
  my (@mro_order);
  my ($seen_subs) = {};

  # Walk down finding shadowing
  ## no critic (ProhibitCallstoUnexportedSubs)
  for my $isa ( @{ mro::get_linear_isa($class) } ) {
    my (@subs) = _class_subs($isa);
    if ( not @subs ) {
      push @mro_order,
        {
        class => $isa,
        subs  => {},
        };
      next;
    }
    my %sub_map;
    for my $sub (@subs) {
      $sub_map{$sub} = {
        shadowed  => 0,
        shadowing => 0,
      };

      # The first incarnation of a sub shadows the rest.
      if ( not exists $seen_subs->{$sub} ) {
        $seen_subs->{$sub} = $isa;
      }

      # If we are shadowed, mark ourselves shadowed,
      # and mark all children as shadowers
      if ( $seen_subs->{$sub} ne $isa ) {
        $sub_map{$sub}->{shadowed} = 1;
        for my $child_class (@mro_order) {
          next unless exists $child_class->{subs}->{$sub};
          $child_class->{subs}->{$sub}->{shadowing} = 1;
        }
      }
    }
    push @mro_order,
      {
      class => $isa,
      subs  => \%sub_map,
      };
  }

  if ( 1 > @mro_order or ( 1 >= @mro_order and 1 > keys %{ $mro_order[0]->{subs} } ) ) {

    # Huh, No inheritance, and no subs. K.
    my $module_path = $class;
    $module_path =~ s{ (::|') }{/}sgx;
    if ( not exists $INC{ $module_path . '.pm' } ) {
      croak "No module called $class loaded" . _E5;
    }
  }
  return \@mro_order;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Devel::Isa::Explainer - Pretty Print Hierarchies of Subs in Packages

=head1 VERSION

version 0.001001

=head1 SYNOPSIS

  use Devel::Isa::Explainer qw( explain_isa );

  # Load it yourself first
  print explain_isa('Dist::Zilla::Dist::Builder');

=head1 DESCRIPTION

This module is a simple tool for quickly visualizing inheritance hierarchies to quickly
see what subs are available for a given package, or to ascertain where a given sub
you might see in use is coming from.

This module does not concern itself with any of the fanciness of Roles, and instead, relies entirely
on standard Perl5 Object Model infrastructure. ( Roles are effectively invisible at run-time as
they appear as composed subs in the corresponding class )

=for html <center><img alt="A Display of a simple output from simple usage" src="http://kentnl.github.io/screenshots/Devel-Isa-Explainer/0/c3.png" width="820" height="559" /></center>

=head2 Conventional Sub Name Interpretation

This module utilizes a cultural understanding of the naming conventions that are standardized
on C<CPAN>, and applies color highlighting to make them stand out.

For instance:

=over 4

=item * all lower case subs are assumed to be normal methods/functions/subs

=item * all upper case subs are assumed to be used for semi-private inter-module interoperability
( for instance, C<DESTROY>, C<BUILDALL> )

=item * subs with a leading underscore are assumed to be private methods/functions/subs

=item * subs with C<CamelCase> naming are assumed to be uncleaned Moose/Types::Tiny type-constraint subs

=item * subs starting with C<is_> C<to_> and C<assert_> followed by C<CamelCase> lettering are assumed to
be uncleaned type-constraint utility subs.

=back

=for html <center><img alt="A Display of different subs highlighted by convention" src="http://kentnl.github.io/screenshots/Devel-Isa-Explainer/0/c2.png" width="820" height="559" /></center>

=head2 Inheritance Aware Sub Shadowing

This module analyses the presence of "Shadowed" subs by indicating specifically
when a given module has an overriding sub in higher context.

We don't do any work to ascertain if in fact the higher sub chains to the shadowed one or
not, but we merely indicate that there's a possibility, and show where the default method
call will get routed on the relevant class.

=head1 FUNCTIONS

=head2 C<explain_isa>

  print explain_isa( $loaded_module_name );

Returns a pretty-printed formatted description of the class referenced by C<$loaded_module_name>

=head1 DIAGNOSTICS

=head4 C<< (id: Devel::Isa::Explainer#1) >>

C<explain_isa()> expects exactly one argument, a (loaded) module name to print
the C<ISA> hierarchy of. You passed either 0 arguments ( too few to be useful )
or too many ( Which silently ignoring might block us from adding future enhancements )

=head4 C<< (id: Devel::Isa::Explainer#2) >>

C<explain_isa( $argument )> expects C<$argument> to be a defined module name, but you
somehow managed to pass C<undef>. I don't I<think> there is a legitimate use case for a
module with an undefined name, but I could be wrong.

File a bug if you have proof.

=head4 C<< (id: Devel::Isa::Explainer#3) >>

C<explain_isa( $argument )> expects C<$argument> to have a positive length, but you passed
an empty string. Again as with L<< C<(id: Devel::Isa::Explainer#2)>|/(id: Devel::Isa::Explainer#2) >>, file a bug if there's a
real use case here that I missed.

=head4 C<< (id: Devel::Isa::Explainer#4) >>

C<explain_isa( $argument )> expects C<$argument> to be a normal scalar value describing
a module name, but you passed a reference of some kind.

This is presently an error to protect it for future possible use.

=head4 C<< (id: Devel::Isa::Explainer#5) >>

When trying to extract subs and inheritance from the module name you passed in
C<explain_isa( $module_name )>, no C<sub>s could be found, there were no parent classes,
and the module name in question had never been registered in C<%INC> by Perl.

This indicates that the most likely thing that happened was you forgot to either C<require>
the module in question first, or you forgot to locally define that package with some classes
prior to calling C<explain_isa( $module_name )>

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
