# scalars: numbers, strings and conversions between them
open(STDERR, ">&STDOUT");
print "hello, world\n";
$x = 2 ** 10; print "x=$x\n";
print 7 / 2, " ", int(7 / 2), " ", 7 % 3, " ", -7 % 3, "\n";
print 70000 * 3, " ", 1e10, " ", 0.1 + 0.2 == 0.3 ? "eq" : "ne", "\n";
print "10" + "5", " ", "3abc" + 4, " ", "abc" x 3, " ", "a" . "b", "\n";
$s = "Hello"; $s .= ", World"; print length($s), " ", substr($s, 7, 5), " ", index($s, "World"), "\n";
print ord("A"), " ", sprintf("%x", 255), " ", hex("ff"), " ", oct("777"), "\n";
$n = "aa9"; $n++; print "$n\n";
