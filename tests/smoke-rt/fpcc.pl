# fpcc: FPCTST.EXE, the C layer under fpcmp.pl (#16). Its first columns
# are the compiler's own comparisons, with wcc -fpc's known limits (a
# literal 0.0 and a truth test see only the high 16 bits; > and >= are
# true with a NaN); the rest are msdos/p16fp.h's, which must be right.
# Run directly, with standard output redirected: backticks need the
# shell's exit status, which DOSBox-X's COMMAND.COM doesn't give.
open(SAVE, ">&STDOUT");
open(STDOUT, ">FPC.TMP") || die "FPC.TMP: $!\n";
$r = system("C:\\FPCTST.EXE");
close(STDOUT);
open(STDOUT, ">&SAVE") || die "dup: $!\n";
open(F, "FPC.TMP") || die "FPC.TMP: $!\n";
print while <F>;
close(F);
unlink("FPC.TMP");
print "status $r\n";
