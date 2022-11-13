// https://issues.dlang.org/show_bug.cgi?id=22973

int *ps[1];
_Static_assert(sizeof(ps[0][0]) == sizeof(int), "");
