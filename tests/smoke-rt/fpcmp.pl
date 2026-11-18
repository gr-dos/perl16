# fpcmp: truth and numeric comparisons of -0.0, subnormals, infinities
# and NaN (#16). Perl 3 on an IEEE machine: either zero is false, every
# other number (a NaN too) is true; a NaN is unordered, so <, <=, >, >=
# and == are false and != true; <=> of a NaN is a NaN. wcc -fpc tests
# only the high 16 bits against a literal 0.0, and its helper reports a
# NaN as greater (docs/M3-RUNTIME-AUDIT.md, section 11.5); patch 0012
# works around both. Runtime build only: the development build's Open
# Watcom emulator is wrong itself (a NaN equals everything, 0 == inf is
# true) and does not finish this script.
open(STDERR, ">&STDOUT");
$zero = 0; $m1 = -1; $big = 1e308; $e20 = 1e20; $e300 = 1e-300;
$pz = $zero * 1;
$nz = $zero * $m1;
$tiny = $e300 / $e20;			# 1e-320: high 16 bits clear
$ntiny = -$tiny;
$sub = 1e-308 / 4;			# 2.5e-309: subnormal, high bits set
$inf = $big * 10;
$ninf = -$inf;
$nan = $inf - $inf;
@name = ('+0', '-0', '1e-320', '-1e-320', '2.5e-309', '0.5', '-0.5',
	 'inf', '-inf', 'nan');
@val = ($pz, $nz, $tiny, $ntiny, $sub, 0.5, -0.5, $inf, $ninf, $nan);

sub n {				# a number, or NaN by the only portable test
    local($x) = @_;
    $x == $x ? $x : 'NaN';
}

# the values themselves, through sprintf (which doesn't make them strings)
for ($i = 0; $i <= $#val; $i++) {
    printf "%-8s %s\n", $name[$i],
	$val[$i] == $val[$i] ? sprintf("%.3g", $val[$i]) : 'NaN';
}

print "truth: ?: ! && || if unless while\n";
for ($i = 0; $i <= $#val; $i++) {
    $v = $val[$i];
    $t = ($v ? 'T' : 'F') . (!$v ? 'T' : 'F') . (($v && 1) ? 'T' : 'F')
	. (($v || 0) ? 'T' : 'F');
    if ($v) { $t .= 'T'; } else { $t .= 'F'; }
    unless ($v) { $t .= 'T'; } else { $t .= 'F'; }
    $w = 'F'; while ($v) { $w = 'T'; last; } $t .= $w;
    printf "%-8s %s\n", $name[$i], $t;
}

print "with 0: == != < <= > >= | 0== 0!= 0< 0<= 0> 0>= | if== if> if>= | <=> 0<=>\n";
for ($i = 0; $i <= $#val; $i++) {
    $v = $val[$i];
    $t = (($v == 0) ? 'T' : 'F') . (($v != 0) ? 'T' : 'F')
	. (($v < 0) ? 'T' : 'F') . (($v <= 0) ? 'T' : 'F')
	. (($v > 0) ? 'T' : 'F') . (($v >= 0) ? 'T' : 'F') . ' '
	. ((0 == $v) ? 'T' : 'F') . ((0 != $v) ? 'T' : 'F')
	. ((0 < $v) ? 'T' : 'F') . ((0 <= $v) ? 'T' : 'F')
	. ((0 > $v) ? 'T' : 'F') . ((0 >= $v) ? 'T' : 'F') . ' ';
    if ($v == 0) { $t .= 'T'; } else { $t .= 'F'; }
    if ($v > 0) { $t .= 'T'; } else { $t .= 'F'; }
    if ($v >= 0) { $t .= 'T'; } else { $t .= 'F'; }
    $t .= ' ' . &n($v <=> 0) . ' ' . &n(0 <=> $v);
    printf "%-8s %s\n", $name[$i], $t;
}

print "nan with: < <= > >= == != | reversed | <=> reversed\n";
@bname = ('1', '-1', '+0', '-0', 'inf', 'nan');
@b = (1, -1, $pz, $nz, $inf, $nan);
for ($i = 0; $i <= $#b; $i++) {
    $v = $b[$i];
    $t = (($nan < $v) ? 'T' : 'F') . (($nan <= $v) ? 'T' : 'F')
	. (($nan > $v) ? 'T' : 'F') . (($nan >= $v) ? 'T' : 'F')
	. (($nan == $v) ? 'T' : 'F') . (($nan != $v) ? 'T' : 'F') . ' '
	. (($v < $nan) ? 'T' : 'F') . (($v <= $nan) ? 'T' : 'F')
	. (($v > $nan) ? 'T' : 'F') . (($v >= $nan) ? 'T' : 'F')
	. (($v == $nan) ? 'T' : 'F') . (($v != $nan) ? 'T' : 'F') . ' '
	. &n($nan <=> $v) . ' ' . &n($v <=> $nan);
    printf "%-8s %s\n", $bname[$i], $t;
}
$t = '';
if ($nan > 1) { $t .= 'T'; } else { $t .= 'F'; }
if ($nan >= 1) { $t .= 'T'; } else { $t .= 'F'; }
if ($nan < 1) { $t .= 'T'; } else { $t .= 'F'; }
if ($nan == 1) { $t .= 'T'; } else { $t .= 'F'; }
print "if nan>1 >=1 <1 ==1: $t\n";

# constants, folded when the script is compiled
print "folded: ", (-0.0 ? 'T' : 'F'), (1e-320 ? 'T' : 'F'),
    ((-0.0 < 0) ? 'T' : 'F'), ((9**9**9 - 9**9**9 > 1) ? 'T' : 'F'),
    ((9**9**9 - 9**9**9 >= 1) ? 'T' : 'F'), ' ', &n(-1e-320 <=> 0),
    ' ', &n(9**9**9 - 9**9**9 <=> 1), "\n";

# division by a zero of either sign is an error; by a subnormal it isn't
eval '$x = 1 / $nz;'; print "1/-0: ", ($@ ? $@ : "no error\n");
eval '$x = 1 / $tiny;'; print "1/1e-320: ", ($@ ? $@ : "no error\n");
eval '$x = 1 / 1e-320;'; print "1/1e-320 folded: ", ($@ ? $@ : "no error\n");
print "1/1e-320 > 1e300: ", ((1 / $tiny > 1e300) ? 'T' : 'F'), "\n";
