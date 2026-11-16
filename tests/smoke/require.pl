# require and do FILE, from the current directory (tests/run-install covers @INC and -I); the modules are the fixtures rqmod.pm and rqfalse.pm
open(STDERR, ">&STDOUT");
require 'rqmod.pm';
require 'rqmod.pm';
print &twice(21), " loaded $loaded ", defined($INC{'rqmod.pm'}) ? "in %INC" : "not in %INC", "\n";
do 'rqmod.pm'; print "do again: $loaded\n";
eval "require 'nosuch.pm';"; print $@ =~ /^Can't locate nosuch.pm in \@INC/ ? "missing ok\n" : "missing: $@";
eval "require 'rqfalse.pm';"; print $@ =~ /did not return a true value/ ? "false ok\n" : "false: $@";
print $INC[$#INC], "\n";
