# <*.x> globbing, done in-process by msdos/dosglob.c (no GLOB.EXE): DOS wildcard rules, sorted, lower-cased names after the directory as given, directories but not . and .., and nothing for no match
open(STDERR, ">&STDOUT");
mkdir("GL", 0777) || die "mkdir: $!\n";
mkdir("GL\\SUB", 0777) || die "mkdir: $!\n";
foreach $f ("B.TXT", "A.TXT", "C.DAT", "NOEXT", "AB.TXT") {
    open(F, ">GL\\$f") || die "open: $!\n"; close(F);
}
@g = <GL\*.TXT>; print "@g\n";
@g = <gl/*.*>; print "@g\n";
@g = <GL\*>; print "@g\n";
@g = <GL\?.TXT>; print "@g\n";
@g = <GL\*.NONE>; print scalar(@g), "\n";
@g = <GL\C.* plain GL\NOSUCH*>; print "@g\n";
$d = "GL"; @g = <$d/A*.*>; print "@g\n";
while (<GL\*.TXT>) { $n++; } print "$n\n";
print $/ eq "\n" ? "rs ok" : "rs changed", "\n";
foreach $f (<GL\*.*>) { unlink($f) if -f $f; }
rmdir("GL\\SUB"); rmdir("GL");
print -d "GL" ? "left" : "gone", "\n";
