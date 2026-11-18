# fopenmax: libc16's FOPEN_MAX is 8 streams, STDIN, STDOUT and STDERR
# among them (#17). Five files open; a sixth fails cleanly with EMFILE
# and opens once another is closed. A duplicated STDERR takes a stream
# of its own while it is open. (The development build's runtime has 20.)
@fh = ('F1', 'F2', 'F3', 'F4', 'F5', 'F6');
for ($i = 1; $i <= 6; $i++) {
    if (open($fh[$i - 1], ">FMAX$i.TMP")) {
	print "open $i: ok\n";
    } else {
	print "open $i: $!\n";
    }
}
close(F5);
print "after closing 5, open 6: ", (open(F6, ">FMAX6.TMP") ? "ok" : $!), "\n";
close(F4);
open(STDERR, ">&STDOUT") || print "dup: $!\n";
print "with STDERR duplicated, open 4: ",
    (open(F4, ">FMAX4.TMP") ? "ok" : $!), "\n";
close(STDERR);
print "STDERR closed, open 4: ", (open(F4, ">FMAX4.TMP") ? "ok" : $!), "\n";
for ($i = 1; $i <= 6; $i++) {
    close($fh[$i - 1]);
    unlink("FMAX$i.TMP");
}
