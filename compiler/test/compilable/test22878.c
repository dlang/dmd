// https://issues.dlang.org/show_bug.cgi?id=22878

_Static_assert(1e10000 + 1e10000 == 1e10000, "1");
