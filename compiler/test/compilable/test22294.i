/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22294

#pragma whatever
enum { Ax, Bx, Cx };
#pragma

_Static_assert(Ax == 0 && Bx == 1 && Cx == 2, "in");

int array22924[Cx];

// Note that ^Z means end of file, this file ends with one
#pragma 

this should never be parsed
