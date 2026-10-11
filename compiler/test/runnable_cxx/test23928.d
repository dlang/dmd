// EXTRA_CPP_SOURCES: test23928.cpp
// CXXFLAGS(osx linux freebsd openbsd netbsd dragonflybsd solaris): -std=c++11 -O2
// CXXFLAGS(windows): /std:c11 /O2

int baseDestroyed;
int sDestroyed;

struct S
{
    ~this() { sDestroyed++; }
}

extern(C++) class Base
{
    ~this() { baseDestroyed++; }
}

extern(C++) class Derived : Base
{
    S s;
}

extern(C++) void deleteFromCpp(Base b);

void main()
{
    deleteFromCpp(new Derived);
    assert(sDestroyed == 1);
    assert(baseDestroyed == 1);
}
