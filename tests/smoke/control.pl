# control flow and subroutines
open(STDERR, ">&STDOUT");
sub fact { local($n) = @_; $n <= 1 ? 1 : $n * &fact($n - 1); }
print &fact(10), "\n";
sub fib { local($n) = @_; $n < 2 ? $n : &fib($n - 1) + &fib($n - 2); }
print &fib(10), "\n";
OUTER: for ($i = 0; $i < 5; $i++) { for ($j = 0; $j < 5; $j++) { next OUTER if $j > $i; last OUTER if $i == 3; print "$i$j "; } } print "\n";
$i = 0; until ($i >= 3) { $i++; } print "$i\n";
$r = eval 'die "oops\n"; 1;'; print defined($r) ? "lived" : "died: $@";
$x = eval '6 * 7'; print "$x\n";
unless (0) { print "unless\n"; } else { print "else\n"; }
