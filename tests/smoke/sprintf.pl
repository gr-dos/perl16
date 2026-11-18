# sprintf: a width or precision larger than the interpreter's 1,024-byte
# buffer is cut to 1,023 bytes rather than overrunning it (#16)
$keep = "still here";
@keep = (1, 2, 3);
print length(sprintf("%2000d", 7)), " ", substr(sprintf("%2000d", 7), -3), "|\n";
print length(sprintf("%-2000ld", 7)), " ", substr(sprintf("%-2000d", 7), 0, 3), "|\n";
print length(sprintf("%2000x", 255)), " ", substr(sprintf("%2000x", 255), -3), "|\n";
print length(sprintf("%.1500f", 1)), " ", substr(sprintf("%.1500f", 1), 0, 4), "|\n";
print length(sprintf("%2000c", 65)), " ", substr(sprintf("%2000c", 65), -2), "|\n";
print length(sprintf("%2000s", "abc")), " ", substr(sprintf("%2000s", "abc"), -4), "|\n";
print length(sprintf("%-2000s|", "abc")), "\n";
$f = "%" . ("0" x 300) . "s";
print sprintf("<$f>", "abc"), "\n";
print sprintf("%5d|%-5s|%.2f", 42, "ab", 3.14159), "\n";
print "$keep @keep\n";
