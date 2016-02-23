use 5.006;    # our
use strict;
use warnings;

package App::Isa::Splain;

our $VERSION = '0.001000';

# AUTHORITY

# ABSTRACT: Visualize Module Hierarchies on the command line

use Module::Load qw( load );
use Carp qw( croak );
use Devel::Isa::Explainer qw( explain_isa );

use constant 1.03 { map { ( ( sprintf '_E%x', $_ ), ( sprintf ' E<%s#%d>', __PACKAGE__, $_ ) ) } 1 .. 2 };

{
  no strict 'refs';    # namespace clean
  delete ${ __PACKAGE__ . q[::] }{ sprintf '_E%x', $_ } for 1 .. 2;
}

=method C<new>

Creates an Explainer script for the given module

  my $instance = App::Isa::Splain->new(
    module => "module::name"
  );

=cut

sub new {
  my ( $class, @args ) = @_;
  my (%args) = ref $args[0] ? %{ $args[0] } : @args;
  return bless \%args, $class;
}

=method C<new_from_ARGV>

Creates an Explainer script by passing command line arguments

  my $instance = App::Isa::Splain->new_from_ARGV;
  my $instance = App::Isa::Splain->new_from_ARGV(\@ARGV); # Alternative syntax

See L<COMMAND LINE ARGUMENTS|/COMMAND LINE ARGUMENTS>

=cut

sub new_from_ARGV {
  my (@args) = defined $_[1] ? @{ $_[1] } : @ARGV;
  my $module = shift @args;
  defined $module or croak 'Expected a module name, got none' . _E1;
  return $_[0]->new( module => $module, );
}

sub _module { return $_[0]->{module} }
sub _output { return ( $_[0]->{output} || *STDOUT ) }

=method C<run>

Executes the explainer and prints its output.

=cut

sub run {
  my ($self) = @_;
  load $self->_module;
  croak "Could not print to output handle: $! $^E" . _E2
    unless print { $self->_output } explain_isa( $self->_module );

  return 0;
}

1;

=head1 SYNOPSIS

  my $instance = App::Isa::Splain->new_from_ARGV;
  $instance->run;


=head1 COMMAND LINE ARGUMENTS

  isa-splain Module::Name

=over 4

=item * C<Module::Name>

A module to C<require> and analyze the C<ISA> of.

=back


