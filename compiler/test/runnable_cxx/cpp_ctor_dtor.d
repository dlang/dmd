/*
Construction and destruction of extern(C++) classes, across hierarchies defined in D, in C++,
and mixed in both directions: virtual destructor dispatch through a base reference, chaining
through every base, field destruction order, gaps in the hierarchy, and the Itanium
base-object constructor and destructor variants.

EXTRA_CPP_SOURCES: cpp_ctor_dtor.cpp
CXXFLAGS(linux osx freebsd openbsd netbsd dragonflybsd solaris): -fno-rtti
CXXFLAGS(windows): /GR-
*/

import core.stdc.stdio;

extern(C) __gshared char[64] trace;
extern(C) __gshared int trace_len;

extern(C) void trace_log(char c)
{
    trace[trace_len++] = c;
}

void check(const(char)* name, const(char)[] expect)
{
    const(char)[] got = trace[0 .. trace_len];
    if (got != expect)
    {
        printf("FAIL %s: expected \"%.*s\", got \"%.*s\"\n", name, cast(int)expect.length, expect.ptr, cast(int)got.length, got.ptr);
        assert(0);
    }
    trace_len = 0;
}

struct F(char c)
{
    ~this() { trace_log(c); }
}

T make(T)()
{
    __gshared void[256] buf;
    enum size = __traits(classInstanceSize, T);
    static assert(size <= buf.length);
    buf[0 .. size] = __traits(initSymbol, T)[];
    T t = cast(T)buf.ptr;
    static if (__traits(hasMember, T, "__ctor"))
        t.__ctor();
    return t;
}

extern(C++):

// every class declares a destructor
class A1 { ~this() { trace_log('a'); } }
class B1 : A1 { ~this() { trace_log('b'); } }
final class C1 : B1 { ~this() { trace_log('c'); } }

// a middle class with no destructor
class A2 { ~this() { trace_log('a'); } }
class B2 : A2 { int x; }
final class C2 : B2 { ~this() { trace_log('c'); } }

// a middle class with no destructor, a leaf whose only destructor comes from a field
class A3 { ~this() { trace_log('a'); } }
class B3 : A3 { int x; }
final class C3 : B3 { F!'f' f; }

// a middle class whose only destructor comes from a field
class A4 { ~this() { trace_log('a'); } }
class B4 : A4 { F!'b' b; }
final class C4 : B4 { ~this() { trace_log('c'); } }

// several gaps
class A5 { ~this() { trace_log('a'); } }
class B5 : A5 { int x; }
class C5 : B5 { int y; }
final class D5 : C5 { ~this() { trace_log('d'); } }

// body first, then fields in reverse declaration order, then the base
class A6 { F!'x' x; F!'y' y; ~this() { trace_log('a'); } }
final class B6 : A6 { F!'z' z; ~this() { trace_log('b'); } }

// two field-only levels under a gap
class A7 { ~this() { trace_log('a'); } }
class B7 : A7 { int x; }
class C7 : B7 { F!'c' c; }
final class D7 : C7 { F!'d' d; }

// the destructor declared extern(D) inside an extern(C++) class
class A8 { extern(D) ~this() { trace_log('a'); } }
class B8 : A8 { int x; }
final class C8 : B8 { ~this() { trace_log('c'); } }

// a root with virtual functions but no destructor of its own is, like C++, not virtual
class A9 { F!'x' x; void f() {} }
final class B9 : A9 { ~this() { trace_log('b'); } }

// a D class deriving from a C++ class with a virtual destructor
class CppBase
{
    ~this();
    int id();
}
final class DFromCpp : CppBase
{
    ~this() { trace_log('d'); }
    override int id() { return 10; }
}

// a C++ class deriving from a D class; C++ constructs and destroys the D base subobject
class DBase
{
    this() { trace_log('A'); }
    ~this() { trace_log('B'); }
    int id() { return 1; }
}
DBase make_cpp_from_d();

void cpp_destroy_a2(A2 p);
void cpp_destroy_a3(A3 p);
void cpp_destroy_a5(A5 p);
void cpp_destroy_cppbase(CppBase p);
void cpp_destroy_dbase(DBase p);

extern(D):

void main()
{
    A1 a1 = make!C1(); a1.__xdtor(); check("chain", "cba");
    A2 a2 = make!C2(); a2.__xdtor(); check("gap", "ca");
    A3 a3 = make!C3(); a3.__xdtor(); check("gap, field-only leaf", "fa");
    A4 a4 = make!C4(); a4.__xdtor(); check("field-only middle", "cba");
    A5 a5 = make!D5(); a5.__xdtor(); check("two gaps", "da");
    A6 a6 = make!B6(); a6.__xdtor(); check("field order", "bzayx");
    A7 a7 = make!D7(); a7.__xdtor(); check("field-only levels under a gap", "dca");
    A8 a8 = make!C8(); a8.__xdtor(); check("extern(D) destructor", "ca");
    B9 b9 = make!B9(); b9.__xdtor(); check("exact type, root without destructor", "bx");

    A2 d2 = make!C2(); destroy(d2); check("destroy(): gap", "ca");
    A7 d7 = make!D7(); destroy(d7); check("destroy(): field-only levels", "dca");

    cpp_destroy_a2(make!C2()); check("C++ ~A2(): gap", "ca");
    cpp_destroy_a3(make!C3()); check("C++ ~A3(): field-only leaf", "fa");
    cpp_destroy_a5(make!D5()); check("C++ ~A5(): two gaps", "da");

    CppBase cb = make!DFromCpp(); cb.__xdtor(); check("D ~CppBase(): D derived", "dP");
    cpp_destroy_cppbase(make!DFromCpp()); check("C++ ~CppBase(): D derived", "dP");

    DBase db = make_cpp_from_d(); check("C++ derived: constructed", "AC");
    assert(db.id() == 2);
    db.__xdtor(); check("D ~DBase(): C++ derived", "EB");
    cpp_destroy_dbase(make_cpp_from_d()); check("C++ ~DBase(): C++ derived", "ACEB");

    printf("cpp_ctor_dtor: all passed\n");
}
