// REQUIRED_ARGS: -preview=rvaluerefparam
//
/* TEST_OUTPUT:
---
---
*/

//import std.stdio;
import core.stdc.stdio;

/***************************************************/

void text10682()
{
    ulong x = 1;
    ulong y = 2 ^^ x;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=6228

void test6228()
{
    int val;
    const(int)* ptr = &val;
    const(int)  temp;
    auto x = (*ptr) ^^ temp;
}

/***************************************************/

int main()
{
    test6228();

    printf("Success\n");
    return 0;
}
