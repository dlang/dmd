/*
TEST_OUTPUT:
---
fail_compilation/test8509.d(15): Error: cannot implicitly convert expression `"hello world"` of type `string` to `E`
fail_compilation/test8509.d(15):        `e1` should be of type `const(string)` or `immutable(string)` and not `string`
fail_compilation/test8509.d(16): Error: cannot implicitly convert expression `"hello world"` of type `string` to `E`
fail_compilation/test8509.d(16):        `e2` should be of type `const(string)` or `immutable(string)` and not `string`
---
*/
module test8509;
enum E : string { a = "hello", b = "world" }

void main()
{
    E e1 = E.a ~ " world";
    E e2 = "hello " ~ E.b;
}
