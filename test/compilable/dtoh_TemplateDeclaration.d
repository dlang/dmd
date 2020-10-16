/*
REQUIRED_ARGS: -HC -c -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
// Automatically generated by Digital Mars D Compiler

#pragma once

#include <stddef.h>
#include <stdint.h>


template <typename T>
struct A
{
    // Ignoring var x alignment 0
public:
    T x;
};

struct B
{
    A<int32_t> x;
    B() :
        x()
    {
    }
};

template <typename T>
struct Foo
{
    // Ignoring var val alignment 0
    T val;
};

template <typename T>
struct Bar
{
    // Ignoring var v alignment 0
    Foo<T> v;
};
---
*/

extern (C++) struct A(T)
{
    T x;
    // enum Num = 42; // dtoh segfaults at enum

    void foo() {}
}

extern (C++) struct B
{
    A!int x;
}

// https://issues.dlang.org/show_bug.cgi?id=20604
extern(C++)
{
    struct Foo (T)
    {
        T val;
    }

    struct Bar (T)
    {
        Foo!T v;
    }
}
