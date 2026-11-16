# todo: Perl 3 recursion uses about 600 bytes of C stack per level, and the 32 KB stack in DGROUP overflows near depth 50; the overflow crashes rather than being reported (docs/M0-AUDIT.md)
# subroutine recursion 100 deep
open(STDERR, ">&STDOUT");
sub d { &d($_[0] + 1) if $_[0] < 100; }
&d(0);
print "deep ok\n";
