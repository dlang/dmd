/*
TEST_OUTPUT:
---
compilable/b14854.d(10): Deprecation: constructor `b14854.C1.this` cannot be annotated with `@disable` because it has a body
---
*/

class C1
{
    @disable this() {}
}

class C2
{
    @disable this();
}

void main()
{
}
