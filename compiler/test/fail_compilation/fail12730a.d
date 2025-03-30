/*
TEST_OUTPUT:
---
fail_compilation/fail12730a.d(13): Error: cannot subtract register
---
*/
// https://issues.dlang.org/show_bug.cgi?id=12730

void test()
{
    asm
    {
        lea ECX, [EBX - EAX];
    }
}
