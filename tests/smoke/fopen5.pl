# fopen5: five files open at once, as many as libc16's FOPEN_MAX of 8
# leaves beside STDIN, STDOUT and STDERR (#17)
@fh = ('F1', 'F2', 'F3', 'F4', 'F5');
for ($i = 1; $i <= 5; $i++) {
    open($fh[$i - 1], ">FOPEN$i.TMP") || die "create $i: $!\n";
}
for ($n = 1; $n <= 3; $n++) {
    for ($i = 1; $i <= 5; $i++) {
	$f = $fh[$i - 1];
	print $f "file $i line $n\n";
    }
}
for ($i = 1; $i <= 5; $i++) { close($fh[$i - 1]) || die "close $i: $!\n"; }
for ($i = 1; $i <= 5; $i++) {
    open($fh[$i - 1], "FOPEN$i.TMP") || die "open $i: $!\n";
}
for ($n = 1; $n <= 3; $n++) {		# read them in turn, all open
    for ($i = 5; $i >= 1; $i--) {
	$f = $fh[$i - 1];
	$line = <$f>;
	print $line;
    }
}
for ($i = 1; $i <= 5; $i++) {
    $f = $fh[$i - 1];
    print "file $i at eof: ", (eof($f) ? "yes" : "no"), "\n";
    close($f);
    unlink("FOPEN$i.TMP");
}
