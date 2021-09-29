// https://issues.dlang.org/show_bug.cgi?id=22294

#pragma whatever
enum { A, B, C };
#pragma

_Static_assert(A == 0 && B == 1 && C == 2, "in");

int array[C];

// Note that ^Z means end of file, this file ends with one
#pragma 

this should never be parsed
