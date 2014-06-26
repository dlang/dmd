
/*
TEST_OUTPUT:
---
fail_compilation/parseStc4.d(14): Error: redundant attribute 'pure'
fail_compilation/parseStc4.d(14): Error: redundant attribute 'nothrow'
fail_compilation/parseStc4.d(14): Error: conflicting attribute '@system'
fail_compilation/parseStc4.d(14): Error: redundant attribute '@nogc'
fail_compilation/parseStc4.d(14): Error: redundant attribute '@property'
---
*/
pure nothrow @safe   @nogc @property
int foo()
pure nothrow @system @nogc @property
{
    return 0;
}
