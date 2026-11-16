# a hash with more than about 409 keys: hsplit() once computed its threshold in a 16-bit int and split forever from 512 buckets (patches/0005-16bit-int.patch)
open(STDERR, ">&STDOUT");
for ($i = 0; $i < 1500; $i++) { $big{"k$i"} = $i * 2; }
print scalar(@x = keys %big), " $big{'k999'} $big{'k1499'}\n";
for ($i = 0; $i < 1500; $i += 2) { delete $big{"k$i"}; }
$sum = 0; while (($k, $v) = each %big) { $sum += $v; }
print scalar(@x = keys %big), " $sum ", defined($big{'k10'}) ? "def" : "undef", "\n";
