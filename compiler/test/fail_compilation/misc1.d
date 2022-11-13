/*
TEST_OUTPUT:
---
fail_compilation/misc1.d(108): Error: `5` has no effect
fail_compilation/misc1.d(109): Error: `1 + 2` has no effect
fail_compilation/misc1.d(115): Error: `1 * 1` has no effect
fail_compilation/misc1.d(116): Error: `__lambda3` has no effect
fail_compilation/misc1.d(122): Error: `false` has no effect
---
*/

#line 100

/***************************************************/
//https://issues.dlang.org/show_bug.cgi?id=12490

void hasSideEffect12490(){}

void issue12490()
{
    5, hasSideEffect12490();
    1 + 2, hasSideEffect12490();
}

void issue23480()
{
    int j;
    for({} j; 1*1) {}
    for({j=2; int d = 3; } j+d<7; {j++; d++; }) {}
    for (
        if (true)        // (o_O)
            assert(78);
        else
            assert(79);
        false; false
    ) {}
}
