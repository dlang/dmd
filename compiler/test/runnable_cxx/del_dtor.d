// EXTRA_CPP_SOURCES: del_dtor.cpp
// EXTRA_FILES: extra-files/del_dtor.h
// REQUIRED_ARGS: -extern-std=c++11
// CXXFLAGS(osx linux freebsd openbsd netbsd dragonflybsd solaris): -std=c++11

import core.stdc.string;
import core.stdcpp.new_;

extern(C++):

extern __gshared int newCount;
extern __gshared int deleteCount;

__gshared uint destructorCount;
struct DestructorCall
{
    const(char)[] name;
    int value;
}
__gshared DestructorCall[10] destructorValues;

void logDestructorCall(const(char)* name, int value)
{
    assert(destructorCount < destructorValues.length);
    destructorValues[destructorCount] = DestructorCall(name[0 .. strlen(name)], value);
    destructorCount++;
}

extern(D) DestructorCall[] loggedDestructorValues()
{
    return destructorValues[0 .. destructorCount];
}

pragma(cpp_use_deleting_destructor, true)
class DBase
{
    int i;
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
}
void deleteDBaseFromCPP(DBase inst);
CppBase createCppBaseFromCPP(int i);

pragma(cpp_use_deleting_destructor, true)
class CppBase
{
    int i;
    ~this();
}
void deleteCppBaseFromCPP(CppBase inst);

struct StructWithDtor
{
    int i;
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
}

class DDerived1 : CppBase
{
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
}

class DDerived2 : CppBase
{
}

class DDerived3 : CppBase
{
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
    StructWithDtor x1;
}

class DDerived2a : DDerived2
{
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
}

class DDerived3a : DDerived3
{
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
}

class DDerived4 : CppBase
{
    StructWithDtor x1;
}

class DDerived5 : CppBase
{
    StructWithDtor x1;
    StructWithDtor x2;
    StructWithDtor x3;
}

pragma(cpp_use_deleting_destructor, false)
class DDerived6 : CppBase
{
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
}

pragma(cpp_use_deleting_destructor, true) // The pragma ignored for structs
struct Struct1
{
    int i;
    ~this()
    {
        logDestructorCall(typeof(this).stringof.ptr, i);
    }
}
void deleteStruct1FromCPP(Struct1* inst);

void main()
{
    {
        auto inst = cpp_new!DBase;
        inst.i = 1;
        deleteDBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("DBase", 1)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        {
            scope inst = new DBase;
            inst.i = 2;
        }
        assert(newCount == 0);
        assert(deleteCount == 0);
        assert(loggedDestructorValues() == [DestructorCall("DBase", 2)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!CppBase;
        inst.i = 3;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("CppBase", 3)]);
    }
    {
        // Test the other direction of creating an object in C++ and deleting
        // it in D. This is not affected by the pragma.
        // This only works for classes without custom operator delete,
        // see https://github.com/dlang/dmd/issues/23509
        newCount = deleteCount = destructorCount = 0;
        auto inst = createCppBaseFromCPP(4);
        cpp_delete(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("CppBase", 4)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived1;
        inst.i = 100;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("DDerived1", 100), DestructorCall("CppBase", 100)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived2;
        inst.i = 200;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("CppBase", 200)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived3;
        inst.i = 300;
        inst.x1.i = 301;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("DDerived3", 300), DestructorCall("StructWithDtor", 301), DestructorCall("CppBase", 300)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived2a;
        inst.i = 210;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("DDerived2a", 210), DestructorCall("CppBase", 210)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived3a;
        inst.i = 310;
        inst.x1.i = 311;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("DDerived3a", 310), DestructorCall("DDerived3", 310), DestructorCall("StructWithDtor", 311), DestructorCall("CppBase", 310)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived4;
        inst.i = 400;
        inst.x1.i = 401;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("StructWithDtor", 401), DestructorCall("CppBase", 400)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived5;
        inst.i = 500;
        inst.x1.i = 501;
        inst.x2.i = 502;
        inst.x3.i = 503;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("StructWithDtor", 503), DestructorCall("StructWithDtor", 502), DestructorCall("StructWithDtor", 501), DestructorCall("CppBase", 500)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!DDerived6;
        inst.i = 600;
        deleteCppBaseFromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 0);
        assert(loggedDestructorValues() == [DestructorCall("DDerived6", 600), DestructorCall("CppBase", 600)]);
    }
    {
        newCount = deleteCount = destructorCount = 0;
        auto inst = cpp_new!Struct1;
        inst.i = 700;
        deleteStruct1FromCPP(inst);
        assert(newCount == 1);
        assert(deleteCount == 1);
        assert(loggedDestructorValues() == [DestructorCall("Struct1", 700)]);
    }
}
