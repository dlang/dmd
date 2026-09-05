/*
TEST_OUTPUT:
---
fail_compilation/diag20040.d(19): Error: variable name expected after type `b`, not `+=`
fail_compilation/diag20040.d(16):        closing brace on line 16 appears mismatched (opened on line 13)
fail_compilation/diag20040.d(19): Error: declaration expected, not `+=`
fail_compilation/diag20040.d(25): Error: unmatched closing brace
---
*/
class A {
    void foo() {
        int b;
           void nested() {
               if (true) {
               }
               }
           }

           b += 5;
    }

    void bar() {

    }
}
