# todo: Open Watcom's printf rounds a tie away from zero (%.0f of 2.5 gives 3) and gets the 20th digit of %.20g wrong, so Perl 3's number to string conversion differs from glibc's in the last digit (docs/M0-AUDIT.md)
# correctly rounded conversions, as glibc gives them
open(STDERR, ">&STDOUT");
printf("%.0f %.0f %.1f\n", 2.5, 3.5, 0.25);
print 1/3, " ", 2/3, "\n";
