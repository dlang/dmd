/*
REQUIRED_ARGS: -c
PERMUTE_ARGS:
TEST_OUTPUT:
---
0
---
*/
struct S { T* t; }
struct T { string name; }

S foo(string name)
{
    return S(new T(name[0 .. $]));
}

int bar(string name)
{
    return cast(int)name.length;
}

const S s = foo("");
enum b = bar(s.t.name);
pragma(msg, b);
