/*
TEST_OUTPUT:
---
fail_compilation/discard_value.d(30): Error: the result of the equality expression `3 is 3` is discarded
fail_compilation/discard_value.d(31): Error: the result of the equality expression `null !is null` is discarded
fail_compilation/discard_value.d(32): Error: the result of the equality expression `v == 0` is discarded
fail_compilation/discard_value.d(33): Error: the result of the equality expression `v == 0` is discarded
fail_compilation/discard_value.d(34): Error: the result of the equality expression `"" != ""` is discarded
fail_compilation/discard_value.d(35): Error: the result of the equality expression `"" == ""` is discarded
fail_compilation/discard_value.d(36): Error: the result of the equality expression `fun().i == 4` is discarded
fail_compilation/discard_value.d(36):        note that `fun().i` may have a side effect
fail_compilation/discard_value.d(39): Error: the result of the equality expression `slice == slice[0..0]` is discarded
fail_compilation/discard_value.d(51): Error: the result of the equality expression `s.opEquals(1)` is discarded
fail_compilation/discard_value.d(55): Error: the result of the equality expression `c.opEquals(s)` is discarded
---
*/

struct S
{
    int i;
    bool opEquals(int);
}

S fun() { return S(42); }

int v;

void main()
{
    3 is 3;
    null !is null;
    true && v == 0;
    true || v == 0;
    "" != "";
    "" == ""; // https://issues.dlang.org/show_bug.cgi?id=24359
    fun().i == 4; // https://issues.dlang.org/show_bug.cgi?id=12390

    int[] slice = [0, 1];
    slice == slice[0 .. 0];
}

class C
{
    bool opEquals(ref const S) pure nothrow const;
}

// https://github.com/dlang/dmd/issues/19239
void test()
{
    S s;
    s == 1;
    s.opEquals(1); // allowed

    C c;
    c == s;
    c.opEquals(s); // FIXME, should error as S.opEquals can't have side effects
}
