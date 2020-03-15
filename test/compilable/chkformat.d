// https://issues.dlang.org/show_bug.cgi?id=20644
/*
TEST_OUTPUT:
----
compilable/chkformat.d(12): Deprecation: more format specifiers than 0 arguments
----
*/
import core.stdc.stdio;

void main()
{
    printf("%d \n");
}
