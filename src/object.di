/**
 * Contains all implicitly declared types and variables.
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
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
    override string toString() const pure @safe nothrow;
    override size_t toHash() @trusted const;
    override int opCmp(Object o);
    override bool opEquals(Object o);
    size_t   getHash(in void* p) @trusted nothrow const;
    bool     equals(in void* p1, in void* p2) const;
    int      compare(in void* p1, in void* p2) const;
    @property size_t   tsize() nothrow pure const @safe @nogc;
    void     swap(void* p1, void* p2) const;
    @property inout(TypeInfo) next() nothrow pure inout @nogc;
    const(void)[]   init() nothrow pure const @safe @nogc; // TODO: make this a property, but may need to be renamed to diambiguate with T.init...
    @property uint     flags() nothrow pure const @safe @nogc;
    // 1:    // has possible pointers into GC memory
    const(OffsetTypeInfo)[] offTi() const;
    void destroy(void* p) const;
    void postblit(void* p) const;
    @property size_t talign() nothrow pure const @safe @nogc;
    version (X86_64) int argTypes(out TypeInfo arg1, out TypeInfo arg2) @safe nothrow;
    @property immutable(void)* rtInfo() nothrow pure const @safe @nogc;
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
    enum ClassFlags : uint
    {
        isCOMclass = 0x1,
        noPointers = 0x2,
        hasOffTi = 0x4,
        hasCtor = 0x8,
        hasGetMembers = 0x10,
        hasTypeInfo = 0x20,
        isAbstract = 0x40,
        isCPPclass = 0x80,
        hasDtor = 0x100,
    }
    ClassFlags m_flags;
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

    enum StructFlags : uint
    {
        hasPointers = 0x1,
    }
    StructFlags m_flags;
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

    version (all)
    {
        deprecated("ModuleInfo cannot be copy-assigned because it is a variable-sized struct.")
        void opAssign(in ModuleInfo m) { _flags = m._flags; _index = m._index; }
    }
    else
    {
        @disable this();
        @disable this(this) const;
    }

const:
    @property uint index() nothrow pure;
    @property uint flags() nothrow pure;
    @property void function() tlsctor() nothrow pure;
    @property void function() tlsdtor() nothrow pure;
    @property void* xgetMembers() nothrow pure;
    @property void function() ctor() nothrow pure;
    @property void function() dtor() nothrow pure;
    @property void function() ictor() nothrow pure;
    @property void function() unitTest() nothrow pure;
    @property immutable(ModuleInfo*)[] importedModules() nothrow pure;
    @property TypeInfo_Class[] localClasses() nothrow pure;
    @property string name() nothrow pure;

    static int opApply(scope int delegate(ModuleInfo*) dg);
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
    void toString(scope void delegate(in char[]) sink) const;
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
    // from druntime/src/rt/aaA.d

    // size_t _aaLen(in void* p) pure nothrow @nogc;
    private void* _aaGetX(void** paa, const TypeInfo keyti, in size_t valuesize, in void* pkey) pure nothrow;
    // inout(void)* _aaGetRvalueX(inout void* p, in TypeInfo keyti, in size_t valuesize, in void* pkey);
    inout(void)[] _aaValues(inout void* p, in size_t keysize, in size_t valuesize) pure nothrow;
    inout(void)[] _aaKeys(inout void* p, in size_t keysize) pure nothrow;
    void* _aaRehash(void** pp, in TypeInfo keyti) pure nothrow;

    // alias _dg_t = extern(D) int delegate(void*);
    // int _aaApply(void* aa, size_t keysize, _dg_t dg);

    // alias _dg2_t = extern(D) int delegate(void*, void*);
    // int _aaApply2(void* aa, size_t keysize, _dg2_t dg);

    private struct AARange { void* impl, current; }
    AARange _aaRange(void* aa) pure nothrow @nogc;
    bool _aaRangeEmpty(AARange r) pure nothrow @nogc;
    void* _aaRangeFrontKey(AARange r) pure nothrow @nogc;
    void* _aaRangeFrontValue(AARange r) pure nothrow @nogc;
    void _aaRangePopFront(ref AARange r) pure nothrow @nogc;

    /*
        _d_assocarrayliteralTX marked as pure, because aaLiteral can be called from pure code.
        This is a typesystem hole, however this is existing hole.
        Early compiler didn't check purity of toHash or postblit functions, if key is a UDT thus
        copiler allowed to create AA literal with keys, which have impure unsafe toHash methods.
    */
    void* _d_assocarrayliteralTX(const TypeInfo_AssociativeArray ti, void[] keys, void[] values) pure;
}

auto aaLiteral(Key, Value, T...)(auto ref T args) if (T.length % 2 == 0)
{
    static if(!T.length) 
    {
        return cast(void*)null;
    }
    else
    {
        import core.internal.traits;
        Key[] keys;
        Value[] values;
        keys.reserve(T.length / 2);
        values.reserve(T.length / 2);

        foreach (i; staticIota!(0, args.length / 2))
        {
            keys ~= args[2*i];
            values ~= args[2*i + 1];
        }

        void[] key_slice;
        void[] value_slice;
        void *ret;
        () @trusted {
            key_slice = *cast(void[]*)&keys;
            value_slice = *cast(void[]*)&values;
            ret = _d_assocarrayliteralTX(typeid(Value[Key]), key_slice, value_slice);
        }();
        return ret;
    }
}

alias AssociativeArray(Key, Value) = Value[Key];

T rehash(T : Value[Key], Value, Key)(T aa)
{
    _aaRehash(cast(void**)&aa, typeid(Value[Key]));
    return aa;
}

T rehash(T : Value[Key], Value, Key)(T* aa)
{
    _aaRehash(cast(void**)aa, typeid(Value[Key]));
    return *aa;
}

T rehash(T : shared Value[Key], Value, Key)(T aa)
{
    _aaRehash(cast(void**)&aa, typeid(Value[Key]));
    return aa;
}

T rehash(T : shared Value[Key], Value, Key)(T* aa)
{
    _aaRehash(cast(void**)aa, typeid(Value[Key]));
    return *aa;
}

V[K] dup(T : V[K], K, V)(T aa)
{
    // Bug10720 - check whether V is copyable
    static assert(is(typeof({ V v = aa[K.init]; })),
        "cannot call " ~ T.stringof ~ ".dup because " ~ V.stringof ~ " is not copyable");

    V[K] result;

    //foreach (k, ref v; aa)
    //    result[k] = v;  // Bug13701 - won't work if V is not mutable

    ref V duplicateElem(ref K k, ref const V v) @trusted pure nothrow
    {
        import core.stdc.string : memcpy;

        void* pv = _aaGetX(cast(void**)&result, typeid(K), V.sizeof, &k);
        memcpy(pv, &v, V.sizeof);
        return *cast(V*)pv;
    }

    if (auto postblit = _getPostblit!V())
    {
        foreach (k, ref v; aa)
            postblit(duplicateElem(k, v));
    }
    else
    {
        foreach (k, ref v; aa)
            duplicateElem(k, v);
    }

    return result;
}

V[K] dup(T : V[K], K, V)(T* aa)
{
    return (*aa).dup;
}

auto byKey(T : Value[Key], Value, Key)(T aa) pure nothrow @nogc
{
    static struct Result
    {
        AARange r;

    pure nothrow @nogc:
        @property bool empty() { return _aaRangeEmpty(r); }
        @property ref Key front() { return *cast(Key*)_aaRangeFrontKey(r); }
        void popFront() { _aaRangePopFront(r); }
        @property Result save() { return this; }
    }

    return Result(_aaRange(cast(void*)aa));
}

auto byKey(T : Value[Key], Value, Key)(T *aa) pure nothrow @nogc
{
    return (*aa).byKey();
}

auto byValue(T : Value[Key], Value, Key)(T aa) pure nothrow @nogc
{
    static struct Result
    {
        AARange r;

    pure nothrow @nogc:
        @property bool empty() { return _aaRangeEmpty(r); }
        @property ref Value front() { return *cast(Value*)_aaRangeFrontValue(r); }
        void popFront() { _aaRangePopFront(r); }
        @property Result save() { return this; }
    }

    return Result(_aaRange(cast(void*)aa));
}

auto byValue(T : Value[Key], Value, Key)(T *aa) pure nothrow @nogc
{
    return (*aa).byValue();
}

Key[] keys(T : Value[Key], Value, Key)(T aa) @property
{
    auto a = cast(void[])_aaKeys(cast(inout(void)*)aa, Key.sizeof);
    return *cast(Key[]*)&a;
}

Key[] keys(T : Value[Key], Value, Key)(T *aa) @property
{
    return (*aa).keys;
}

Value[] values(T : Value[Key], Value, Key)(T aa) @property
{
    auto a = cast(void[])_aaValues(cast(inout(void)*)aa, Key.sizeof, Value.sizeof);
    return *cast(Value[]*)&a;
}

Value[] values(T : Value[Key], Value, Key)(T *aa) @property
{
    return (*aa).values;
}

inout(V) get(K, V)(inout(V[K]) aa, K key, lazy inout(V) defaultValue)
{
    auto p = key in aa;
    return p ? *p : defaultValue;
}

inout(V) get(K, V)(inout(V[K])* aa, K key, lazy inout(V) defaultValue)
{
    return (*aa).get(key, defaultValue);
}

// Explicitly undocumented. It will be removed in March 2015.
deprecated("Please use destroy instead.")
alias clear = destroy;

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

void destroy(T : U[n], U, size_t n)(ref T obj) if (!is(T == struct))
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
    extern (C) void _d_arrayshrinkfit(TypeInfo ti, void[] arr) nothrow;
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

auto ref inout(T[]) assumeSafeAppend(T)(auto ref inout(T[]) arr) nothrow
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

/**
Calculates the hash value of $(D arg) with $(D seed) initial value.
Result may be non-equals with $(D typeid(T).getHash(&arg))
The $(D seed) value may be used for hash chaining:
----
struct Test
{
    int a;
    string b;
    MyObject c;

    size_t toHash() const @safe pure nothrow
    {
        size_t hash = a.hashOf();
        hash = b.hashOf(hash);
        size_t h1 = c.myMegaHash();
        hash = h1.hashOf(hash); //Mix two hash values
        return hash;
    }
}
----
*/
size_t hashOf(T)(auto ref T arg, size_t seed = 0)
{
    import core.internal.hash;
    return core.internal.hash.hashOf(arg, seed);
}

bool _xopEquals(in void* ptr, in void* ptr);
bool _xopCmp(in void* ptr, in void* ptr);

void __ctfeWrite(T...)(auto ref T) {}
void __ctfeWriteln(T...)(auto ref T values) { __ctfeWrite(values, "\n"); }

template RTInfo(T)
{
    enum RTInfo = cast(void*)0x12345678;
}

/// Provide the .dup array property.
@property auto dup(T)(T[] a)
    if (!is(const(T) : T))
{
    import core.internal.traits : Unconst;
    static assert(is(T : Unconst!T), "Cannot implicitly convert type "~T.stringof~
                  " to "~Unconst!T.stringof~" in dup.");

    // wrap unsafe _dup in @trusted to preserve @safe postblit
    static if (__traits(compiles, (T b) @safe { T a = b; }))
        return _trustedDup!(T, Unconst!T)(a);
    else
        return _dup!(T, Unconst!T)(a);
}

/// ditto
// const overload to support implicit conversion to immutable (unique result, see DIP29)
@property T[] dup(T)(const(T)[] a)
    if (is(const(T) : T))
{
    // wrap unsafe _dup in @trusted to preserve @safe postblit
    static if (__traits(compiles, (T b) @safe { T a = b; }))
        return _trustedDup!(const(T), T)(a);
    else
        return _dup!(const(T), T)(a);
}

/// ditto
@property T[] dup(T:void)(const(T)[] a) @trusted
{
    if (__ctfe) assert(0, "Cannot dup a void[] array at compile time.");
    return cast(T[])_rawDup(a);
}

/// Provide the .idup array property.
@property immutable(T)[] idup(T)(T[] a)
{
    static assert(is(T : immutable(T)), "Cannot implicitly convert type "~T.stringof~
                  " to immutable in idup.");

    // wrap unsafe _dup in @trusted to preserve @safe postblit
    static if (__traits(compiles, (T b) @safe { T a = b; }))
        return _trustedDup!(T, immutable(T))(a);
    else
        return _dup!(T, immutable(T))(a);
}

/// ditto
@property immutable(T)[] idup(T:void)(const(T)[] a)
{
    return .dup(a);
}

private U[] _trustedDup(T, U)(T[] a) @trusted
{
    return _dup!(T, U)(a);
}

private U[] _dup(T, U)(T[] a) // pure nothrow depends on postblit
{
    if (__ctfe)
    {
        U[] res;
        foreach (ref e; a)
            res ~= e;
        return res;
    }

    a = _rawDup(a);
    auto res = *cast(typeof(return)*)&a;
    _doPostblit(res);
    return res;
}

private extern (C) void[] _d_newarrayU(const TypeInfo ti, size_t length) pure nothrow;

private inout(T)[] _rawDup(T)(inout(T)[] a)
{
    import core.stdc.string : memcpy;

    void[] arr = _d_newarrayU(typeid(T[]), a.length);
    memcpy(arr.ptr, cast(void*)a.ptr, T.sizeof * a.length);
    return *cast(inout(T)[]*)&arr;
}

// Returns null, or a delegate to call postblit of T
private auto _getPostblit(T)() @trusted pure nothrow @nogc
{
    // infer static postblit type, run postblit if any
    static if (is(T == struct))
    {
        import core.internal.traits : Unqual;

        // assume that ref T and void* are equivalent in abi level.
        alias PostBlitT = typeof(function (ref T t){ T a = t; });

        // use typeid(Unqual!T) here to skip TypeInfo_Const/Shared/...
        return cast(PostBlitT)typeid(Unqual!T).xpostblit;
    }
    else if ((&typeid(T).postblit).funcptr !is &TypeInfo.postblit)
    {
        // assume that ref T and void* are equivalent in abi level.
        alias PostBlitT = typeof(delegate (ref T t){ T a = t; });

        return cast(PostBlitT)&typeid(T).postblit;
    }
    else
        return null;
}

private void _doPostblit(T)(T[] arr)
{
    // infer static postblit type, run postblit if any
    if (auto postblit = _getPostblit!T())
    {
        foreach (ref elem; arr)
            postblit(elem);
    }
}
