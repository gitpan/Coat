{
    package Util;
    sub looks_like_number {
        my $val = shift;
        $val =~ /^[\d\.]+$/;
    }
}

{
    package Coat::Type;

    use strict;
    use warnings;
    use Carp 'confess';

    sub is_valid   { confess "is_valid Cannot be called from interface Coat::Type" }
}
{
    package Coat::Type::Any;

    use strict;
    use warnings;

    use base 'Coat::Type';

    sub is_valid { 1 }
}

{
    package Coat::Type::Item;

    use strict;
    use warnings;

    use base 'Coat::Type';

    sub is_valid { 1 }
}
{
    package Coat::Type::Item::Bool;

    use strict;
    use warnings;

    use base 'Coat::Type::Item';

    # A boolean must be defined and equal to 0 or 1
    sub is_valid { 
        (defined $_[1]) 
        ? ( ($_[1] == 0 || $_[1] == 1) 
            ? 1
            : 0)
        : 0
    }
}
{
    package Coat::Type::Item::Defined;

    use strict;
    use warnings;

    use base 'Coat::Type::Item';


    sub is_valid {
        (defined $_[1])
        ? 1
        : 0
    }
}
{
    package Coat::Type::Item::Undef;

    use strict;
    use warnings;

    use base 'Coat::Type::Item';

    sub is_valid 
    {
        (! defined $_[1])
        ? 1
        : 0
    }
}
{
    package Coat::Type::Item::Defined::Ref;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined';

    sub is_valid { 
        my ($class, $value) = @_;    
        ($class->SUPER::is_valid($value))
        ? ((ref $value)
            ? 1
            : 0)
        : 0
    }
}
{
    package Coat::Type::Item::Defined::Value;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined';


    sub is_valid { 
        $_[0]->SUPER::is_valid($_[1]) && ( ! ref $_[1] ) ;
    }
}
{
    package Coat::Type::Item::Defined::Value::Num;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Value';

    sub is_valid { $_[0]->SUPER::is_valid($_[1]) && Util::looks_like_number( "$_[1]" ) }
}
{
    package Coat::Type::Item::Defined::Value::Str;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Value';

    sub is_valid { 
        $_[0]->SUPER::is_valid($_[1])
    }
}
{
    package Coat::Type::Item::Defined::Value::Num::Int;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Value::Num';

    sub is_valid {
        $_[0]->SUPER::is_valid( $_[1] ) && ( Util::looks_like_number( "$_[1]" ) == 1 );
    }
}
{
    package Coat::Type::Item::Defined::Value::Str::ClassName;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Value::Str';

    sub is_valid 
    { 
        my ($class, $classname, $value) = @_;
        
        return (defined $value) && 
            (ref $value) &&
            (ref $value eq $classname);
    }
}
{
    package Coat::Type::Item::Defined::Ref::ArrayRef;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Ref';

    sub is_valid {
        $_[0]->SUPER::is_valid($_[1]) && 
        ((ref $_[1]) eq 'ARRAY');
    }
}
{
    package Coat::Type::Item::Defined::Ref::CodeRef;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Ref';

    sub is_valid {
        $_[0]->SUPER::is_valid($_[1]) && 
        ((ref $_[1]) eq 'CODE');
    }
}
{
    package Coat::Type::Item::Defined::Ref::HashRef;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Ref';

    sub is_valid {
        $_[0]->SUPER::is_valid($_[1]) && 
        ((ref $_[1]) eq 'HASH');
    }
}
{
    package Coat::Type::Item::Defined::Ref::ScalarRef;

    use strict;
    use warnings;

    use base 'Coat::Type::Item::Defined::Ref';

    sub is_valid {
        $_[0]->SUPER::is_valid($_[1]) && 
        ((ref $_[1]) eq 'SCALAR');
    }
}

# Types 

package Coat::Types;

use strict;
use warnings;
use Carp 'confess';

my $cache = {};

sub validate
{
    my ($class, $attr, $attribute, $value) = @_;
    my $isa = $attr->{isa};

    my $isa_class = {
        Any       => 'Coat::Type::Any',
        Item      => 'Coat::Type::Item',
        Bool      => 'Coat::Type::Item::Bool',
        Undef     => 'Coat::Type::Item::Undef',
        Defined   => 'Coat::Type::Item::Defined',
        Value     => 'Coat::Type::Item::Defined::Value',
        Num       => 'Coat::Type::Item::Defined::Value::Num',
        Int       => 'Coat::Type::Item::Defined::Value::Num::Int',
        Str       => 'Coat::Type::Item::Defined::Value::Str',
        ClassName => 'Coat::Type::Item::Defined::Value::Str::ClassName',
        Ref       => 'Coat::Type::Item::Defined::Ref',
        ScalarRef => 'Coat::Type::Item::Defined::Ref::ScalarRef',
        ArrayRef  => 'Coat::Type::Item::Defined::Ref::ArrayRef',
        HashRef   => 'Coat::Type::Item::Defined::Ref::HashRef',
        CodeRef   => 'Coat::Type::Item::Defined::Ref::CodeRef',
        RegexpRef => 'Coat::Type::Item::Defined::Ref::RegexpRef',
    };

    # Exception if not defined and required attribute 
    confess "Attribute \($attribute\) is required and cannot be undef" 
        if ($attr->{required} && ! defined $value);

    # Bypass the type check if not defined and not required
    return 1 if (! defined $value && ! $attr->{required});

    # now normal type constraint checks
    if (exists $isa_class->{$isa}) {
        my $type = $isa_class->{$isa};
        $type->is_valid($value) 
            or confess "Value '"
                .(defined $value ? $value : 'undef')
                ."' does not validate type constraint '$isa' "
                . "for attribute '$attribute'";
    }
    
    # unknown type, use it as a classname
    else {
        my $classname = $isa;
        $isa = $isa_class->{'ClassName'};
        $isa->is_valid($classname, $value) 
            or confess "Value '"
                . (defined $value ? $value : 'undef')
                . " is not a member of class '$classname' "
                . "for attribute '$attribute'";
    }
}

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
L<Moose>)

    Any
    Item
      Bool
      Undef
      Defined
        Value
          Num
            Int
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

