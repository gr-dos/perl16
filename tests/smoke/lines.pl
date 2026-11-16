# reading lines longer than str_gets()'s 512-byte buffer, at and around its edges, in line and paragraph mode, and lines with NUL bytes in them (patches/0006-str-gets.patch)
open(STDERR, ">&STDOUT");
@len = (0, 1, 507, 508, 509, 510, 511, 512, 1019, 1020, 1021, 1500, 5000);
open(F, ">L.TXT") || die "open: $!\n";
binmode(F);
foreach $n (@len) {
    $s = ""; for ($i = 0; $i < $n; $i++) { $s .= sprintf("%c", 65 + ($i * 7 + $n) % 26); }
    print F $s, "\n"; $want .= $s . "|";
}
print F "tail";
close(F);
open(F, "L.TXT") || die; binmode(F);
while (<F>) { $got .= $_; push(@got, length($_)); }
close(F);
$got =~ s/\n/|/g;
print $got eq $want . "tail" ? "same" : "differ", "\n";
print "@got\n";
open(F, ">P.TXT") || die; binmode(F);
print F "a\nb\n\n\n", "x" x 600, "\ny\n\n", "z" x 509, "\n\nlast";
close(F);
open(F, "P.TXT") || die; binmode(F);
$/ = ""; @p = <F>; $/ = "\n"; close(F);
print scalar(@p), " ", join(" ", grep(($_ = length($_)) || 1, @p)), "\n";
open(F, ">B.BIN") || die; binmode(F);
print F "ab\0cd\n", "\0" x 700, "\n", "\0\0\n", "x\0";
close(F);
open(F, "B.BIN") || die; binmode(F);
@b = <F>; close(F);
print scalar(@b), " ", join(" ", grep(($_ = length($_)) || 1, @b)), "\n";
open(F, "B.BIN") || die; binmode(F);
$_ = <F>; close(F);
print $_ eq "ab\0cd\n" ? "nul ok" : "nul bad", "\n";
unlink("L.TXT", "P.TXT", "B.BIN");
