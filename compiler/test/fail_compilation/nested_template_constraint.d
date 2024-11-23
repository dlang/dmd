/*
TEST_OUTPUT:
---
fail_compilation/nested_template_constraint.d(23): Error: template `foo` is not callable using argument types `!()(string, int)`
    foo("hello", 4);
       ^
fail_compilation/nested_template_constraint.d(16):        Candidate is: `foo(int x = 0)`
template foo(int x = 0) {
^
fail_compilation/nested_template_constraint.d(17):          - Containing: `foo(T, U)(T t, U u)`
    void foo(T, U)(T t, U u)
         ^
---
*/

template foo(int x = 0) {
    void foo(T, U)(T t, U u)
        if (is(T == int) && is(U == int)) {}
}

void main()
{
    foo("hello", 4);
}
