/**
 * Contains all implicitly declared types and variables.
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module object;

alias typeof(int.sizeof)                    size_t;
alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;

alias size_t hash_t;
alias bool equals_t;

alias immutable(char)[]  string;
alias immutable(wchar)[] wstring;
alias immutable(dchar)[] dstring;

class Object
{
    string   toString();
    hash_t   toHash();
    int      opCmp(Object o);
    equals_t opEquals(Object o);

    interface Monitor
    {
        void lock();
        void unlock();
    }

    static Object factory(string classname);
}

struct Interface
{
    ClassInfo   classinfo;
    void*[]     vtbl;
    ptrdiff_t   offset;   // offset to Interface 'this' from Object 'this'
}

class ClassInfo : Object
{
    byte[]      init;   // class static initializer
    string      name;   // class name
    void*[]     vtbl;   // virtual function pointer table
    Interface[] interfaces;
    ClassInfo   base;
    void*       destructor;
    void(*classInvariant)(Object);
    uint        flags;
    //  1:      // is IUnknown or is derived from IUnknown
    //  2:      // has no possible pointers into GC memory
    //  4:      // has offTi[] member
    //  8:      // has constructors
    // 16:      // has xgetMembers member
    // 32:      // has typeinfo member
    void*       deallocator;
    OffsetTypeInfo[] offTi;
    void*       defaultConstructor;
    const(MemberInfo[]) function(string) xgetMembers;
    TypeInfo    typeinfo;

    static ClassInfo find(in char[] classname);
    Object create();
    const(MemberInfo[]) getMembers(in char[] classname);
}

struct OffsetTypeInfo
{
    size_t   offset;
    TypeInfo ti;
}

class TypeInfo
{
    hash_t   getHash(in void* p);
    equals_t equals(in void* p1, in void* p2);
    int      compare(in void* p1, in void* p2);
    size_t   tsize();
    void     swap(void* p1, void* p2);
    TypeInfo next();
    void[]   init();
    uint     flags();
    // 1:    // has possible pointers into GC memory
    OffsetTypeInfo[] offTi();
    void destroy(void* p);
    void postblit(void* p);
}

class TypeInfo_Typedef : TypeInfo
{
    TypeInfo base;
    string   name;
    void[]   m_init;
}

class TypeInfo_Enum : TypeInfo_Typedef
{

}

class TypeInfo_Pointer : TypeInfo
{
    TypeInfo m_next;
}

class TypeInfo_Array : TypeInfo
{
    TypeInfo value;
}

class TypeInfo_StaticArray : TypeInfo
{
    TypeInfo value;
    size_t   len;
}

class TypeInfo_AssociativeArray : TypeInfo
{
    TypeInfo value;
    TypeInfo key;
    TypeInfo impl;
}

class TypeInfo_Function : TypeInfo
{
    TypeInfo next;
}

class TypeInfo_Delegate : TypeInfo
{
    TypeInfo next;
}

class TypeInfo_Class : TypeInfo
{
    ClassInfo info;
}

class TypeInfo_Interface : TypeInfo
{
    ClassInfo info;
}

class TypeInfo_Struct : TypeInfo
{
    string name;
    void[] m_init;

    uint function(in void*)               xtoHash;
    equals_t function(in void*, in void*) xopEquals;
    int function(in void*, in void*)      xopCmp;
    string function(in void*)             xtoString;

    uint m_flags;

    const(MemberInfo[]) function(in char[]) xgetMembers;
    void function(void*)                    xdtor;
    void function(void*)                    xpostblit;
}

class TypeInfo_Tuple : TypeInfo
{
    TypeInfo[]  elements;
}

class TypeInfo_Const : TypeInfo
{
    TypeInfo next;
}

class TypeInfo_Invariant : TypeInfo_Const
{

}

class TypeInfo_Shared : TypeInfo_Const
{

}

abstract class MemberInfo
{
    string name();
}

class MemberInfo_field : MemberInfo
{
    this(string name, TypeInfo ti, size_t offset);

    override string name();
    TypeInfo typeInfo();
    size_t offset();
}

class MemberInfo_function : MemberInfo
{
    enum
    {
        Virtual = 1,
        Member  = 2,
        Static  = 4,
    }

    this(string name, TypeInfo ti, void* fp, uint flags);

    override string name();
    TypeInfo typeInfo();
    void* fp();
    uint flags();
}

class ModuleInfo
{
    string          name;
    ModuleInfo[]    importedModules;
    ClassInfo[]     localClasses;
    uint            flags;

    void function() ctor;
    void function() dtor;
    void function() unitTest;

    void*           xgetMembers;
    void function() ictor;
    void*[4] reserved;

    static int opApply(int delegate(inout ModuleInfo));
}

class Throwable : Object
{
    interface TraceInfo
    {
        int opApply(int delegate(inout char[]));
        string toString();
    }

    string      msg;
    string      file;
    size_t      line;
    TraceInfo   info;
    Throwable   next;

    this(string msg, Throwable next = null);
    this(string msg, string file, size_t line, Throwable next = null);
    override string toString();
}


class Exception : Throwable
{
    this(string msg, Throwable next = null);
    this(string msg, string file, size_t line, Throwable next = null);
}


class Error : Throwable
{
    this(string msg, Throwable next = null);
    this(string msg, string file, size_t line, Throwable next = null);
}

extern (C)
{
    // from druntime/src/compiler/dmd/aaA.d

    size_t _aaLen(void* p);
    void* _aaGet(void** pp, TypeInfo keyti, size_t valuesize, ...);
    void* _aaGetRvalue(void* p, TypeInfo keyti, size_t valuesize, ...);
    void* _aaIn(void* p, TypeInfo keyti);
    void _aaDel(void* p, TypeInfo keyti, ...);
    void[] _aaValues(void* p, size_t keysize, size_t valuesize);
    void[] _aaKeys(void* p, size_t keysize, size_t valuesize);
    void* _aaRehash(void** pp, TypeInfo keyti);

    extern (D) typedef int delegate(void *) _dg_t;
    int _aaApply(void* aa, size_t keysize, _dg_t dg);

    extern (D) typedef int delegate(void *, void *) _dg2_t;
    int _aaApply2(void* aa, size_t keysize, _dg2_t dg);

    void* _d_assocarrayliteralT(TypeInfo_AssociativeArray ti, size_t length, ...);
}

struct AssociativeArray(Key, Value)
{
    void* p;

    size_t length() { return _aaLen(p); }

    Value[Key] rehash()
    {
	return cast(Value[Key]) _aaRehash(&p, typeid(Value[Key]));
    }

    Value[] values()
    {
	auto a = _aaValues(p, Key.sizeof, Value.sizeof);
	return *cast(Value[]*) &a;
    }

    Key[] keys()
    {
	auto a = _aaKeys(p, Key.sizeof, Value.sizeof);
	return *cast(Key[]*) &a;
    }

/+ Won't work yet because cannot pass static arrays to inout
    int opApply(int delegate(inout Value) dg)
    {
	return _aaApply(p, Key.sizeof, cast(_dg_t)dg);
    }

    int opApply(int delegate(inout Key, inout Value) dg)
    {
	return _aaApply2(p, Key.sizeof, cast(_dg2_t)dg);
    }
+/
}


