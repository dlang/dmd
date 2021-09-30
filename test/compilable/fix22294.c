// https://issues.dlang.org/show_bug.cgi?id=22294

enum { A, B, C };

_Static_assert(A == 0 && B == 1 && C == 2, "in");

int array[C];
