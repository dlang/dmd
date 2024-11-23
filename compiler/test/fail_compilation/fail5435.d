// https://issues.dlang.org/show_bug.cgi?id=5435
/*
TEST_OUTPUT:
---
Enum5435.A
Enum5435.B
Enum5435.C
fail_compilation/fail5435.d(70): Error: cannot implicitly convert expression `"foo"` of type `string` to `Enum5435`
    foreach (Enum5435 foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(70):        while evaluating `pragma(msg, foo)`
    foreach (Enum5435 foo; tup) pragma(msg, foo);
                                ^
fail_compilation/fail5435.d(70): Error: cannot implicitly convert expression `3.0` of type `double` to `Enum5435`
    foreach (Enum5435 foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(70):        while evaluating `pragma(msg, foo)`
    foreach (Enum5435 foo; tup) pragma(msg, foo);
                                ^
fail_compilation/fail5435.d(71): Error: cannot implicitly convert expression `Enum5435.A` of type `Enum5435` to `string`
    foreach (  string foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(71):        while evaluating `pragma(msg, foo)`
    foreach (  string foo; tup) pragma(msg, foo);
                                ^
fail_compilation/fail5435.d(71): Error: cannot implicitly convert expression `Enum5435.B` of type `Enum5435` to `string`
    foreach (  string foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(71):        while evaluating `pragma(msg, foo)`
    foreach (  string foo; tup) pragma(msg, foo);
                                ^
fail_compilation/fail5435.d(71): Error: cannot implicitly convert expression `Enum5435.C` of type `Enum5435` to `string`
    foreach (  string foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(71):        while evaluating `pragma(msg, foo)`
    foreach (  string foo; tup) pragma(msg, foo);
                                ^
foo
fail_compilation/fail5435.d(71): Error: cannot implicitly convert expression `3.0` of type `double` to `string`
    foreach (  string foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(71):        while evaluating `pragma(msg, foo)`
    foreach (  string foo; tup) pragma(msg, foo);
                                ^
0
1
2
fail_compilation/fail5435.d(72): Error: cannot implicitly convert expression `"foo"` of type `string` to `int`
    foreach (     int foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(72):        while evaluating `pragma(msg, foo)`
    foreach (     int foo; tup) pragma(msg, foo);
                                ^
fail_compilation/fail5435.d(72): Error: cannot implicitly convert expression `3.0` of type `double` to `int`
    foreach (     int foo; tup) pragma(msg, foo);
                           ^
fail_compilation/fail5435.d(72):        while evaluating `pragma(msg, foo)`
    foreach (     int foo; tup) pragma(msg, foo);
                                ^
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
