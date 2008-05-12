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

{
    package A;
    use Coat;
    has 'date_time' => (is => 'rw', isa => 'DateTime', coerce => 1);
}


my $dt = DateTime->now();

my $a = A->new();
eval {
    $a->date_time('2008-10-12');
};
is($@,'','affectation ok');
isa_ok( $a->date_time, 'DateTime' );

1;
