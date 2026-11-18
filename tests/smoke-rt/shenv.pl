# system() through DOSBox-X's COMMAND.COM in the runtime build (#22): a command with double quotes and redirection reaches the program the shell runs, which sees %ENV as Perl changed it, as does the shell itself
open(STDERR, ">&STDOUT");
sub show {
    local($file, $pat) = @_;
    local(@env);
    open(F, $file) || die "$file: $!\n";
    while (<F>) {
	print if /^tail/;
	push(@env, $_) if /$pat/;
    }
    close(F);
    unlink($file);
    print sort @env;
}

$ENV{'P16ADD'} = 'added value';
$ENV{'PATH'} = 'C:\;Z:\\';
print defined($ENV{'PROMPT'}) ? "PROMPT inherited\n" : "no PROMPT\n";
delete $ENV{'PROMPT'};

system('tailtst "a  b" "c d" >SH1.TMP');
&show('SH1.TMP', '^env\[(P16|PROMPT|PATH)');
system('set >SH2.TMP');
&show('SH2.TMP', '^(P16|PROMPT|PATH)');
