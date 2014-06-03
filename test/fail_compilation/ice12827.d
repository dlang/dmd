// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/ice12827.d(12): Error: circular initialization of i
fail_compilation/ice12827.d(17): Error: circular initialization of i
fail_compilation/ice12827.d(22): Error: circular initialization of i
---
*/
struct S1
{
    int i = i;
}

struct S2
{
    immutable int i = i;
}

struct S3
{
    enum int i = i;
}
