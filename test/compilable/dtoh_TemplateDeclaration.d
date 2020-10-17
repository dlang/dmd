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
    void foo();
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

template <typename T>
struct Array
{
    typedef Array This;
    typedef typeof(1 + 2) Int;
    typedef typeof(T::a) IC;
    Array(size_t dim);
    ~Array();
    void get() const;
    template <typename T>
    bool opCast() const;
};

template <typename T, typename U>
extern T foo(U u);
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

extern (C++) struct Array(T)
{
    alias This = typeof(this);
    alias Int = typeof(1 + 2);
    alias IC = typeof(T.a);

    this(size_t dim) pure nothrow {}
    @disable this(this);
    ~this() {}
    void get() const {}

    bool opCast(T)() const pure nothrow @nogc @safe
    if (is(T == bool))
    {
        return str.ptr !is null;
    }
}

extern(C++) T foo(T, U)(U u) { return T.init; }
