// REQUIRED_ARGS: -m64
/*
TEST_OUTPUT:
---
fail_compilation/fail15999.d(11): Error: bad type/size of operands 'and'
---
*/

void foo(ulong bar)
{
    asm { and RAX, 0x00000000FFFFFFFF; ret; }
}
