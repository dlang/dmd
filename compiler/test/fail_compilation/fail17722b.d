/* TEST_OUTPUT:
---
fail_compilation/fail17722b.d(14): Error: static assert:  `__traits(compiles, a1 || a2)` is false
    static assert(__traits(compiles, a1 || a2));  // diagnostic was (__error) || (__error)
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17722

void fail17722b()
{
    byte[16] a1, a2;
    static assert(__traits(compiles, a1 || a2));  // diagnostic was (__error) || (__error)
}
