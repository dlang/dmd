// https://github.com/dlang/dmd/issues/23605
// EXTRA_CPP_SOURCES: test23605.cpp
// EXTRA_FILES: extra-files/test23605.h
// CXXFLAGS(osx linux freebsd openbsd netbsd dragonflybsd solaris): -std=c++11 -O2

import core.stdcpp.new_;

extern(C++) class A
{
    int i;
    ~this();
}

extern(C++) extern __gshared int lastDeleteA;

int lastDeleteB;

class B : A
{
    ~this()
    {
        lastDeleteB = i;
    }
}

static assert(__traits(getLinkage, B) == "C++");
static assert(__traits(getLinkage, B.__dtor) == "D");
static assert(__traits(getLinkage, B.__xdtor) == "C++");

extern(C++) void deleteFromCpp(A obj);

void main()
{
    {
        A obj = cpp_new!B();
        obj.i = 1;
        cpp_delete(obj);
        assert(lastDeleteA == 1);
        assert(lastDeleteB == 1);
    }
    {
        A obj = cpp_new!B();
        obj.i = 2;
        deleteFromCpp(obj);
        assert(lastDeleteA == 2);
        assert(lastDeleteB == 2);
    }
}
