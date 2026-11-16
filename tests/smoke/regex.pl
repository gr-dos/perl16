# regular expressions: match, substitute, translate, split
open(STDERR, ">&STDOUT");
$_ = "abc123def456";
/(\d+)\D+(\d+)/ && print "$1 $2\n";
($t = $_) =~ s/\d/#/g; print "$t\n";
$c = ($t = $_) =~ tr/a-z/A-Z/; print "$t $c\n";
print "yes\n" if "Foo" =~ /^f/i;
@f = split(/\s+/, "  a  b c "); print scalar(@f), ":@f:\n";
$s = "x=1, y=22"; $s =~ s/(\w)=(\d+)/$2=$1/g; print "$s\n";
