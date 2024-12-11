// https://issues.dlang.org/show_bug.cgi?id=21314
/* TEST_OUTPUT:
---
fail_compilation/fail21314.d(12): Error: variable `fail21314.C21314.c21314` cannot have `extern(C++)` linkage because it is `static`
    static C21314[] c21314;
                    ^
fail_compilation/fail21314.d(12):        perhaps declare it as `__gshared` instead
---
*/
extern(C++) class C21314
{
    static C21314[] c21314;
}
