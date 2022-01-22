// https://issues.dlang.org/show_bug.cgi?id=22631

enum E : char { A = 3, B };

_Static_assert(sizeof(enum E) == 1, "1");
_Static_assert(A == 3, "2");
