# ctype16: CTYPETST.EXE checks msdos/ctype16.h's table macros against
# libc16's <ctype.h> functions for every value from EOF to 255 (#17).
# Run directly, with standard output redirected, as fpcc.pl does.
open(SAVE, ">&STDOUT");
open(STDOUT, ">CT.TMP") || die "CT.TMP: $!\n";
$r = system("C:\\CTYPETST.EXE");
close(STDOUT);
open(STDOUT, ">&SAVE") || die "dup: $!\n";
open(F, "CT.TMP") || die "CT.TMP: $!\n";
print while <F>;
close(F);
unlink("CT.TMP");
print "status $r\n";
