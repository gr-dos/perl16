# rand: rand(N) covers [0,N), whatever the C library's rand() gives
# (RANDBITS, msdos/config.h; #16)
srand(1);
$lo = $n = 1000; $hi = 0;
for ($i = 0; $i < 400; $i++) {
    $r = rand($n);
    $lo = $r if $r < $lo;
    $hi = $r if $r > $hi;
}
print "rand(1000) >= 0: ", ($lo >= 0 ? "ok" : "not ok $lo"), "\n";
print "rand(1000) < 1000: ", ($hi < $n ? "ok" : "not ok $hi"), "\n";
print "rand(1000) reaches 900: ", ($hi >= 900 ? "ok" : "not ok $hi"), "\n";
print "rand(1000) below 100: ", ($lo < 100 ? "ok" : "not ok $lo"), "\n";
$hi = 0;
for ($i = 0; $i < 400; $i++) {
    $r = rand;
    $hi = $r if $r > $hi;
}
print "rand reaches 0.9: ", ($hi >= 0.9 && $hi < 1 ? "ok" : "not ok $hi"), "\n";
%seen = ();
for ($i = 0; $i < 400; $i++) { $seen{int(rand(10))}++; }
print "int(rand(10)) gives 0 to 9: ", join(" ", sort keys %seen), "\n";
