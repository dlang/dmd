/*
TEST_OUTPUT:
---
fail_compilation/fail2.d(15): Error: TestS cannot be sliced with []
---
*/

struct TestS
{
}

static void test()
{
    TestS s;
    s[] = error;
}

