/*
TEST_OUTPUT:
---
fail_compilation/ice14130.d(16): Error: undefined identifier `Undef`
F foo(R, F = Undef)(R r, F s = 0) {}
         ^
fail_compilation/ice14130.d(20): Error: template `foo` is not callable using argument types `!()(int)`
    0.foo;
     ^
fail_compilation/ice14130.d(16):        Candidate is: `foo(R, F = Undef)(R r, F s = 0)`
F foo(R, F = Undef)(R r, F s = 0) {}
  ^
---
*/

F foo(R, F = Undef)(R r, F s = 0) {}

void main()
{
    0.foo;
}
