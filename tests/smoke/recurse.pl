# todo: each Perl call level takes about 1 KB of C stack (3 KB with local()), mostly eval()'s 780-byte frame, so the 32 KB stack overflows at depth 34; Open Watcom's overflow handler then crashes instead of reporting (docs/M1-REPORT.md)
# subroutine recursion 100 deep
open(STDERR, ">&STDOUT");
sub d { &d($_[0] + 1) if $_[0] < 100; }
&d(0);
print "deep ok\n";
