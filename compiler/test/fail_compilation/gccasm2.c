/* TEST_OUTPUT:
---
fail_compilation/gccasm2.c(27): Error: `const` is not a valid `asm` qualifier
fail_compilation/gccasm2.c(28): Error: `restrict` is not a valid `asm` qualifier
fail_compilation/gccasm2.c(33): Error: duplicate `asm` qualifier `volatile`
fail_compilation/gccasm2.c(34): Error: duplicate `asm` qualifier `volatile`
fail_compilation/gccasm2.c(35): Error: duplicate `asm` qualifier `volatile`
fail_compilation/gccasm2.c(36): Error: duplicate `asm` qualifier `goto`
fail_compilation/gccasm2.c(37): Error: duplicate `asm` qualifier `goto`
fail_compilation/gccasm2.c(38): Error: duplicate `asm` qualifier `goto`
fail_compilation/gccasm2.c(40): Error: duplicate `asm` qualifier `volatile`
fail_compilation/gccasm2.c(41): Error: duplicate `asm` qualifier `volatile`
fail_compilation/gccasm2.c(42): Error: duplicate `asm` qualifier `volatile`
fail_compilation/gccasm2.c(43): Error: duplicate `asm` qualifier `inline`
fail_compilation/gccasm2.c(44): Error: duplicate `asm` qualifier `inline`
fail_compilation/gccasm2.c(45): Error: duplicate `asm` qualifier `inline`
fail_compilation/gccasm2.c(47): Error: duplicate `asm` qualifier `inline`
fail_compilation/gccasm2.c(48): Error: duplicate `asm` qualifier `inline`
fail_compilation/gccasm2.c(49): Error: duplicate `asm` qualifier `inline`
fail_compilation/gccasm2.c(50): Error: duplicate `asm` qualifier `goto`
fail_compilation/gccasm2.c(51): Error: duplicate `asm` qualifier `goto`
fail_compilation/gccasm2.c(52): Error: duplicate `asm` qualifier `goto`
---
 */
void test1()
{
    asm const ("");
    asm restrict ("");
}

void test2()
{
    asm goto volatile volatile ("");
    asm volatile goto volatile ("");
    asm volatile volatile goto ("");
    asm goto goto volatile ("");
    asm goto volatile goto ("");
    asm volatile goto goto ("");

    asm inline volatile volatile ("");
    asm volatile inline volatile ("");
    asm volatile volatile inline ("");
    asm inline inline volatile ("");
    asm inline volatile inline ("");
    asm volatile inline inline ("");

    asm goto inline inline ("");
    asm inline goto inline ("");
    asm inline inline goto ("");
    asm goto goto inline ("");
    asm goto inline goto ("");
    asm inline goto goto ("");
}
