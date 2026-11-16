# pack and unpack with network (32-bit big-endian) order: my_htonl() and my_ntohl() return long and need declaring (patches/0005-16bit-int.patch)
open(STDERR, ">&STDOUT");
@p = unpack("N", pack("N", 305419896)); print "@p\n";
print unpack("H8", pack("N", 305419896)), "\n";
@p = unpack("N2", pack("N2", 4294967295, 65536)); print "@p\n";
@p = unpack("n2", pack("n2", 65535, 4660)); print "@p\n";
print unpack("%32N*", pack("N3", 1, 2, 3000000000)), "\n";
