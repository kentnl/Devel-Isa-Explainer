use 5.006;    # our
use strict;
use warnings;

package Devel::Isa::Explainer;

our $VERSION = '0.001000';

# ABSTRACT: Pretty Print Function Hierarchies of Classes

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Exporter        ();
use Term::ANSIColor ('colored');
use Carp            ('croak');
use Package::Stash  ();
use MRO::Compat     ();

BEGIN { *import = \&Exporter::import } ## no critic (ProhibitCallsToUnexportedSubs)

our @EXPORT = qw( explain_isa ); ## no critic (ProhibitAutomaticExportation)

use constant 1.03 { map { ( ( sprintf '_E%x', $_ ), ( sprintf ' E<%s#%d>', __PACKAGE__, $_ ), ) } 1 .. 4 };

{
  no strict 'refs';    # namespace clean
  delete ${ __PACKAGE__ . q[::] }{ sprintf '_E%x', $_ } for 1 .. 4;
}

# These exist for twiddling, but are presently undocumented as their interface
# is not deemed even remotely stable. Use at own risk.

our @TYPE_METHOD      = qw( cyan );
our @TYPE             = qw( yellow );
our @PRIVATE          = qw( reset );
our @PUBLIC           = qw( bold bright_green );
our @SHADOWED_PRIVATE = qw( magenta );
our @SHADOWED_PUBLIC  = qw( red );

our $MAX_WIDTH     = 80;
our $SHOW_SHADOWED = 1;
our $INDENT        = q[ ] x 4;
our $CLUSTERING    = 'type_clustered';









sub explain_isa {
  my $nargs = scalar( my ( $target, ) = @_ );
  1 == $nargs     or croak "Passed $nargs arguments, Expected 1" . _E1;
  defined $target or croak 'Expected defined target' . _E2;
  length $target  or croak 'Expected target with non-zero length' . _E3;
  ref $target and croak 'Expected scalar target' . _E4;
  return _pp_key() . _pp_class($target);
}

# -- no user servicable parts --
sub _class_functions { return Package::Stash->new( $_[0] )->list_all_symbols('CODE') }

sub _function_type {
  my ($function) = @_;
  return 'PRIVATE'   if $function =~ /\A_/sx;
  return 'TYPE_UTIL' if $function =~ /\A(is_|assert_|to_)[[:upper:]]/sx;
  return 'PRIVATE'   if $function =~ /\A[[:upper:]][[:upper:]]/sx;
  return 'TYPE'      if $function =~ /\A[[:upper:]]/sx;
  return 'PUBLIC';
}

sub _hl_TYPE_UTIL {
  if ( $_[0] =~ /\A([^_]+_)(.*\z)/sx ) {
    return colored( \@TYPE_METHOD, $1 ) . colored( \@TYPE, $2 );
  }
  return $_[0];
}
sub _hl_TYPE { return colored( \@TYPE, $_[0] ) }
sub _hl_PUBLIC  { return $_[1] ? colored( \@SHADOWED_PUBLIC,  $_[0] ) : colored( \@PUBLIC,  $_[0] ) }
sub _hl_PRIVATE { return $_[1] ? colored( \@SHADOWED_PRIVATE, $_[0] ) : colored( \@PRIVATE, $_[0] ) }

sub _pp_function {
  return __PACKAGE__->can( '_hl_' . _function_type( $_[0] ) )->(@_);
}

sub _pp_key {
  my @tokens;
  push @tokens, 'Public Function: ' . _hl_PUBLIC('foo_example');
  push @tokens, 'Type Constraint: ' . _hl_TYPE('TypeName');
  push @tokens, 'Type Constraint Utility: ' . _hl_TYPE_UTIL('typeop_TypeName');
  push @tokens, 'Private/Boring Function: ' . _hl_PRIVATE('foo_example');
  if ($SHOW_SHADOWED) {
    push @tokens, 'Public Function shadowed by higher scope: ' . _hl_PUBLIC( 'shadowed_example', 1 );
    push @tokens, 'Private/Boring Function shadowed by higher scope: ' . _hl_PRIVATE( 'shadowed_example', 1 );
  }
  push @tokens, 'No Functions: ()';
  return sprintf "Key:\n$INDENT%s\n\n", join qq[\n$INDENT], @tokens;
}

sub _mg_sorted {
  my (%functions) = @_;
  if ($SHOW_SHADOWED) {
    return ( [ sort { lc $a cmp lc $b } keys %functions ] );
  }
  return ( [ grep { !$functions{$_} } sort { lc $a cmp lc $b } keys %functions ] );
}

sub _mg_type_shadow_clustered {
  my (%functions) = @_;
  my %clusters;
  for my $function ( keys %functions ) {
    my $shadow = '.shadowed' x !!$functions{$function};
    $clusters{ _function_type($function) . $shadow }{$function} = $functions{$function};
  }
  my @out;
  for my $type ( map { ( $_, "$_.shadowed" ) } qw( PUBLIC PRIVATE TYPE TYPE_UTIL ) ) {
    next unless exists $clusters{$type};
    push @out, _mg_sorted( %{ $clusters{$type} } );
  }
  return @out;
}

sub _mg_type_clustered {
  my (%functions) = @_;
  my %clusters;
  for my $function ( keys %functions ) {
    $clusters{ _function_type($function) }{$function} = $functions{$function};
  }
  my @out;
  for my $type (qw( PUBLIC PRIVATE TYPE TYPE_UTIL )) {
    next unless exists $clusters{$type};
    push @out, _mg_sorted( %{ $clusters{$type} } );
  }
  return @out;
}

sub _mg_aleph {
  my (%functions) = @_;
  my %clusters;
  for my $function ( keys %functions ) {
    $clusters{ lc( substr $function, 0, 1 ) }{$function} = $functions{$function};
  }
  my @out;
  for my $key ( sort keys %clusters ) {
    push @out, _mg_sorted( %{ $clusters{$key} } );
  }
  return @out;

}

sub _pp_functions {
  my (%functions) = @_;
  my (@clusters)  = __PACKAGE__->can( '_mg_' . $CLUSTERING )->(%functions);
  my (@out_clusters);
  for my $cluster (@clusters) {
    my $cluster_out = q[];

    my @functions = @{$cluster};
    while (@functions) {
      my $line = $INDENT;
      while ( @functions and length $line < $MAX_WIDTH ) {
        my $function = shift @functions;
        $line .= $function . q[, ];
      }
      $cluster_out .= "$line\n";
    }

    # Suck up trailing ,
    $cluster_out =~ s/,[ ]\n\z/\n/sx;
    $cluster_out =~ s{(\w+)}{ _pp_function($1, $functions{$1}) }gsex;
    push @out_clusters, $cluster_out;
  }
  return join qq[\n], @out_clusters;
}

sub _pp_class {
  my ($class)        = @_;
  my $out            = q[];
  my $seen_functions = {};
  ## no critic (ProhibitCallstoUnexportedSubs)
  for my $isa ( @{ mro::get_linear_isa($class) } ) {
    $out .= colored( ['green'], $isa ) . q[:];
    my (@my_functions) = _class_functions($isa);
    if ( not @my_functions ) {
      $out .= " ()\n";
      next;
    }
    else { $out .= "\n" }
    my %function_map;
    for my $function (@my_functions) {
      if ( not exists $seen_functions->{$function} ) {
        $seen_functions->{$function} = $isa;
      }
      $function_map{$function} = ( $seen_functions->{$function} ne $isa );
    }
    $out .= _pp_functions(%function_map) . "\n";

    next;
  }
  return $out;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Devel::Isa::Explainer - Pretty Print Function Hierarchies of Classes

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

  use Devel::Isa::Explainer;

  # Load it yourself first
  print explain_isa('Dist::Zilla::Dist::Builder');

=head1 DESCRIPTION

This module is a simple tool for quickly visualizing inheritance hierarchies to quickly
see what functions are available for a given class, or to ascertain where a given function
you might see in use is coming from.

This module does not concern itself with any of the fanciness of Roles, and instead, relies entirely
on standard Perl5 Object Model infrastructure. ( Roles are effectively invisible at run-time as
they appear as composed functions in the corresponding class )

=for html <center><img alt="A Display of a simple output from simple usage" src="http://kentnl.github.io/screenshots/Devel-Isa-Explainer/c3.png" width="761" height="373" /></center>

=head2 Conventional Sub Name Interpretation

This module utilizes a cultural understanding of the naming conventions that are standardized
on C<CPAN>, and applies color highlighting to make them stand out.

For instance:

=over 4

=item * all lower case subs are assumed to be normal methods/functions

=item * all upper case subs are assumed to be used for semi-private inter-module interoperability
( for instance, C<DESTROY>, C<BUILDALL> )

=item * subs with a leading underscore are assumed to be private methods/functions

=item * subs with C<CamelCase> naming are assumed to be uncleaned Moose/Types::Tiny type-constraint subs

=item * subs starting with C<is_> C<to_> and C<assert_> followed by C<CamelCase> lettering are assumed to
be uncleaned type-constraint utility subs.

=back

=for html <center><img alt="A Display of different functions highlighted by convention" src="http://kentnl.github.io/screenshots/Devel-Isa-Explainer/c2.png" width="480" height="578" /></center>

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

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
