/**
 * Contains all implicitly declared types and variables.
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 *
 *          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module object;

private
{
    extern(C) void rt_finalize(void *ptr, bool det=true);
}

alias typeof(int.sizeof)                    size_t;
alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;

alias ptrdiff_t sizediff_t; //For backwards compatibility only.

alias size_t hash_t; //For backwards compatibility only.
alias bool equals_t; //For backwards compatibility only.

alias immutable(char)[]  string;
alias immutable(wchar)[] wstring;
alias immutable(dchar)[] dstring;

class Object
{
    string   toString();
    size_t   toHash() @trusted nothrow;
    int      opCmp(Object o);
    bool     opEquals(Object o);

    interface Monitor
    {
        void lock();
        void unlock();
    }

    static Object factory(string classname);
}

bool opEquals(const Object lhs, const Object rhs);
bool opEquals(Object lhs, Object rhs);

void setSameMutex(shared Object ownee, shared Object owner);

struct Interface
{
    TypeInfo_Class   classinfo;
    void*[]     vtbl;
    size_t      offset;   // offset to Interface 'this' from Object 'this'
}

struct OffsetTypeInfo
{
    size_t   offset;
    TypeInfo ti;
}

class TypeInfo
{
    override string toString() const;
    override size_t toHash() @trusted const;
    override int opCmp(Object o);
    override bool opEquals(Object o);
    size_t   getHash(in void* p) @trusted nothrow const;
    bool     equals(in void* p1, in void* p2) const;
    int      compare(in void* p1, in void* p2) const;
    @property size_t   tsize() nothrow pure const @safe;
    void     swap(void* p1, void* p2) const;
    @property inout(TypeInfo) next() nothrow pure inout;
    const(void)[]   init() nothrow pure const @safe; // TODO: make this a property, but may need to be renamed to diambiguate with T.init...
    @property uint     flags() nothrow pure const @safe;
    // 1:    // has possible pointers into GC memory
    const(OffsetTypeInfo)[] offTi() const;
    void destroy(void* p) const;
    void postblit(void* p) const;
    @property size_t talign() nothrow pure const @safe;
    version (X86_64) int argTypes(out TypeInfo arg1, out TypeInfo arg2) @safe nothrow;
    @property immutable(void)* rtInfo() nothrow pure const @safe;
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
    override string toString() const;
    override bool opEquals(Object o);
    override size_t getHash(in void* p) @trusted const;
    override bool equals(in void* p1, in void* p2) const;
    override int compare(in void* p1, in void* p2) const;
    override @property size_t tsize() nothrow pure const;
    override void swap(void* p1, void* p2) const;
    override @property inout(TypeInfo) next() nothrow pure inout;
    override @property uint flags() nothrow pure const;
    override @property size_t talign() nothrow pure const;
    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2);

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

class TypeInfo_Vector : TypeInfo
{
    TypeInfo base;
}

class TypeInfo_Function : TypeInfo
{
    TypeInfo next;
    string deco;
}

class TypeInfo_Delegate : TypeInfo
{
    TypeInfo next;
    string deco;
}

class TypeInfo_Class : TypeInfo
{
    @property auto info() @safe nothrow pure const { return this; }
    @property auto typeinfo() @safe nothrow pure const { return this; }

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
    immutable(void)*    m_rtInfo;     // data for precise GC

    static const(TypeInfo_Class) find(in char[] classname);
    Object create() const;
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

  @safe pure nothrow
  {
    uint function(in void*)               xtoHash;
    bool function(in void*, in void*) xopEquals;
    int function(in void*, in void*)      xopCmp;
    string function(in void*)             xtoString;

    uint m_flags;
  }
    void function(void*)                    xdtor;
    void function(void*)                    xpostblit;

    uint m_align;

    version (X86_64)
    {
        TypeInfo m_arg1;
        TypeInfo m_arg2;
    }
    immutable(void)* m_rtInfo;
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

    override @property string name() nothrow pure;
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

    override @property string name() nothrow pure;
    @property TypeInfo typeInfo() nothrow pure;
    @property void* fp() nothrow pure;
    @property uint flags() nothrow pure;
}

struct ModuleInfo
{
    uint _flags;
    uint _index;

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

class Throwable : Object
{
    interface TraceInfo
    {
        int opApply(scope int delegate(ref const(char[]))) const;
        int opApply(scope int delegate(ref size_t, ref const(char[]))) const;
        string toString() const;
    }

    string      msg;
    string      file;
    size_t      line;
    TraceInfo   info;
    Throwable   next;

    @safe pure nothrow this(string msg, Throwable next = null);
    @safe pure nothrow this(string msg, string file, size_t line, Throwable next = null);
    override string toString();
}


class Exception : Throwable
{
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}


class Error : Throwable
{
    @safe pure nothrow this(string msg, Throwable next = null)
    {
        super(msg, next);
        bypassedException = null;
    }

    @safe pure nothrow this(string msg, string file, size_t line, Throwable next = null)
    {
        super(msg, file, line, next);
        bypassedException = null;
    }
    Throwable   bypassedException;
}

extern (C)
{
    // from druntime/src/compiler/dmd/aaA.d

    size_t _aaLen(in void* p) pure nothrow;
    void* _aaGet(void** pp, const TypeInfo keyti, in size_t valuesize, ...);
    inout(void)* _aaGetRvalue(inout void* p, in TypeInfo keyti, in size_t valuesize, ...);
    inout(void)* _aaIn(inout void* p, in TypeInfo keyti);
    void _aaDel(void* p, in TypeInfo keyti, ...);
    inout(void)[] _aaValues(inout void* p, in size_t keysize, in size_t valuesize) pure nothrow;
    inout(void)[] _aaKeys(inout void* p, in size_t keysize) pure nothrow;
    void* _aaRehash(void** pp, in TypeInfo keyti) pure nothrow;

    extern (D) alias scope int delegate(void *) _dg_t;
    int _aaApply(void* aa, size_t keysize, _dg_t dg);

    extern (D) alias scope int delegate(void *, void *) _dg2_t;
    int _aaApply2(void* aa, size_t keysize, _dg2_t dg);

    private struct AARange { void* impl, current; }
    AARange _aaRange(void* aa);
    bool _aaRangeEmpty(AARange r);
    void* _aaRangeFrontKey(AARange r);
    void* _aaRangeFrontValue(AARange r);
    void _aaRangePopFront(ref AARange r);

    void* _d_assocarrayliteralT(TypeInfo_AssociativeArray ti, in size_t length, ...);
}

private template _Unqual(T)
{
         static if (is(T U == shared(const U))) alias U _Unqual;
    else static if (is(T U ==        const U )) alias U _Unqual;
    else static if (is(T U ==    immutable U )) alias U _Unqual;
    else static if (is(T U ==        inout U )) alias U _Unqual;
    else static if (is(T U ==       shared U )) alias U _Unqual;
    else                                        alias T _Unqual;
}

struct AssociativeArray(Key, Value)
{
private:
    void* p;

public:
    @property size_t length() const { return _aaLen(p); }

    Value[Key] rehash() @property
    {
        auto p = _aaRehash(cast(void**) &p, typeid(Value[Key]));
        return *cast(Value[Key]*)(&p);
    }

    // Note: can't make `values` and `keys` inout as it is used
    // e.g. in Phobos like `ReturnType!(aa.keys)` instead of `typeof(aa.keys)`
    // which will result in `inout` propagation.

    inout(Value)[] inout_values() inout @property
    {
        auto a = _aaValues(p, Key.sizeof, Value.sizeof);
        return *cast(inout Value[]*) &a;
    }

    inout(Key)[] inout_keys() inout @property
    {
        auto a = _aaKeys(p, Key.sizeof);
        return *cast(inout Key[]*) &a;
    }

    Value[] values() @property
    { return inout_values; }

    Key[] keys() @property
    { return inout_keys; }

    const(Value)[] values() const @property
    { return inout_values; }

    const(Key)[] keys() const @property
    { return inout_keys; }

    int opApply(scope int delegate(ref Key, ref Value) dg)
    {
        return _aaApply2(p, Key.sizeof, cast(_dg2_t)dg);
    }

    int opApply(scope int delegate(ref Value) dg)
    {
        return _aaApply(p, Key.sizeof, cast(_dg_t)dg);
    }

    Value get(Key key, lazy Value defaultValue)
    {
        auto p = key in *cast(Value[Key]*)(&p);
        return p ? *p : defaultValue;
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

    @property auto byKey()
    {
        static struct Result
        {
            AARange r;

            @property bool empty() { return _aaRangeEmpty(r); }
            @property ref Key front() { return *cast(Key*)_aaRangeFrontKey(r); }
            void popFront() { _aaRangePopFront(r); }
        }

        return Result(_aaRange(p));
    }

    @property auto byValue()
    {
        static struct Result
        {
            AARange r;

            @property bool empty() { return _aaRangeEmpty(r); }
            @property ref Value front() { return *cast(Value*)_aaRangeFrontValue(r); }
            void popFront() { _aaRangePopFront(r); }
        }

        return Result(_aaRange(p));
    }
}

// Scheduled for deprecation in December 2012.
// Please use destroy instead of clear.
alias destroy clear;

void destroy(T)(T obj) if (is(T == class))
{
    rt_finalize(cast(void*)obj);
}

void destroy(T)(T obj) if (is(T == interface))
{
    destroy(cast(Object)obj);
}

void destroy(T)(ref T obj) if (is(T == struct))
{
    typeid(T).destroy(&obj);
    auto buf = (cast(ubyte*) &obj)[0 .. T.sizeof];
    auto init = cast(ubyte[])typeid(T).init();
    if(init.ptr is null) // null ptr means initialize to 0s
        buf[] = 0;
    else
        buf[] = init[];
}

void destroy(T : U[n], U, size_t n)(ref T obj)
{
    obj[] = U.init;
}

void destroy(T)(ref T obj)
if (!is(T == struct) && !is(T == interface) && !is(T == class) && !_isStaticArray!T)
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
    extern (C) size_t _d_arraysetcapacity(TypeInfo ti, size_t newcapacity, void *arrptr) pure nothrow;
}

@property size_t capacity(T)(T[] arr) pure nothrow
{
    return _d_arraysetcapacity(typeid(T[]), 0, cast(void *)&arr);
}

size_t reserve(T)(ref T[] arr, size_t newcapacity) pure nothrow @trusted
{
    return _d_arraysetcapacity(typeid(T[]), newcapacity, cast(void *)&arr);
}

auto ref inout(T[]) assumeSafeAppend(T)(auto ref inout(T[]) arr)
{
    _d_arrayshrinkfit(typeid(T[]), *(cast(void[]*)&arr));
    return arr;
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
bool _xopCmp(in void* ptr, in void* ptr);

void __ctfeWrite(T...)(auto ref T) {}
void __ctfeWriteln(T...)(auto ref T values) { __ctfeWrite(values, "\n"); }

template RTInfo(T)
{
    enum RTInfo = cast(void*)0x12345678;
}

version (unittest)
{
    string __unittest_toString(T)(ref T value) pure nothrow @trusted
    {
        static if (is(T == string))
            return `"` ~ value ~ `"`;   // TODO: Escape internal double-quotes.
        else
        {
            version (druntime_unittest)
            {
                return T.stringof;
            }
            else
            {
                enum phobos_impl = q{
                    import std.traits;
                    alias Unqual!T U;
                    static if (isFloatingPoint!U)
                    {
                        import std.string;
                        enum format_string = is(U == float) ? "%.7g" :
                                             is(U == double) ? "%.16g" : "%.20g";
                        return (cast(string function(...) pure nothrow @safe)&format)(format_string, value);
                    }
                    else
                    {
                        import std.conv;
                        alias to!string toString;
                        alias toString!T f;
                        return (cast(string function(T) pure nothrow @safe)&f)(value);
                    }
                };
                enum tango_impl = q{
                    import tango.util.Convert;
                    alias to!(string, T) f;
                    return (cast(string function(T) pure nothrow @safe)&f)(value);
                };

                static if (__traits(compiles, { mixin(phobos_impl); }))
                    mixin(phobos_impl);
                else static if (__traits(compiles, { mixin(tango_impl); }))
                    mixin(tango_impl);
                else
                    return T.stringof;
            }
        }
    }
}

