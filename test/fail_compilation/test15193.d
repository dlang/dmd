/* REQUIRED_ARGS: -dip25
   TEST_OUTPUT:
---
fail_compilation/test15193.d(17): Error: escaping reference to local variable s
---
*/


// https://issues.dlang.org/show_bug.cgi?id=15193

ref int foo()@safe{
    struct S{
        int x;
        ref int bar() { return x; }
    }
    S s;
    return s.bar();
}

