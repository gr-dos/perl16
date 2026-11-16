# subroutine recursion to the depths the default build guarantees: 120 simple, 50 with local() (it reaches 149 and 66; docs/M2-REPORT.md, section 4)
open(STDERR, ">&STDOUT");
sub d { &d($_[0] + 1) if $_[0] < 120; $_[0]; }
print &d(0), "\n";
sub f { local($n) = @_; $n >= 50 ? 0 : 1 + &f($n + 1); }
print &f(0), "\n";
sub fib { local($n) = @_; $n < 2 ? $n : &fib($n - 1) + &fib($n - 2); }
print &fib(15), "\n";
