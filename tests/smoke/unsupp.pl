# Unix operations DOS can't provide die with a clear message that eval can catch (the policy is in docs/M2-REPORT.md, section 8)
open(STDERR, ">&STDOUT");
foreach $op ('fork', 'wait', 'kill 1, $$', 'alarm 1', 'umask 022', 'chown 0, 0, "X"',
    'link("A", "B")', 'symlink("A", "B")', 'readlink("A")', 'chroot("\\\\")',
    'getppid', 'pipe(R, W)', 'socket(S, 2, 1, 0)', 'getpwnam("root")',
    'getgrnam("wheel")', 'getlogin', 'truncate("X", 0)', 'open(F, "UNSUPP.PL"); -T F') {
    eval $op;
    ($m = $@) =~ s/ at \(eval\) line \d+\.\n//;
    $m =~ s/\n$//;
    print "$op: $m\n";
}
print "still running\n";
