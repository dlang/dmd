/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/fail22366.d(36): Error: scope variable `s` may not be copied into allocated memory
    aa[s] ^^= 3;
       ^
fail_compilation/fail22366.d(39): Error: scope variable `s` may not be copied into allocated memory
    saa[""] = s;
              ^
fail_compilation/fail22366.d(40): Error: scope variable `s` may not be copied into allocated memory
    saa[""] ~= s;
               ^
fail_compilation/fail22366.d(41): Error: scope variable `s` may not be copied into allocated memory
    saa[s] = "";
        ^
fail_compilation/fail22366.d(42): Error: scope variable `s` may not be copied into allocated memory
    saa[s] ~= "";
        ^
fail_compilation/fail22366.d(45): Error: scope variable `s` may not be copied into allocated memory
    snaa[s][""] = "";
         ^
fail_compilation/fail22366.d(46): Error: scope variable `s` may not be copied into allocated memory
    snaa[""][s] = "";
             ^
---
*/

// Test escaping scope variables through AA keys / values
// https://issues.dlang.org/show_bug.cgi?id=22366
// https://issues.dlang.org/show_bug.cgi?id=23531

void fun(scope string s) @safe
{
    int[string] aa;
    aa[s] ^^= 3;

    string[string] saa;
    saa[""] = s;
    saa[""] ~= s;
    saa[s] = "";
    saa[s] ~= "";

    string[string][string] snaa;
    snaa[s][""] = "";
    snaa[""][s] = "";
}
