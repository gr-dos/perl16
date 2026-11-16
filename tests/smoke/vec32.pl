# todo: vec() with a 32-bit width shifts a 16-bit int by 16 and 24 (docs/M0-AUDIT.md)
# vec() on 8-, 16- and 32-bit fields
open(STDERR, ">&STDOUT");
$v = "\022\064\126\170";
print vec($v, 0, 8), " ", vec($v, 0, 16), " ", vec($v, 0, 32), "\n";
