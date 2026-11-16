# arrays: list operations
open(STDERR, ">&STDOUT");
@a = (3, 1, 2);
print join(",", sort @a), " ", join(",", reverse @a), " ", $#a, " ", scalar(@a), "\n";
push(@a, 4, 5); $x = shift(@a); unshift(@a, 0); $y = pop(@a);
print "@a $x $y\n";
@b = splice(@a, 1, 2); print "@a | @b\n";
@w = split(/,/, "a,b,,c"); print scalar(@w), " $w[3]\n";
sub numerically { $a <=> $b; }
@n = sort numerically (10, 9, 100, 1); print "@n\n";
@r = (1..5); print "@r[1..3]\n";
($p, $q) = (7, 8); ($p, $q) = ($q, $p); print "$p $q\n";
print grep(/a/, "abc", "xyz", "bar") + 0, "\n";
