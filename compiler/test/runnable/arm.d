
/**************************************
 * Tests aimed at the Arm code generator, even though they also
 * need to pass the x86 compiler.
 */

import core.stdc.stdio;

/******************************************************/

pragma(inline, false)
{
ulong movregconst64_0()  { return 0x123456789abcdef0; }
ulong movregconst64_1()  { return 0x12345678; }
ulong movregconst64_2()  { return 0xFFFF5678; }
ulong movregconst64_3()  { return 0x1234FFFF; }
ulong movregconst64_4()  { return 0xFFFF_FFFF_FFFF_1234; }
ulong movregconst64_5()  { return 0xFFFF_FFFF_1234_FFFF; }
ulong movregconst64_6()  { return 0xFFFF_1234_FFFF_FFFF; }
ulong movregconst64_7()  { return 0x1234_FFFF_FFFF_FFFF; }
ulong movregconst64_8()  { return 0x5555_5555_5555_5555; }
ulong movregconst64_9()  { return 0xAAAA_AAAA_AAAA_AAAA; }
ulong movregconst64_10() { return 0xFFFF_FFFF_FFFF_FFFE; }

uint movregconst32_0() { return 0x12345678; }
uint movregconst32_1() { return 0xFFFF5678; }
uint movregconst32_2() { return 0x1234FFFF; }
uint movregconst32_3() { return 0x55555555; }
uint movregconst32_4() { return 0xAAAAAAAA; }
uint movregconst32_5() { return 0xFFFFFFFF; }
}

void testmovregconst()
{
    assert(movregconst64_0() == 0x123456789abcdef0);
    assert(movregconst64_1() == 0x12345678);
    assert(movregconst64_2() == 0xFFFF5678);
    assert(movregconst64_3() == 0x1234FFFF);
    assert(movregconst64_4() == 0xFFFF_FFFF_FFFF_1234);
    assert(movregconst64_5() == 0xFFFF_FFFF_1234_FFFF);
    assert(movregconst64_6() == 0xFFFF_1234_FFFF_FFFF);
    assert(movregconst64_7() == 0x1234_FFFF_FFFF_FFFF);
    assert(movregconst64_8() == 0x5555_5555_5555_5555);
    assert(movregconst64_9() == 0xAAAA_AAAA_AAAA_AAAA);
    assert(movregconst64_10() == 0xFFFF_FFFF_FFFF_FFFE);

    assert(movregconst32_0() == 0x12345678);
    assert(movregconst32_1() == 0xFFFF5678);
    assert(movregconst32_2() == 0x1234FFFF);
    assert(movregconst32_3() == 0x55555555);
    assert(movregconst32_4() == 0xAAAAAAAA);
    assert(movregconst32_5() == 0xFFFFFFFF);
}

/******************************************************/

int main()
{
    testmovregconst();

    printf("Success\n");
    return 0;
}
