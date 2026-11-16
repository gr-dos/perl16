# todo: my_htonl()/my_ntohl() return long but are called undeclared, so 16-bit int truncates them (docs/M0-AUDIT.md)
# pack and unpack with network (32-bit big-endian) order
open(STDERR, ">&STDOUT");
@p = unpack("N", pack("N", 305419896)); print "@p\n";
print unpack("H8", pack("N", 305419896)), "\n";
