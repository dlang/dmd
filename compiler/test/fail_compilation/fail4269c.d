/*
TEST_OUTPUT:
---
fail_compilation/fail4269c.d(15): Error: undefined identifier `B`
    B blah;
      ^
fail_compilation/fail4269c.d(16): Error: undefined identifier `B`
    void foo(B b){}
         ^
---
*/
enum bool WWW = is(typeof(A.x));

class A {
    B blah;
    void foo(B b){}
}
