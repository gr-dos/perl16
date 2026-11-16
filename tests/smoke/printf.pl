# formatted output, which goes through the C library's sprintf
open(STDERR, ">&STDOUT");
printf("%5.2f|%-5d|%05d|%s|%c|%e\n", 3.14159, 42, 42, "str", 65, 12345.678);
printf("%.0f %g %g %d %.3f\n", 2.75, 0.0001, 1e20, -32768, -0.0626);
print -1.5, " ", 0.25, " ", 1e-5, " ", 1e100, "\n";
