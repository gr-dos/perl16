package DosRun;

use 5.036;
use warnings;
use autodie qw(open close);
use Exporter 'import';
use File::Basename qw(basename);

our @EXPORT_OK = qw(write_config run_batch dos_files slurp);

=head1 NAME

DosRun - run batch files under DOSBox-X on an emulated 8086

=head1 SYNOPSIS

  use lib 'tests';
  use DosRun qw(write_config run_batch dos_files slurp);

  write_config($work);
  my $timedout = run_batch($work, \@lines, $seconds, "$work/NAME.LOG");
  my %file = dos_files($work);       # upper-case name => path

=head1 DESCRIPTION

C<write_config> writes F<DOSBOX.CNF> in WORK: a CGA machine with the
normal core and C<cputype=8086> (and, with C<memkb =E<gt> N>, conventional
memory limited to N KB; with C<cycles =E<gt> N>, a fixed N cycles per
millisecond, so emulated time is repeatable; with C<mounts =E<gt> [...]>,
further DOSBox-X C<mount> arguments, such as C<'d "/path"'> or
C<'e "/path" -ro'>), C: mounted on WORK, and an autoexec that calls
F<RUN.BAT> and exits. C<run_batch> writes LINES as F<RUN.BAT>
(CRLF line ends) and runs one DOSBox-X session (C<$ENV{DOSBOX}>, default
dosbox-x) with no display or sound, killed after SECONDS. It returns true
if the session was killed. C<dos_files> maps each file in WORK, by its
name in upper case, to its path, since DOSBox-X may create a file with
either case. C<slurp> reads a file as bytes.

=cut

sub slurp ($f) {
    open my $h, '<:raw', $f;
    local $/;
    my $s = <$h>;
    close $h;
    return $s // '';
}

sub write_config ($work, %opt) {
    my $memsize = $opt{memkb} ? "dos mem limit=$opt{memkb}\n" : "";
    my $cycles = $opt{cycles} ? "cycles=fixed $opt{cycles}\n" : "";
    my $mounts = join '', map { "mount $_\n" } @{ $opt{mounts} // [] };
    open my $cnf, '>', "$work/DOSBOX.CNF";
    print $cnf <<~"END";
      [sdl]
      output=surface
      [dosbox]
      machine=cga
      $memsize\[cpu]
      core=normal
      cputype=8086
      $cycles\[autoexec]
      ${mounts}mount c "$work"
      c:
      call RUN.BAT
      exit
      END
    close $cnf;
}

sub run_batch ($work, $lines, $timeout, $log) {
    open my $b, '>:raw', "$work/RUN.BAT";
    print $b map { "$_\r\n" } @$lines;
    close $b;
    local $ENV{SDL_VIDEODRIVER} = 'dummy';
    local $ENV{SDL_AUDIODRIVER} = 'dummy';
    my $rc = system('sh', '-c', 'exec "$@" >"$0" 2>&1', $log,
        'timeout', '-s', 'KILL', $timeout,
        $ENV{DOSBOX} // 'dosbox-x', '-nogui', '-nomenu',
        '-conf', "$work/DOSBOX.CNF");
    return $rc >> 8 == 137;
}

sub dos_files ($work) {
    return map { uc(basename($_)) => $_ } glob "$work/*";
}

1;
