/*
REQUIRED_ARGS: -preview=rvaluerefparam
TEST_OUTPUT:
---
---

RUN_OUTPUT:
---
Success
---
*/

import core.stdc.stdio;

/***************************************************/

struct S5
{
    int mX;
    string mY;

    ref int x() return
    {
        return mX;
    }
    ref string y() return
    {
        return mY;
    }

    ref int err(Object)
    {
        static int v;
        return v;
    }
}

void test5()
{
    S5 s;
    s.x += 4;
    assert(s.mX == 4);
    s.x -= 2;
    assert(s.mX == 2);
    s.x *= 4;
    assert(s.mX == 8);
    s.x /= 2;
    assert(s.mX == 4);
    s.x %= 3;
    assert(s.mX == 1);
    s.x <<= 3;
    assert(s.mX == 8);
    s.x >>= 1;
    assert(s.mX == 4);
    s.x >>>= 1;
    assert(s.mX == 2);
    s.x &= 0xF;
    assert(s.mX == 0x2);
    s.x |= 0x8;
    assert(s.mX == 0xA);
    s.x ^= 0xF;
    assert(s.mX == 0x5);

    s.x ^^= 2;
    assert(s.mX == 25);

    s.mY = "ABC";
    s.y ~= "def";
    assert(s.mY == "ABCdef");

    static assert(!__traits(compiles, s.err += 1));
}

/***************************************************/

int main()
{
    test5();

    printf("Success\n");
    return 0;
}
