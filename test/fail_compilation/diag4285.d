/*
TEST_OUTPUT:
---
fail_compilation/diag4285.d(2): Error: template definitions aren't allowed inside functions
fail_compilation/diag4285.d(3): Error: unrecognized declaration
---
*/

#line 1
void main() {
    template Foo() {}
}
