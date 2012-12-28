/*
TEST_OUTPUT:
---
fail_compilation/test9230.d(12): Error: cannot implicitly convert expression (s) of type const(char[]) to string
fail_compilation/test9230.d(18): Error: cannot implicitly convert expression (a) of type int[] to immutable(int[])
fail_compilation/test9230.d(23): Error: cannot implicitly convert expression (a) of type int[] to immutable(int[])
fail_compilation/test9230.d(28): Error: cannot implicitly convert expression (a) of type int[] to immutable(int[])
---
*/

string foo(in char[] s) pure {
    return s; //
}

/*pure*/ immutable(int[]) x1()
{
    int[] a = new int[](10);
    return a;
}
/*pure */immutable(int[]) x2(int len)
{
    int[] a = new int[](len);
    return a;
}
/*pure */immutable(int[]) x3(immutable(int[]) org)
{
    int[] a = new int[](org.length);
    return a;
}
