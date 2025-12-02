/* TEST_OUTPUT:
---
fail_compilation/testfinal.d(24): Error: cannot take mutable ref to final variable `i`, use `const ref`
fail_compilation/testfinal.d(25): Error: cannot modify `final i`
fail_compilation/testfinal.d(26): Error: cannot implicitly convert `const(int)*` to `int*`
fail_compilation/testfinal.d(26):        Note: Converting const to mutable requires an explicit cast (`cast(int*)`).
fail_compilation/testfinal.d(27): Error: cannot modify final `i` with ref to mutable
fail_compilation/testfinal.d(28): Error: cannot modify `final i`
fail_compilation/testfinal.d(29): Error: cannot pass final `i` to `out` parameter
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
