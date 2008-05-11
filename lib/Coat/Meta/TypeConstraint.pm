package Coat::Meta::TypeConstraint;

use strict;
use warnings;
use Carp 'confess';

sub new { 
    my ($class, %values) = @_;
    my $self = { %values }; 
    return bless $self, $class;
}

# accessors
sub name         { $_[0]->{name}         ||= $_[1] }
sub validation   { $_[0]->{validation}   ||= $_[1] }
sub coercion_map { $_[0]->{coercion_map} ||= $_[1] }
sub parent       { $_[0]->{parent}       ||= $_[1] }
sub message      { $_[0]->{message}      ||= $_[1] }

# coerce the given value with the first matching type
sub coerce {
    my ($self, $value) = @_;
    # get the matching types for that value
    my @types = Coat::Types::find_matching_types($value);

    # for each source registered, try coercion if the source is a valid type
    local $_ = $value;
    foreach my $source (keys %{ $self->coercion_map }) {
        (grep /^$source$/, @types) and
            return $self->{coercion_map}{$source}->($value);
    }
    return $value;
}

# check the value through the type constraints
sub validate { 
    my ($self, $value) = @_;
    local $_ = $value;

    my $msg = (defined $self->message) 
        ? $self->message->()
        : "Value '" .(defined $value ? $value : 'undef')
          ."' does not validate type constraint '".$self->name."'";

    # validates the parent's type-constraint if exists
    (defined $self->parent) && 
        Coat::Types::find_type_constraint( $self->parent )->validate( $value );

    # pass the value through the check
    $self->validation->($value) or confess $msg;
}

sub has_coercion {
    my ($self) = @_;
    return defined $self->coercion_map;
}

1;
__END__
