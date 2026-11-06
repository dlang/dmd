/*
TEST_OUTPUT:
---
fail_compilation/fail20456.d(14): Error: type `Flags` is not an expression
fail_compilation/fail20456.d(19): Error: type `Flags` is not an expression
fail_compilation/fail20456.d(24): Error: type `Flags` is not an expression
---
*/

enum Flags : ubyte { Foo = 1, }

void testIf()
{
    if (Flags) {}
}

void testWhile()
{
    while (Flags) {}
}

void testDoWhile()
{
    do {} while (Flags);
}
