# hashes: associative arrays
open(STDERR, ">&STDOUT");
%h = ("one", 1, "two", 2, "three", 3);
foreach $k (sort keys %h) { print "$k=$h{$k};"; } print "\n";
delete $h{"two"}; print join(",", sort values %h), " ", defined($h{"two"}) ? "def" : "undef", "\n";
while (($k, $v) = each %h) { $sum += $v; } print "sum=$sum\n";
for ($i = 0; $i < 300; $i++) { $big{"k$i"} = $i * 2; }
print scalar(@x = keys %big), " $big{'k299'}\n";
