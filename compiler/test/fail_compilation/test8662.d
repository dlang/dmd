/*
TEST_OUTPUT:
---
fail_compilation/test8662.d(34): Error: label `Label` is already defined
        Label:
        ^
fail_compilation/test8662.d(33):        first definition is here
        Label:
        ^
fail_compilation/test8662.d(37): Error: label `Label` is already defined
        Label:
        ^
fail_compilation/test8662.d(33):        first definition is here
        Label:
        ^
fail_compilation/test8662.d(43): Error: label `Label2` is duplicated
        Label2:
        ^
fail_compilation/test8662.d(43):        labels cannot be used in a static foreach with more than 1 iteration
fail_compilation/test8662.d(48): Error: label `Label3` is duplicated
        Label3:
        ^
fail_compilation/test8662.d(48):        labels cannot be used in a static foreach with more than 1 iteration
---
*/
// Issue 8662 - Labels rejected in static foreach loop

alias AliasSeq(T...) = T;

void f()
{
    {
        Label:
        Label:
    }
    {
        Label:
        Label:
    }
    // static foreach
    foreach (x; AliasSeq!(1, 2, 3, 4, 5))
    {
        Label2:
    }

    static foreach (x; 0 .. 3)
    {
        Label3:
    }
}
