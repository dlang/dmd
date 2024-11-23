/*
TEST_OUTPUT:
---
fail_compilation/failinout2.d(12): Error: variable `failinout2.x` - only parameters or stack-based variables can be `inout`
inout int x;
          ^
fail_compilation/failinout2.d(16): Error: variable `failinout2.S3748.err8` - only parameters or stack-based variables can be `inout`
    inout(int) err8;
               ^
---
*/
inout int x;

struct S3748
{
    inout(int) err8;
}
