/* REQUIRED_ARGS: -betterC
   PERMUTE_ARGS:
 */


void test(int ij)
{
    assert(ij);
#line 100 "anotherfile"
    assert(ij,"it is not zero");
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=17843

struct S
{
    double d = 0.0;
    int[] x;
}

/*******************************************/

extern (C) void main()
{
    test(1);
    test18472();
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=17605

extern (C) void test17605()
{
    int a;
    enum bool works = __traits(compiles, { a = 1; });
    a = 1;
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=18472

void test18472()
{
    version(D_LP64)
    {
        enum b = typeid(size_t) is typeid(ulong);
    }
    else
    {
        enum b = typeid(size_t) is typeid(uint);
    }

    assert(b);
}
