/*
TEST_OUTPUT:
---
fail_compilation/fail27.d(27): Error: cannot implicitly convert expression `-32769` of type `int` to `short`
    short a = -32769; // short.min-1
               ^
fail_compilation/fail27.d(28): Error: cannot implicitly convert expression `-129` of type `int` to `byte`
    byte  b = -129; // byte.min-1
               ^
fail_compilation/fail27.d(29): Error: cannot implicitly convert expression `-1` of type `int` to `char`
    char  c = -1; // char.min-1
               ^
fail_compilation/fail27.d(30): Error: cannot implicitly convert expression `65536` of type `int` to `wchar`
    wchar D = 65536; // wchar.max+1
              ^
fail_compilation/fail27.d(31): Error: cannot implicitly convert expression `-1` of type `int` to `wchar`
    wchar d = -1; // wchar.min-1
               ^
fail_compilation/fail27.d(33): Error: cannot implicitly convert expression `-1` of type `int` to `dchar`
    dchar e = -1; // dchar.min-1
               ^
---
*/

void main()
{
    short a = -32769; // short.min-1
    byte  b = -129; // byte.min-1
    char  c = -1; // char.min-1
    wchar D = 65536; // wchar.max+1
    wchar d = -1; // wchar.min-1
    dchar E = 1114111; // dchar.max+1
    dchar e = -1; // dchar.min-1
}
