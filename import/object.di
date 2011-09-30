/**
 * Contains all implicitly declared types and variables.
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 *
 *          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module object;

private
{
    extern(C) void rt_finalize(void *ptr, bool det=true);
}

alias typeof(int.sizeof)                    size_t;
alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;
alias ptrdiff_t                             sizediff_t;

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
    equals_t opEquals(Object lhs, Object rhs);

    interface Monitor
    {
        void lock();
        void unlock();
    }

    static Object factory(string classname);
}

bool opEquals(Object lhs, Object rhs);
//bool opEquals(TypeInfo lhs, TypeInfo rhs);

void setSameMutex(shared Object ownee, shared Object owner);

struct Interface
{
    TypeInfo_Class   classinfo;
    void*[]     vtbl;
    ptrdiff_t   offset;   // offset to Interface 'this' from Object 'this'
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
    @property size_t   tsize() nothrow pure;
    void     swap(void* p1, void* p2);
    @property TypeInfo next() nothrow pure;
    void[]   init() nothrow pure; // TODO: make this a property, but may need to be renamed to diambiguate with T.init...
    @property uint     flags() nothrow pure;
    // 1:    // has possible pointers into GC memory
    OffsetTypeInfo[] offTi();
    void destroy(void* p);
    void postblit(void* p);
    @property size_t talign() nothrow pure;
    version (X86_64) int argTypes(out TypeInfo arg1, out TypeInfo arg2);
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
    @property TypeInfo_Class info() nothrow pure { return this; }
    @property TypeInfo typeinfo() nothrow pure { return this; }

    byte[]      init;   // class static initializer
    string      name;   // class name
    void*[]     vtbl;   // virtual function pointer table
    Interface[] interfaces;
    TypeInfo_Class   base;
    void*       destructor;
    void function(Object) classInvariant;
    uint        m_flags;
    //  1:      // is IUnknown or is derived from IUnknown
    //  2:      // has no possible pointers into GC memory
    //  4:      // has offTi[] member
    //  8:      // has constructors
    // 16:      // has xgetMembers member
    // 32:      // has typeinfo member
    void*       deallocator;
    OffsetTypeInfo[] m_offTi;
    void*       defaultConstructor;
    const(MemberInfo[]) function(string) xgetMembers;

    static TypeInfo_Class find(in char[] classname);
    Object create();
    const(MemberInfo[]) getMembers(in char[] classname);
}

alias TypeInfo_Class ClassInfo;

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

    uint m_align;

    version (X86_64)
    {
        TypeInfo m_arg1;
        TypeInfo m_arg2;
    }
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

class TypeInfo_Inout : TypeInfo_Const
{
}

abstract class MemberInfo
{
    @property string name() nothrow pure;
}

class MemberInfo_field : MemberInfo
{
    this(string name, TypeInfo ti, size_t offset);

    @property override string name() nothrow pure;
    @property TypeInfo typeInfo() nothrow pure;
    @property size_t offset() nothrow pure;
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

    @property override string name() nothrow pure;
    @property TypeInfo typeInfo() nothrow pure;
    @property void* fp() nothrow pure;
    @property uint flags() nothrow pure;
}

struct ModuleInfo
{
    struct New
    {
        uint flags;
        uint index;
    }

    struct Old
    {
        string           name;
        ModuleInfo*[]    importedModules;
        TypeInfo_Class[] localClasses;
        uint             flags;

        void function() ctor;
        void function() dtor;
        void function() unitTest;
        void* xgetMembers;
        void function() ictor;
        void function() tlsctor;
        void function() tlsdtor;
        uint index;
        void*[1] reserved;
    }

    union
    {
        New n;
        Old o;
    }

    @property bool isNew() nothrow pure;
    @property uint index() nothrow pure;
    @property void index(uint i) nothrow pure;
    @property uint flags() nothrow pure;
    @property void flags(uint f) nothrow pure;
    @property void function() tlsctor() nothrow pure;
    @property void function() tlsdtor() nothrow pure;
    @property void* xgetMembers() nothrow pure;
    @property void function() ctor() nothrow pure;
    @property void function() dtor() nothrow pure;
    @property void function() ictor() nothrow pure;
    @property void function() unitTest() nothrow pure;
    @property ModuleInfo*[] importedModules() nothrow pure;
    @property TypeInfo_Class[] localClasses() nothrow pure;
    @property string name() nothrow pure;

    static int opApply(scope int delegate(ref ModuleInfo*) dg);
}

ModuleInfo*[] _moduleinfo_tlsdtors;
uint          _moduleinfo_tlsdtors_i;

extern (C) void _moduleTlsCtor();
extern (C) void _moduleTlsDtor();

class Throwable : Object
{
    interface TraceInfo
    {
        int opApply(scope int delegate(ref char[]));
        int opApply(scope int delegate(ref size_t, ref char[]));
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
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null);
    this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__);
}


class Error : Throwable
{
    this(string msg, Throwable next = null);
    this(string msg, string file, size_t line, Throwable next = null);
    Throwable   bypassedException;
}

extern (C)
{
    // from druntime/src/compiler/dmd/aaA.d

    size_t _aaLen(void* p);
    void*  _aaGet(void** pp, TypeInfo keyti, size_t valuesize, ...);
    void*  _aaGetRvalue(void* p, TypeInfo keyti, size_t valuesize, ...);
    void*  _aaIn(void* p, TypeInfo keyti);
    void   _aaDel(void* p, TypeInfo keyti, ...);
    void[] _aaValues(void* p, size_t keysize, size_t valuesize);
    void[] _aaKeys(void* p, size_t keysize);
    void*  _aaRehash(void** pp, TypeInfo keyti);

    extern (D) alias scope int delegate(void *) _dg_t;
    int _aaApply(void* aa, size_t keysize, _dg_t dg);

    extern (D) alias scope int delegate(void *, void *) _dg2_t;
    int _aaApply2(void* aa, size_t keysize, _dg2_t dg);

    void* _d_assocarrayliteralT(TypeInfo_AssociativeArray ti, size_t length, ...);
}

struct AssociativeArray(Key, Value)
{
    void* p;

    size_t length() @property { return _aaLen(p); }

    Value[Key] rehash() @property
    {
        auto p = _aaRehash(&p, typeid(Value[Key]));
        return *cast(Value[Key]*)(&p);
    }

    Value[] values() @property
    {
        auto a = _aaValues(p, Key.sizeof, Value.sizeof);
        return *cast(Value[]*) &a;
    }

    Key[] keys() @property
    {
        auto a = _aaKeys(p, Key.sizeof);
        return *cast(Key[]*) &a;
    }

    int opApply(scope int delegate(ref Key, ref Value) dg)
    {
        return _aaApply2(p, Key.sizeof, cast(_dg2_t)dg);
    }

    int opApply(scope int delegate(ref Value) dg)
    {
        return _aaApply(p, Key.sizeof, cast(_dg_t)dg);
    }

    int delegate(int delegate(ref Key) dg) byKey()
    {
        int foo(int delegate(ref Key) dg)
        {
            int byKeydg(ref Key key, ref Value value)
            {
               return dg(key);
            }

            return _aaApply2(p, Key.sizeof, cast(_dg2_t)&byKeydg);
        }

        return &foo;
    }

    int delegate(int delegate(ref Value) dg) byValue()
    {
        return &opApply;
    }

    Value get(Key key, lazy Value defaultValue)
    {
        auto r = key in *cast(Value[Key]*)(&p);
        return r ? *r : defaultValue;
    }

    static if (is(typeof({ Value[Key] r; r[Key.init] = Value.init; }())))
        @property Value[Key] dup()
        {
            Value[Key] result;
            foreach (k, v; this)
            {
                result[k] = v;
            }
            return result;
        }
}

unittest
{
    auto a = [ 1:"one", 2:"two", 3:"three" ];
    auto b = a.dup;
    assert(b == [ 1:"one", 2:"two", 3:"three" ]);
}

void clear(T)(T obj) if (is(T == class))
{
    rt_finalize(cast(void*)obj);
}

void clear(T)(ref T obj) if (is(T == struct))
{
    typeid(T).destroy(&obj);
    auto buf = (cast(ubyte*) &obj)[0 .. T.sizeof];
    auto init = cast(ubyte[])typeid(T).init;
    if(init.ptr is null) // null ptr means initialize to 0s
        buf[] = 0;
    else
        buf[] = init[];
}

void clear(T : U[n], U, size_t n)(ref T obj)
{
    obj = T.init;
}

void clear(T)(ref T obj)
if (!is(T == struct) && !is(T == class) && !_isStaticArray!T)
{
    obj = T.init;
}

template _isStaticArray(T : U[N], U, size_t N)
{
    enum bool _isStaticArray = true;
}

template _isStaticArray(T)
{
    enum bool _isStaticArray = false;
}

private
{
    extern (C) void _d_arrayshrinkfit(TypeInfo ti, void[] arr);
    extern (C) size_t _d_arraysetcapacity(TypeInfo ti, size_t newcapacity, void *arrptr);
}

@property size_t capacity(T)(T[] arr)
{
    return _d_arraysetcapacity(typeid(T[]), 0, cast(void *)&arr);
}

size_t reserve(T)(ref T[] arr, size_t newcapacity)
{
    return _d_arraysetcapacity(typeid(T[]), newcapacity, cast(void *)&arr);
}

void assumeSafeAppend(T)(T[] arr)
{
    _d_arrayshrinkfit(typeid(T[]), *(cast(void[]*)&arr));
}

bool _ArrayEq(T1, T2)(T1[] a1, T2[] a2)
{
    if (a1.length != a2.length)
        return false;
    foreach(i, a; a1)
    {   if (a != a2[i])
            return false;
    }
    return true;
}

bool _xopEquals(in void* ptr, in void* ptr);

void __ctfeWriteln(T...)(auto ref T) {}

