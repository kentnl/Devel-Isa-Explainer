use 5.006;    # our
use strict;
use warnings;

package App::Isa::Splain;

our $VERSION = '0.001000';

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

# ABSTRACT: Visualize Module Hierarchies on the command line

use Module::Load qw( load );
use Carp qw( croak );
use Devel::Isa::Explainer qw( explain_isa );

use constant 1.03 { map { ( ( sprintf '_E%x', $_ ), ( sprintf ' E<%s#%d>', __PACKAGE__, $_ ) ) } 1 .. 2 };

{
  no strict 'refs';    # namespace clean
  delete ${ __PACKAGE__ . q[::] }{ sprintf '_E%x', $_ } for 1 .. 2;
}











sub new {
  my ( $class, @args ) = @_;
  my (%args) = ref $args[0] ? %{ $args[0] } : @args;
  return bless \%args, $class;
}












sub new_from_ARGV {
  my (@args) = defined $_[1] ? @{ $_[1] } : @ARGV;
  my $module = shift @args;
  defined $module or croak 'Expected a module name, got none' . _E1;
  return $_[0]->new( module => $module, );
}

sub _module { return $_[0]->{module} }
sub _output { return ( $_[0]->{output} || *STDOUT ) }







sub run {
  my ($self) = @_;
  load $self->_module;
  croak "Could not print to output handle: $! $^E" . _E2
    unless print { $self->_output } explain_isa( $self->_module );

  return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Isa::Splain - Visualize Module Hierarchies on the command line

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

  my $instance = App::Isa::Splain->new_from_ARGV;
  $instance->run;

=for html <center><img alt="Colorised output from a Moose::Meta::Class" src="http://kentnl.github.io/screenshots/Devel-Isa-Explainer/c1.png" width="820" height="738" /></center>

=head1 METHODS

=head2 C<new>

Creates an Explainer script for the given module

  my $instance = App::Isa::Splain->new(
    module => "module::name"
  );

=head2 C<new_from_ARGV>

Creates an Explainer script by passing command line arguments

  my $instance = App::Isa::Splain->new_from_ARGV;
  my $instance = App::Isa::Splain->new_from_ARGV(\@ARGV); # Alternative syntax

See L<COMMAND LINE ARGUMENTS|/COMMAND LINE ARGUMENTS>

=head2 C<run>

Executes the explainer and prints its output.

=head1 COMMAND LINE ARGUMENTS

  isa-splain Module::Name

=over 4

=item * C<Module::Name>

A module to C<require> and analyze the C<ISA> of.

=back

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
