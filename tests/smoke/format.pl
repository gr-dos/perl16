# formats and write, with the default top-of-page format "top" (t/op.write checks its output with cat, so cannot run on DOS)
open(STDERR, ">&STDOUT");
format top =
Name       Count  Share
---------- ----- ------
.
format STDOUT =
@<<<<<<<<< @>>>> @##.##
$name,     $n,   $share
.
%n = ("apples", 12, "pears", 3, "plums", 146);
foreach $name (sort keys %n) {
    $n = $n{$name};
    $share = $n / 160 * 100;
    write;
}
$long = "This is a fairly long line that format must break up into pieces.";
format WRAP =
^<<<<<<<<<<<<<<<<<<<~~
$long
.
$~ = "WRAP";
write;
