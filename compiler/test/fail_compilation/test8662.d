/*
TEST_OUTPUT:
---
fail_compilation/test8662.d(22): Error: label `Label` is already defined
fail_compilation/test8662.d(21):        first definition is here
fail_compilation/test8662.d(25): Error: label `Label` is already defined
fail_compilation/test8662.d(21):        first definition is here
fail_compilation/test8662.d(31): Error: label `Label2` is duplicated
fail_compilation/test8662.d(31):        labels cannot be used in a static foreach with more than 1 iteration
fail_compilation/test8662.d(36): Error: label `Label3` is duplicated
fail_compilation/test8662.d(36):        labels cannot be used in a static foreach with more than 1 iteration
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
