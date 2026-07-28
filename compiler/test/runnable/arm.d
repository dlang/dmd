
/**************************************
 * Tests aimed at the Arm code generator, even though they also
 * need to pass the x86 compiler.
 */

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

// Returns nonzero if any value is wrong
int testmovregconst()
{
    int r;
    r |= movregconst64_0()  != 0x123456789abcdef0;
    r |= movregconst64_1()  != 0x12345678;
    r |= movregconst64_2()  != 0xFFFF5678;
    r |= movregconst64_3()  != 0x1234FFFF;
    r |= movregconst64_4()  != 0xFFFF_FFFF_FFFF_1234;
    r |= movregconst64_5()  != 0xFFFF_FFFF_1234_FFFF;
    r |= movregconst64_6()  != 0xFFFF_1234_FFFF_FFFF;
    r |= movregconst64_7()  != 0x1234_FFFF_FFFF_FFFF;
    r |= movregconst64_8()  != 0x5555_5555_5555_5555;
    r |= movregconst64_9()  != 0xAAAA_AAAA_AAAA_AAAA;
    r |= movregconst64_10() != 0xFFFF_FFFF_FFFF_FFFE;
    r |= movregconst32_0()  != 0x12345678;
    r |= movregconst32_1()  != 0xFFFF5678;
    r |= movregconst32_2()  != 0x1234FFFF;
    r |= movregconst32_3()  != 0x55555555;
    r |= movregconst32_4()  != 0xAAAAAAAA;
    r |= movregconst32_5()  != 0xFFFFFFFF;
    return r;
}

/******************************************************/

extern(C) int main()
{
    return testmovregconst();
}
