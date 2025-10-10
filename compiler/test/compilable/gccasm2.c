void test1()
{
    asm goto ("");
    asm inline ("");
    asm volatile ("");
}

void test2()
{
    asm volatile goto ("");
    asm volatile inline ("");
    asm inline volatile ("");
    asm inline goto ("");
    asm goto volatile ("");
    asm goto inline ("");

    asm volatile inline goto ("");
    asm volatile goto inline ("");
    asm inline volatile goto ("");
    asm inline goto volatile ("");
    asm goto volatile inline ("");
    asm goto inline volatile ("");
}
