package Coat::Object;

use strict;
use warnings;
use Coat::Meta;

# this is the mother-class of each Coat objects, it provides
# basic instance methods such as a constructor

# The default constructor
sub new {
    my ( $class, %args ) = @_;

    my $self = {};
    bless $self, $class;

    $self->init(%args);

    return $self;
}

# returns the meta-class description of that instance
sub meta {
    my ($self) = @_;
    return Coat::Meta->class( ref($self) );
}

# init an instance : put default values and set values
# given at instanciation time
sub init {
    my ( $self, %attrs ) = @_;

    # default values
    my $class_attr = Coat::Meta->all_attributes( ref( $self ) );
    foreach my $attr ( keys %{$class_attr} ) {
        if ( defined $class_attr->{$attr}{'default'} ) {
            my $default = $class_attr->{$attr}{'default'};
            ref $default
              ? $self->$attr( &$default(@_) ) # we have a CODE ref
              : $self->$attr( $default );     # we have a plain scalar
        }
    }

    # forced values
    foreach my $attr ( keys %attrs ) {
        $self->$attr( $attrs{$attr} );
    }

    # try to run the BUILD method, if exists
    my $build_sub;
    { no strict 'refs'; $build_sub = *{ref($self)."::BUILD"}; }
    $self->BUILD( %attrs ) if ( defined &$build_sub );
}

# end Coat::Object
1;
__END__

=head1 NAME

Coat::Object - The mother class for each class that uses Coat

=head1 DESCRIPTION

When a class is described with Coat, each instance of that class will inherit
from Coat::Object.

This is the mother-class for each Coat-created objects, it provides a basic default
constructor and access to the meta-class.

=head1 METHODS

=head2 new

This is the default constructor, it creates a new object for your class and
calls init with the arguments given.

=head2 init

This method initialize the instance: basically, setting default values to
attributes and setting values received (passed to the "new" method).

=head2 meta

Returns the meta-calss description: attributes declared with properties.

=head1 SEE ALSO

See C<Coat>, the meta-class for Coat::Object's.

See also C<Moose>, the mother of Coat.

=head1 AUTHORS

This module was written by Alexis Sukrieh E<lt>sukria+perl@sukria.netE<gt>

Strong and helpful reviews were made by Stevan Little and 
Matt (mst) Trout ; this module wouldn't be there without their help.
Huge thank to them.

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Alexis Sukrieh.

L<http://www.sukria.net/perl/coat/>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
