use strict;
use warnings;

use Time::HiRes qw( stat );

use Test::Fatal;
use Test::More;

{
    package Step1;

    use Moose;
    with 'Stepford::Role::Step';

    has plain => (
        is => 'ro',
    );

    has input_file1 => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    has input_file2 => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    has output_file1 => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    has output_file2 => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run { }

    sub last_run_time { time }
}

is_deeply(
    [ sort map { $_->name() } Step1->dependencies() ],
    [qw( input_file1 input_file2)],
    'Step1->dependencies returns the expected attributes'
);

is_deeply(
    [ sort map { $_->name() } Step1->productions() ],
    [qw( output_file1 output_file2)],
    'Step1->productions returns the expected attributes'
);

{
    package FileStep;

    use File::Temp qw( tempdir );
    use Path::Class qw( dir );
    use Stepford::Types qw( File );

    use Moose;
    with 'Stepford::Role::Step::FileGenerator';

    my $tempdir = dir( tempdir( CLEANUP => 1 ) );

    has output_file1 => (
        traits  => ['StepProduction'],
        is      => 'ro',
        isa     => File,
        default => sub { $tempdir->file('file1') },
    );

    has output_file2 => (
        traits  => ['StepProduction'],
        is      => 'ro',
        isa     => File,
        default => sub { $tempdir->file('file2') },
    );

    sub run {
        my $self = shift;

        $self->output_file1()->touch();
        utime 100, 100, $self->output_file1();

        $self->output_file2()->touch();
    }
}

{
    my $step = FileStep->new( prior_steps_last_run_time => 1 );

    is(
        $step->last_run_time(), undef,
        q{no last run time when output files don't exist}
    );

    $step->run();
    is(
        $step->last_run_time(),
        ( stat $step->output_file2() )[9],
        'last_run_time matches mtime of $step->output_file2'
    );
}

{
    package FileStep::Bad;

    use Stepford::Types qw( Str );

    use Moose;
    with 'Stepford::Role::Step::FileGenerator';

    has output1 => (
        traits => ['StepProduction'],
        is     => 'ro',
        isa    => Str,
    );

    has output2 => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run { }
}

{
    my $e
        = exception { FileStep::Bad->new( prior_steps_last_run_time => 1 ) };
    like(
        $e,
        qr/
            \QThe FileStep::Bad class consumed the \E
            \QStepford::Role::Step::FileGenerator role but contains \E
            \Qthe following productions which are not files: output1 output2\E
           /x,
        'FileStep::Bad->new() dies because it has productions which are not files'
    );
}

done_testing();
