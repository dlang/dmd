/*
TEST_OUTPUT:
---
fail_compilation/fail341.d(30): Error: struct `fail341.S` is not copyable because field `t` is not copyable
    auto t = s;
         ^
fail_compilation/fail341.d(31): Error: function `fail341.foo` cannot be used because it is annotated with `@disable`
    foo();
       ^
---
*/

struct T
{
    @disable this(this)
    {
    }
}

struct S
{
    T t;
}

@disable void foo() { }

void main()
{
    S s;
    auto t = s;
    foo();
}
