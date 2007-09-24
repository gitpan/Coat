use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Coat',
    VERSION_FROM => 'lib/Coat.pm',
    ABSTRACT => 'Light meta class for writing fast OO Perl code',
    PREREQ_PM => {
        'Scalar::Util' => 0,
    },
    test => {TESTS => join( ' ', glob( 't/*.t' ))},
);
