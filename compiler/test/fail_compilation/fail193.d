/*
TEST_OUTPUT:
---
fail_compilation/fail193.d(16): Error: cannot infer type from overloaded function symbol `& foo`
    auto fp = &foo;
              ^
---
*/

void foo() { }
void foo(int) { }

void main()
{
    //void function(int) fp = &foo;
    auto fp = &foo;
    fp(1);
}
