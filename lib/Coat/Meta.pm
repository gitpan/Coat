package Coat::Meta;

use strict;
use warnings;
use Carp 'confess';
use Scalar::Util 'reftype';

# This is the classes placeholder for attribute descriptions
my $CLASSES = {};

# the root accessor: returns the whole data structure, all meta classes
sub classes { $CLASSES }

sub attributes { $CLASSES->{ $_[1] } }
sub class
{ 
    my ($self, $class) = @_;
    
    $CLASSES->{ $class } ||= {};
    
    $CLASSES->{'@!family'}{ $class } = [] 
        unless defined $CLASSES->{'@!family'}{ $class };

    return $CLASSES->{ $class };
}

# define an attribute for a class,
# takes care to propagate default values from parents to 
# children
sub attribute 
{
    my ($self, $class, $attribute, $attr_desc) = @_;
        
    # the attribute description may already exist 
    my $desc = Coat::Meta->has( $class, $attribute ); 
    
    # we define the attribute for the class
    if (@_ == 4) {
        $desc = {} unless defined $desc;

        # default values for attribute description
        $desc->{isa} = 'Any' unless exists $desc->{isa};
        $desc->{is}  = 'rw'  unless exists $desc->{is};

        # if a trigger is set, must be a coderef
        if (defined $attr_desc->{'trigger'}) {
            my $trigger = $attr_desc->{'trigger'};
            confess "The trigger option must be passed a code reference" 
                unless ref $trigger && (ref $trigger eq 'CODE');
        }

        # check attribute description
        if (defined $desc->{default}) {
            if (( ref($desc->{default})) && 
                ('CODE' ne reftype($desc->{default}))) {
                confess "Default must be a code reference or a simple scalar for "
                        . "attribute '$attribute' : ".$desc->{default};
            }
        }

        return $CLASSES->{ $class }{ $attribute } = { %{$desc}, %{$attr_desc}};
    }

    # we have to return the attribute description
    # either from ourselves, or from our parents
    else {
        return $desc if defined $desc;
        confess "Attribute $attribute was not previously declared ".
                "for class $class";
    }
}

sub exists
{ 
    my ($self, $class) = @_;
    return exists $CLASSES->{ $class };
}

# this method looks for the attribute description in the whole hierarchy 
# of the class, starting by the lowest leaf.
# returns the description or undef if not found.
sub has($$$);
sub has($$$)
{ 
    my ($self, $class, $attribute) = @_;


    # if the attribute is declared for us, it's ok
    return $CLASSES->{ $class }{ $attribute } if 
        exists $CLASSES->{ $class }{ $attribute };

    # else, we'll look inside each of our parents, recursively
    # until we stop or find one ancestor with the atttribute
    foreach my $parent (@{ Coat::Meta->parents( $class ) }) {
        my $parent_attr = Coat::Meta->has( $parent, $attribute );
        return $parent_attr if defined $parent_attr;
    }

    # none found, the attribute is not supported by the family 
    return undef;
}

# This will build the attributes for a class with all inherited attributes
sub all_attributes
{
    my ($self, $class, $hash) = @_;
    $hash = {} unless defined $hash;

    foreach my $parent (@{ Coat::Meta->family( $class ) }) {
        $hash = { %{ $hash }, %{ Coat::Meta->attributes( $parent ) } };
    }
    
    $hash = { %{ $hash }, %{ Coat::Meta->attributes( $class ) } };

    return $hash;
}

sub is_family 
{ 
    my ($self, $class, $parent) = @_;
    return grep /^$parent$/, @{$CLASSES->{'@!family'}{ $class }};
}


sub parents 
{ 
    my ($self, $class) = @_;
    { no strict 'refs'; return \@{"${class}::ISA"}; }
}

sub class_precedence_list {
    my ($self, $class) = @_;
    return if !$class;

    ( $class, map { $self->class_precedence_list($_) } @{$self->parents($class)} );
}

sub linearized_isa {
    my ($self, $class) = @_;
    my %seen;
    grep { !( $seen{$_}++ ) } $self->class_precedence_list($class);
}

sub is_parent 
{ 
    my ($self, $class, $parent) = @_;
    return grep /^$parent$/, @{ Coat::Meta->parents( $class ) };
}

sub family { $CLASSES->{'@!family'}{ $_[1] } }

sub extends 
{ 
    my ($self, $class, $parents) = @_;
    $parents = [$parents] unless ref $parents;

     # init the family with parents if not exists
     if (! defined $CLASSES->{'@!family'}{ $class } ) {
        $CLASSES->{'@!family'}{ $class } = [];
     }
    

    foreach my $parent (@$parents) {
        # make sure we don't inherit twice
        confess "Class '$class' already inherits from class '$parent'" if 
            Coat::Meta->is_family( $class, $parent );
        
        foreach my $ancestor (@{ Coat::Meta->parents( $parent ) }) {
            push @{ $CLASSES->{'@!family'}{ $class } }, $ancestor 
                unless grep /^$ancestor$/, 
                            @{$CLASSES->{'@!family'}{ $class }};
        }
        
        push @{ $CLASSES->{'@!family'}{ $class } }, $parent;
    }

}

sub modifiers
{ 
    my ($self, $hook, $class, $method, $coderef) = @_;

    # init the method modifiers placeholder
    $CLASSES->{'%!hooks'}{ $class }{ $hook }{ $method } = [] unless
        defined $CLASSES->{'%!hooks'}{ $class }{$hook}{ $method };
     
    # wants to push a new coderef 
    if (defined $coderef) {
        push @{ $CLASSES->{'%!hooks'}{ $class }{$hook}{ $method } }, $coderef;
        return $coderef;
    }

    # wants to get the hooks
    else {
        return $CLASSES->{'%!hooks'}{ $class }{$hook}{ $method } ||= [];
    }
}

sub around_modifiers { shift and Coat::Meta->modifiers('around', @_ ) }
sub after_modifiers  { shift and Coat::Meta->modifiers('after', @_ ) }
sub before_modifiers { shift and Coat::Meta->modifiers('before', @_ ) }

1;
__END__
