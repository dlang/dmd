// https://issues.dlang.org/show_bug.cgi?id=5435
/*
TEST_OUTPUT:
---
cast(Enum5435)0
cast(Enum5435)1
cast(Enum5435)2
fail_compilation/fail5435.d(38): Error: cannot implicitly convert expression `"foo"` of type `string` to `Enum5435`
fail_compilation/fail5435.d(38):        while evaluating `pragma(msg, foo)`
fail_compilation/fail5435.d(38): Error: cannot implicitly convert expression `3.00000` of type `double` to `Enum5435`
fail_compilation/fail5435.d(38):        while evaluating `pragma(msg, foo)`
fail_compilation/fail5435.d(39): Error: cannot implicitly convert expression `cast(Enum5435)0` of type `Enum5435` to `string`
fail_compilation/fail5435.d(39):        while evaluating `pragma(msg, foo)`
fail_compilation/fail5435.d(39): Error: cannot implicitly convert expression `cast(Enum5435)1` of type `Enum5435` to `string`
fail_compilation/fail5435.d(39):        while evaluating `pragma(msg, foo)`
fail_compilation/fail5435.d(39): Error: cannot implicitly convert expression `cast(Enum5435)2` of type `Enum5435` to `string`
fail_compilation/fail5435.d(39):        while evaluating `pragma(msg, foo)`
foo
fail_compilation/fail5435.d(39): Error: cannot implicitly convert expression `3.00000` of type `double` to `string`
fail_compilation/fail5435.d(39):        while evaluating `pragma(msg, foo)`
0
1
2
fail_compilation/fail5435.d(40): Error: cannot implicitly convert expression `"foo"` of type `string` to `int`
fail_compilation/fail5435.d(40):        while evaluating `pragma(msg, foo)`
fail_compilation/fail5435.d(40): Error: cannot implicitly convert expression `3.00000` of type `double` to `int`
fail_compilation/fail5435.d(40):        while evaluating `pragma(msg, foo)`
---
*/

template Tuple5435(E...) { alias E Tuple5435; }
enum Enum5435 { A, B, C };

void main()
{
    alias Tuple5435!(Enum5435.A, Enum5435.B, Enum5435.C, "foo", 3.0) tup;

    foreach (Enum5435 foo; tup) pragma(msg, foo);
    foreach (  string foo; tup) pragma(msg, foo);
    foreach (     int foo; tup) pragma(msg, foo);
}
