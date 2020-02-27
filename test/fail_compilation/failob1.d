/* REQUIRED_ARGS: -verrors=0
TEST_OUTPUT:
---
fail_compilation/failob1.d(104): Error: variable `failob1.test1.a1` is left dangling at return
fail_compilation/failob1.d(105): Error: variable `failob1.test2.a2` is left dangling at return
fail_compilation/failob1.d(107): Error: variable `failob1.test4.s4` is left dangling at return
fail_compilation/failob1.d(108): Error: variable `failob1.test5.dg5` is left dangling at return
fail_compilation/failob1.d(115): Error: variable `failob1.test12.p12` is left dangling at return
---
*/

struct S { int i; int* f; }
struct T { int i; const(int)* f; }
class C { int i; int* f; }

#line 100

@live
{
    // Test what is and is not a trackable variable
    @live void test1(int[] a1) { }            // error
    @live void test2(int*[3] a2) { }          // error
    @live void test3(const int*[3] a) { }     // ok
    @live void test4(S s4) { }                // error
    @live void test5(int delegate() dg5) { }  // error
    @live void test6(const(int*)[3] a) { }    // ok
    @live void test7(const(int)*[3] a) { }    // ok
    @live void test8(const(int)* p) { }       // ok
    @live void test9(T t) { }                 // ok
    @live void test10(C c) { }                // ok
    @live void test11(int i) { }              // ok
    @live void test12(int* p12) { }           // error
}
