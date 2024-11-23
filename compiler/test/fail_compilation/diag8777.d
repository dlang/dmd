/*
TEST_OUTPUT:
---
fail_compilation/diag8777.d(28): Error: constructor `diag8777.Foo1.this` missing initializer for immutable field `x`
    this() {} // Constructor missing initializers for `x` and `y`
    ^
fail_compilation/diag8777.d(28): Error: constructor `diag8777.Foo1.this` missing initializer for const field `y`
    this() {} // Constructor missing initializers for `x` and `y`
    ^
fail_compilation/diag8777.d(34): Error: cannot modify `immutable` expression `x`
    x = 1;           // Error: `immutable` variable cannot be modified
    ^
fail_compilation/diag8777.d(37): Error: cannot modify `const` expression `y`
    y = 1;           // Error: `const` variable cannot be modified
    ^
fail_compilation/diag8777.d(44): Error: cannot remove key from `immutable` associative array `hashx`
    hashx.remove(1); // Error: cannot modify immutable associative array
                ^
fail_compilation/diag8777.d(45): Error: cannot remove key from `const` associative array `hashy`
    hashy.remove(1); // Error: cannot modify const associative array
                ^
---
*/
class Foo1
{
    immutable int[5] x;
    const int[5] y;
    this() {} // Constructor missing initializers for `x` and `y`
}

void test2()
{
    immutable int x; // Immutable variable `x` declared
    x = 1;           // Error: `immutable` variable cannot be modified

    const int y;     // Const variable `y` declared
    y = 1;           // Error: `const` variable cannot be modified
}

immutable(int[int]) hashx; // Immutable associative array
const(int[int]) hashy;     // Const associative array
void test3()
{
    hashx.remove(1); // Error: cannot modify immutable associative array
    hashy.remove(1); // Error: cannot modify const associative array
}
