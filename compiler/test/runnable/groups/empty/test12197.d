// RUNNABLE_PHOBOS_TEST
// import std.math;

void foo(T)(T[] b)
{
    b[] = b[] ^^ 4;
}
shared static this()
{
    double[] a = [10];
    foo(a);
    assert(a[0] == 10000);
}
