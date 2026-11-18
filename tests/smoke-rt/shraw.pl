# setup: set COMSPEC=C:\TAILTST.EXE
# system() in the runtime build (#22), with TAILTST.EXE as the command processor: it prints its command tail byte for byte and its environment and exits with P16EXIT. A shell command reaches COMSPEC /C exactly as written, with %ENV as Perl changed it, and system() returns its status; a command run directly keeps its quoted arguments
open(STDERR, ">&STDOUT");
open(SAVE, ">&STDOUT");
sub run {
    local($cmd) = @_;
    local(@env);
    open(STDOUT, ">RUN.TMP") || die "RUN.TMP: $!\n";
    $r = system($cmd);
    $e = $!;
    close(STDOUT);
    open(STDOUT, ">&SAVE") || die "dup: $!\n";
    open(F, "RUN.TMP");
    while (<F>) {
	print if /^tail/;
	push(@env, $_) if /^env\[(P16|COMSPEC|PROMPT|PATH)/;
    }
    close(F);
    unlink("RUN.TMP");
    print sort @env;
    print "status $r", $r == -1 ? " ($e)" : "", "\n";
}

$ENV{'P16ADD'} = 'added value';
$ENV{'PATH'} = 'C:\;Z:\\';
print defined($ENV{'PROMPT'}) ? "PROMPT inherited\n" : "no PROMPT\n";
delete $ENV{'PROMPT'};
$ENV{'P16EXIT'} = '5';

# metacharacters: the shell, the command byte for byte
&run("echo \"a  b\"  c \"d \\\"e\\\" f\"\tt %P16ADD% <in >out | more ; x");
# no metacharacters: run directly, the arguments as the command names them
&run('tailtst "a  b" c\"d "e\\\\" ""');
# a program that can't be run directly goes to the shell
&run('nosuchcm "x y"');

# COMSPEC in %ENV is passed on, but the shell is still the one DOS named
$ENV{'COMSPEC'} = 'C:\NOPE.COM';
$ENV{'P16EXIT'} = '0';
delete $ENV{'P16ADD'};
&run('echo >x');

# the shell's exit status; the 122-byte limit on the command
$ENV{'P16EXIT'} = '7';
&run('echo >' . ('x' x 116));
&run('echo >' . ('x' x 117));
