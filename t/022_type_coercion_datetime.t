use Test::More 'no_plan';
use strict;
use warnings;

use DateTime;
use Coat::Types;
use Coat::Meta::TypeConstraint;

subtype 'DateTime'
    => as 'Object'
    => where {$_->isa('DateTime')};
    

coerce 'DateTime'
    => from 'Str'
        => via {
            return DateTime->now()
        };

subtype 'UInt'
    => as 'Int'
    => where { $_ >= 0}
    => message { 'Cette valeur ('.$_.') n\'est pas positive'};  

{
    package A;
    use Coat;
    has 'date_time' => (is => 'rw', isa => 'DateTime', coerce => 1);
    has 'uint'  => (is =>'rw', isa => 'UInt');
}


my $dt = DateTime->now();

my $a = A->new();
eval {
    $a->date_time('2008-10-12');
};
is($@,'','affectation ok');

eval {
    $a->uint(23);
};
is($@,'','affectation ok');
1;
