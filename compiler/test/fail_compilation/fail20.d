/*
TEST_OUTPUT:
---
fail_compilation/fail20.d(18): Error: need member function `opCmp()` for struct `FOO` to compare
    if (one < two){} // This should tell me that there
        ^
---
*/

// ICE(cod3) DMD0.080

struct FOO{}

void main()
{
    FOO one;
    FOO two;
    if (one < two){} // This should tell me that there
                     // is no opCmp() defined instead
                     // of crashing.
}
