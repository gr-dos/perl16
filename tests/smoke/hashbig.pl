# todo: hsplit() computes tbl_max * FILLPCT in a 16-bit int, which overflows at 512 buckets, so every insert splits until the 64 KB allocation limit (docs/M0-AUDIT.md)
# a hash with more than about 409 keys
open(STDERR, ">&STDOUT");
for ($i = 0; $i < 1000; $i++) { $big{"k$i"} = $i * 2; }
print scalar(@x = keys %big), " $big{'k999'}\n";
