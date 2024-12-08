/*
REQUIRED_ARGS: -checkaction=context
EXTRA_SOURCES: extra-files/minimal/object.d
*/

/************************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/verifyhookexist.d(34): Error: `object.__ArrayCast` not found. The current runtime does not support casting array of structs, or the runtime is corrupt.
    return cast(MyStruct[])arr;
           ^
fail_compilation/verifyhookexist.d(40): Error: `object.__equals` not found. The current runtime does not support equal checks on arrays, or the runtime is corrupt.
    bool a = arrA[] == arrB[];
             ^
fail_compilation/verifyhookexist.d(41): Error: `object.__cmp` not found. The current runtime does not support comparing arrays, or the runtime is corrupt.
    bool b = arrA < arrB;
             ^
fail_compilation/verifyhookexist.d(45): Error: `object._d_assert_fail` not found. The current runtime does not support generating assert messages, or the runtime is corrupt.
        assert(x == y);
        ^
fail_compilation/verifyhookexist.d(48): Error: `object.__switch` not found. The current runtime does not support switch cases on strings, or the runtime is corrupt.
    switch ("") {
    ^
fail_compilation/verifyhookexist.d(53): Error: `object.__switch_error` not found. The current runtime does not support generating assert messages, or the runtime is corrupt.
    final switch (0) {
    ^
---
*/

struct MyStruct { int a, b; }
MyStruct[] castToMyStruct(int[] arr) {
    return cast(MyStruct[])arr;
}

void test() {
    int[] arrA, arrB;

    bool a = arrA[] == arrB[];
    bool b = arrA < arrB;

    {
        int x = 1; int y = 1;
        assert(x == y);
    }

    switch ("") {
    default:
        break;
    }

    final switch (0) {
    case 1:
        break;
    }
}
