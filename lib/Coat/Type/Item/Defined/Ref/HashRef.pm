package Coat::Type::Item::Defined::Ref::HashRef;

use strict;
use warnings;

use base 'Coat::Type::Item::Defined::Ref';

sub is_valid {
    $_[0]->SUPER::is_valid($_[1]) && 
    ((ref $_[1]) eq 'HASH');
}

1;