/*
TEST_OUTPUT:
---
fail_compilation/test20096.d(17): Error: cannot `goto` into `try` block
        goto L1;
        ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=20096

void test()
{
    int x;

    try {
      L2:
        goto L1;

        try
        {
          L1:
            ++x;
            goto L2;
        }
        finally
        {
            ++x;
        }
    } finally {}
}
