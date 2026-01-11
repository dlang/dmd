/* TEST_OUTPUT:
---
fail_compilation/testfinal.d(26): Error: cannot take mutable ref to final variable `i`, use `const ref`
fail_compilation/testfinal.d(27): Error: cannot modify `final i`
fail_compilation/testfinal.d(28): Error: cannot implicitly convert `const(int)*` to `int*`
fail_compilation/testfinal.d(28):        Note: Converting const to mutable requires an explicit cast (`cast(int*)`).
fail_compilation/testfinal.d(29): Error: cannot modify final `i` with ref to mutable
fail_compilation/testfinal.d(30): Error: cannot modify `final i`
fail_compilation/testfinal.d(31): Error: cannot pass final `i` to `out` parameter
fail_compilation/testfinal.d(51): Error: cannot modify `final tbuf[3]`
fail_compilation/testfinal.d(54): Error: cannot modify `final y[0][0]`
---
*/

void legal()
{
    final int i = 3;
    const ref r = i;
    const(int)*p = &i;
    pppp(i);
}

void illegal()
{
    final int i = 3;
    ref int r = i;
    i = 4;
    int* p = &i;
    tttt(i);
    ++i;
    oooo(i);
}

void tttt(ref int r);
void pppp(ref const int r);
void oooo(out int r);

class C
{
    final int fo();
}

void legal2(C c)
{
    auto dg = &c.fo;
}

void teststaticarray()
{
    final char[64] tbuf;
    tbuf[3] = 'c';

    final int[3][1] y = [[1,2,3]];
    y[0][0] = 2;
}
