# vec() on 8-, 16- and 32-bit fields, reading and assigning, with values that need all 16 or 32 bits (patches/0005-16bit-int.patch)
open(STDERR, ">&STDOUT");
$v = "\022\064\126\170";
print vec($v, 0, 8), " ", vec($v, 0, 16), " ", vec($v, 0, 32), "\n";
$w = "\377\376\375\374";
print vec($w, 0, 16), " ", vec($w, 1, 16), " ", vec($w, 0, 32), "\n";
$x = ""; vec($x, 0, 32) = 4000000000; vec($x, 2, 16) = 40000;
print length($x), " ", unpack("H*", $x), " ", vec($x, 0, 32), " ", vec($x, 2, 16), "\n";
