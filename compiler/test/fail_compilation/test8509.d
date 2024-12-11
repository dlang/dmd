/*
TEST_OUTPUT:
---
fail_compilation/test8509.d(17): Error: cannot implicitly convert expression `"hello world"` of type `string` to `E`
    E e1 = E.a ~ " world";
           ^
fail_compilation/test8509.d(18): Error: cannot implicitly convert expression `"hello world"` of type `string` to `E`
    E e2 = "hello " ~ E.b;
           ^
---
*/
module test8509;
enum E : string { a = "hello", b = "world" }

void main()
{
    E e1 = E.a ~ " world";
    E e2 = "hello " ~ E.b;
}
