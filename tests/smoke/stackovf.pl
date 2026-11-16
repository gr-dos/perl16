# status: 255
# unbounded recursion: msdos/stk16.asm reports "Stack overflow" on standard error and exits with status 255, instead of crashing DOS (docs/M2-REPORT.md, section 4)
open(STDERR, ">&STDOUT");
$| = 1;
print "start\n";
sub r { &r($_[0] + 1); }
&r(0);
print "not reached\n";
