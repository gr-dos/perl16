# harderr: HARDTST.EXE, the unit test of the INT 24h handler (#17). It
# raises INT 24h itself, as DOS would (DOSBox-X never does), and prints
# the action the handler returned (3, Fail) and its description of each
# error. Run directly, with standard output redirected, as fpcc.pl does.
open(SAVE, ">&STDOUT");
open(STDOUT, ">HARD.TMP") || die "HARD.TMP: $!\n";
$r = system("C:\\HARDTST.EXE");
close(STDOUT);
open(STDOUT, ">&SAVE") || die "dup: $!\n";
open(F, "HARD.TMP") || die "HARD.TMP: $!\n";
print while <F>;
close(F);
unlink("HARD.TMP");
print "status $r\n";
