/*
TEST_OUTPUT:
---
fail_compilation/fail1.d(15): Error: object.Object cannot be sliced with []
---
*/

struct TestS
{
}

static void test()
{
    Object m;
    m[] = error;
}

