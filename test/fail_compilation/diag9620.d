/*
TEST_OUTPUT:
---
fail_compilation/diag9620.d(16): Error: pure function 'diag9620.main.bar' cannot call impure function 'diag9620.foot!().foot'
fail_compilation/diag9620.d(17): Error: pure function 'diag9620.main.bar' cannot call impure function 'diag9620.foo'
---
*/

int x;

void foot()() { x = 3; }
void foo() { }

void main() pure {
    void bar() {
        foot();
        foo();
    }
}
