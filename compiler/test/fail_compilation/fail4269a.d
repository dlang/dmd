/*
TEST_OUTPUT:
---
fail_compilation/fail4269a.d(18): Error: undefined identifier `B`
    B blah;
      ^
fail_compilation/fail4269a.d(18): Error: field `blah` not allowed in interface
    B blah;
      ^
fail_compilation/fail4269a.d(19): Error: undefined identifier `B`
    void foo(B b){}
         ^
---
*/
enum bool WWW = is(typeof(A.x));

interface A {
    B blah;
    void foo(B b){}
}
