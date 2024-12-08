/*
TEST_OUTPUT:
---
fail_compilation/fail11163.d(16): Error: cannot implicitly convert expression `foo()` of type `int[]` to `immutable(int[])`
    immutable a = foo();
                     ^
fail_compilation/fail11163.d(17):        while evaluating `pragma(msg, a)`
    pragma(msg, a);
    ^
---
*/
int[] foo() {
    return [1];
}
void main() {
    immutable a = foo();
    pragma(msg, a);
}
