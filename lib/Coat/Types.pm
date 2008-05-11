package Coat::Types;

use strict;
use warnings;

use Carp 'confess';
use base 'Exporter';
use vars qw(@EXPORT);

use Coat::Meta::TypeConstraint;

# Moose/Coat keywords
sub as      ($);
sub from    ($);
sub where   (&);
sub message (&);
sub type    ($$;$);
sub subtype ($$;$$);
sub enum    ($;@);
sub via     (&);
sub coerce  ($@);

@EXPORT = qw(
    type subtype enum coerce
    from as where via message
    register_type_constraint
    find_type_constraint
);

sub as      ($) { $_[0] }
sub from    ($) { $_[0] }
sub where   (&) { $_[0] }
sub via     (&) { $_[0] }
sub message (&) { $_[0] }

# {{{ - Registry
# singleton for storing Coat::Meta::Typeconstrain objects

my $REGISTRY = { };

sub register_type_constraint {
    my ($tc) = @_;

    confess "can't register an unnamed type constraint"
        unless defined $tc->name;

    $REGISTRY->{$tc->name} = $tc;
}

sub find_type_constraint         { $REGISTRY->{$_[0]} }
sub list_all_type_constraints    { keys %$REGISTRY    }
sub get_type_constraint_registry { $REGISTRY          }

# }}}

# {{{ - macro (type, subtype, coerce, enum)

sub type($$;$) { 
    my ($type_name, $validation_code, $message) = @_;
    
    register_type_constraint( new Coat::Meta::TypeConstraint(
        name       => $type_name,
        validation => $validation_code,
        message    => $message) );
}

sub subtype ($$;$$) {
    my ($type_name, $parent, $validation_code, $message) = @_;

    register_type_constraint( new Coat::Meta::TypeConstraint(
        name       => $type_name,
        parent     => $parent,
        validation => $validation_code,
        message    => $message ) );
}

sub enum ($;@) {
    my ($type_name, @values) = @_;
    confess "You must have at least two values to enumerate through"
        unless (scalar @values >= 2);

    my $regexp = join( '|', @values );
	
    subtype $type_name 
        => as 'Str' 
        => where { /^$regexp$/i };    
}

sub coerce($@) {
    my ($type_name, %coercion_map) = @_;
    my $tc = find_type_constraint($type_name);

    (defined $tc) || 
        confess "Cannot find type '$type_name', perhaps you forgot to load it.";

    if ($tc->has_coercion) {
        $tc->coercion_map ( { %{ $tc->coercion_map }, %coercion_map });
    }
    else {
        $tc->coercion_map ( \%coercion_map );
    }
}

# }}}

# {{{ - exported functions 

sub export_type_constraints_as_functions {
    my $caller = caller;
    foreach my $t ( list_all_type_constraints() ) {
        my $constraint = find_type_constraint( $t );
        my $constraint_symbol = "${caller}::${t}";
        my $constraint_sub = sub {
            my ($value) = @_;
            local $_ = $value;
            return $constraint->validation->($value) ? 1 : undef;
        };
        {
            no strict 'refs';
            no warnings 'redefine', 'prototype';
            *$constraint_symbol = $constraint_sub;
        }
    }
}

sub validate {
    my ($class, $attr, $attribute, $value, $isa) = @_;
    $isa ||= $attr->{isa};
    my $tc = find_type_constraint( $isa );

    # Exception if not defined and required attribute 
    confess "Attribute \($attribute\) is required and cannot be undef" 
        if ($attr->{required} && ! defined $value);

    # Bypass the type check if not defined and not required
    return 1 if (! defined $value && ! $attr->{required});

    # look for coercion : if the constraint has coercion and
    # current value is of a supported coercion source type, coerce.
    if (defined $tc && $tc->has_coercion) {
        $value = $tc->coerce($value) 
    }

    # look through the type-constraints
    if (defined $tc) {
        $tc->validate( $value ); 
    }

    # unknown type, use it as a classname
    else {
        my $classname = $isa;
        my $tc = find_type_constraint( 'ClassName' );
        
        $tc->validation->($value, $classname)
            or confess "Value '"
                . (defined $value ? $value : 'undef')
                . " is not a member of class '$classname' "
                . "for attribute '$attribute'";
    }

    return $value;
}

# pass the value through all types ; return matching types
sub find_matching_types {
    my ($value) = @_;
    my @matching_types;

    local $_ = $value;
    foreach my $t ( list_all_type_constraints() ){
        my $tc = find_type_constraint( $t );
        push @matching_types, $t 
            if $tc->validation->( $value );
    }

    return @matching_types;
}

# }}}

# {{{ - built-in types and subtypes

## --------------------------------------------------------
## some basic built-in types (mostly taken from Moose)
## --------------------------------------------------------

type 'Any'  => where { 1 }; # meta-type including all
type 'Item' => where { 1 }; # base-type 

subtype 'Undef'   => as 'Item' => where { !defined($_) };
subtype 'Defined' => as 'Item' => where {  defined($_) };

subtype 'Bool'
    => as 'Item' 
    => where { !defined($_) || $_ eq "" || "$_" eq '1' || "$_" eq '0' };

subtype 'Value' 
    => as 'Defined' 
    => where { !ref($_) };
    
subtype 'Ref'
    => as 'Defined' 
    => where {  ref($_) };

subtype 'Str' 
    => as 'Value' 
    => where { 1 };

subtype 'Num' 
    => as 'Value' 
    => where { "$_" =~ /^-?[\d\.]+$/ };
    
subtype 'Int' 
    => as 'Num'   
    => where { "$_" =~ /^-?[0-9]+$/ };

subtype 'ScalarRef' => as 'Ref' => where { ref($_) eq 'SCALAR' };
subtype 'ArrayRef'  => as 'Ref' => where { ref($_) eq 'ARRAY'  }; 
subtype 'HashRef'   => as 'Ref' => where { ref($_) eq 'HASH'   }; 
subtype 'CodeRef'   => as 'Ref' => where { ref($_) eq 'CODE'   }; 
subtype 'RegexpRef' => as 'Ref' => where { ref($_) eq 'Regexp' }; 
subtype 'GlobRef'   => as 'Ref' => where { ref($_) eq 'GLOB'   };

subtype 'FileHandle' 
    => as 'GlobRef' 
    => where { ref($_) eq 'GLOB' };

subtype 'Object' 
    => as 'Ref' 
    => where { ref($_) && ref($_) ne 'Regexp' };

subtype 'ClassName' 
    => as 'Str' 
    => where { ref($_[0]) && ref($_[0]) eq $_[1] };

# }}}

1;
__END__
=pod

=head1 NAME

Coat::Types -- Type constraints handling for Coat

=head1 DESCRIPTION

Attributes in Coat are bound to types with the keyword 'isa'. This lets Coat
perform type-constraint validation when a value is set to an attribute of the
class.

The following types are supported by Coat (based on the ones provided by
L<Moose>, those that are not available in Moose are marked 'C')

    Any
    Item
      Bool
      Undef
      Defined
        Value
          Num
            Int
              Timestamp (C)
          Str
            ClassName
        Ref
          ScalarRef
          ArrayRef
          HashRef
          CodeRef


Each of these types provides a static method called "is_valid" which takes a
value and returns a boolean telling if the value given is valid according to
the type.

=head1 METHODS

=head2 validate

This module provides a method for validating a value set to an attribute. It
calls the appropriate "is_valid" method according to the type given.

If the type given is not a known type, it will be assumed this is a classname,
and the value will then be checked with ClassName->is_valid.

=head1 SEE ALSO

See L<Coat> for more details.

=head1 AUTHORS

This module was written by Alexis Sukrieh E<lt>sukria+perl@sukria.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Alexis Sukrieh.

L<http://www.sukria.net/perl/coat/>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

