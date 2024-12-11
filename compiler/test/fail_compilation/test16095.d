/*
TEST_OUTPUT:
---
fail_compilation/test16095.d(24): Error: `shared` method `test16095.C.ping` is not callable using a non-shared `a`
    (&a.ping)(); // error
     ^
fail_compilation/test16095.d(34): Error: `shared` method `test16095.S.ping` is not callable using a non-shared `*a`
    (&a.ping)(); // error
     ^
fail_compilation/test16095.d(47): Error: mutable method `test16095.Foo.flip` is not callable using a `immutable` `foo`
    (&foo.flip)();      // error
     ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=16095

class C
{
    void ping() shared;
}

void test1(C a)
{
    (&a.ping)(); // error
}

struct S
{
    void ping() shared;
}

void test2(S* a)
{
    (&a.ping)(); // error
}

struct Foo {
   bool flag;
   void flip() {
        flag = true;
   }
}

void test3()
{
    immutable Foo foo;
    (&foo.flip)();      // error
}
