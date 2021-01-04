// https://issues.dlang.org/show_bug.cgi?id=21177
/*
DISABLED: win
TEST_OUTPUT:
---
compilable/test21177.d(19): Deprecation: more format specifiers than 0 arguments
---
*/

import core.stdc.stdio;

void main()
{
    version (CRuntime_Glibc)
    {
        printf("%m this is a string in errno");
        printf("%s %m", "str".ptr, 2);
        printf("%a", 2.);
        printf("%m %m %s");
    }
    else
    {
        // fake it
        pragma(msg, "compilable/test21177.d(19): Deprecation: more format specifiers than 0 arguments");
    }
}
