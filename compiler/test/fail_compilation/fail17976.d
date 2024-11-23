/*
TEST_OUTPUT:
---
fail_compilation/fail17976.d(15): Error: constructor `fail17976.S.this` parameter `this.a` is already defined
    this(string a, string a, string a)
    ^
fail_compilation/fail17976.d(15): Error: constructor `fail17976.S.this` parameter `this.a` is already defined
    this(string a, string a, string a)
    ^
---
*/

struct S
{
    this(string a, string a, string a)
    {
    }
}

void main()
{
}
