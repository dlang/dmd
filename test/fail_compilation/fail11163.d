/*
TEST_OUTPUT:
---
fail_compilation/fail11163.d(13): Error: cannot implicitly convert expression (foo()) of type int[] to immutable(int[])
fail_compilation/fail11163.d(14):        while evaluating a.init
fail_compilation/fail11163.d(14):        while evaluating pragma(msg, a)
---
*/
int[] foo() {
    return [1];
}
void main() {
    immutable a = foo();
    pragma(msg, a);
}

