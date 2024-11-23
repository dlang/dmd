/*
TEST_OUTPUT:
---
fail_compilation/discard_value.d(42): Error: the result of the equality expression `3 is 3` is discarded
    3 is 3;
    ^
fail_compilation/discard_value.d(43): Error: the result of the equality expression `null !is null` is discarded
    null !is null;
    ^
fail_compilation/discard_value.d(44): Error: the result of the equality expression `v == 0` is discarded
    true && v == 0;
            ^
fail_compilation/discard_value.d(45): Error: the result of the equality expression `v == 0` is discarded
    true || v == 0;
            ^
fail_compilation/discard_value.d(46): Error: `!__equals("", "")` has no effect
    "" != "";
    ^
fail_compilation/discard_value.d(47): Error: the result of the equality expression `"" == ""` is discarded
    "" == ""; // https://issues.dlang.org/show_bug.cgi?id=24359
    ^
fail_compilation/discard_value.d(48): Error: the result of the equality expression `fun().i == 4` is discarded
    fun().i == 4; // https://issues.dlang.org/show_bug.cgi?id=12390
    ^
fail_compilation/discard_value.d(48):        note that `fun().i` may have a side effect
    fun().i == 4; // https://issues.dlang.org/show_bug.cgi?id=12390
       ^
fail_compilation/discard_value.d(51): Error: the result of the equality expression `slice == slice[0..0]` is discarded
    slice == slice[0 .. 0];
    ^
---
*/

struct S { int i; }

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
