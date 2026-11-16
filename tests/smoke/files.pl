# file I/O: text mode, binary mode, file tests, rename, unlink
open(STDERR, ">&STDOUT");
open(F, ">T.TXT") || die "open: $!\n"; print F "a\nb\n"; close(F);
print "size ", -s "T.TXT", "\n";
open(F, "T.TXT") || die; @l = <F>; close(F); print "lines ", scalar(@l), " $l[1]";
open(F, "T.TXT") || die; binmode(F); $_ = <F>; close(F); print "raw ", length($_), "\n";
open(F, ">>T.TXT") || die; print F "c\n"; close(F);
open(F, "T.TXT") || die; while (<F>) { $n = $.; } close(F); print "now $n lines\n";
print -e "T.TXT" ? "exists" : "missing", " ", -d "." ? "dir" : "notdir", "\n";
rename("T.TXT", "U.TXT") || die "rename: $!\n";
print -e "T.TXT" ? "T" : "-", -e "U.TXT" ? "U" : "-", "\n";
unlink("U.TXT"); print -e "U.TXT" ? "kept" : "gone", "\n";
