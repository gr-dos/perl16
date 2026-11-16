# %ENV comes from the DOS environment, and child processes inherit it
# (patches/0004-watcom-environ.patch). DOSBox-X always sets COMSPEC and
# PATH. The eval makes Perl build %ENV at startup whether or not it is
# used, which once hung (docs/M1-REPORT.md).
eval '1;';
print defined($ENV{'COMSPEC'}) ? "COMSPEC set\n" : "COMSPEC missing\n";
print $ENV{'PATH'} ne '' ? "PATH set\n" : "PATH missing\n";
@k = keys %ENV;
print @k >= 2 ? "keys ok\n" : "keys " . scalar(@k) . "\n";
system("set >ENVX.TMP");
open(F, "ENVX.TMP"); @set = <F>; close(F); unlink("ENVX.TMP");
print grep(/^COMSPEC=/i, @set) ? "child has the environment\n" : "child lost the environment\n";
