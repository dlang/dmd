// https://issues.dlang.org/show_bug.cgi?id=22151
/*
TEST_OUTPUT:
---
fail_compilation/fail22151.d(22): Error: function `test` is not an lvalue and cannot be modified
    *&test = *&test;
    ^
fail_compilation/fail22151.d(23): Error: function `test2` is not an lvalue and cannot be modified
    *&test2 = *&test;
    ^
fail_compilation/fail22151.d(26): Error: function pointed to by `fp` is not an lvalue and cannot be modified
    *fp = *fp;
    ^
fail_compilation/fail22151.d(29): Error: function pointed to by `ff` is not an lvalue and cannot be modified
    *ff = *&test2;
    ^
---
*/

void test()
{
    *&test = *&test;
    *&test2 = *&test;

    void function() fp;
    *fp = *fp;

    auto ff = &test2;
    *ff = *&test2;
}

void test2();
