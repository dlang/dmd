// https://issues.dlang.org/show_bug.cgi?id=22918

_Static_assert(sizeof(!0) == 4, "1");
_Static_assert(sizeof(0 == 0) == 4, "2");
_Static_assert(sizeof(0 < 0) == 4, "3");
_Static_assert(sizeof(0 || 0) == 4, "4");
_Static_assert(sizeof(0 && 0) == 4, "5");
