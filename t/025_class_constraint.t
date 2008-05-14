use Test::More 'no_plan';

use strict;
use warnings;

{
    package A;
    use Coat;

    has file => (is => 'rw', isa => 'IO::File');

}
use IO::File;

my $a = A->new( file => IO::File->new );
ok( defined $a, 'defined $a' );

eval { $a->file( A->new ) };
ok( $@, 'Object A is not an IO::File' );

