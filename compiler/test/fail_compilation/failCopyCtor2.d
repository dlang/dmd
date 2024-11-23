/*
TEST_OUTPUT:
---
fail_compilation/failCopyCtor2.d(21): Error: `struct B` may not define a rvalue constructor and have fields with copy constructors
struct B
^
fail_compilation/failCopyCtor2.d(24):        rvalue constructor defined here
    this(immutable B b) shared {}
    ^
fail_compilation/failCopyCtor2.d(23):        field with copy constructor defined here
    A a;
      ^
---
*/

struct A
{
    this (ref shared A a) immutable {}
}

struct B
{
    A a;
    this(immutable B b) shared {}
}
