/**
 * Forms the symbols available to all D programs. Includes Object, which is
 * the root of the class object hierarchy.  This module is implicitly
 * imported.
 * Macros:
 *      WIKI = Object
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module object;

//debug=PRINTF;

private
{
    import core.atomic;
    import core.stdc.string;
    import core.stdc.stdlib;
    import core.memory;
    import rt.util.hash;
    import rt.util.string;
    import rt.util.console;
    import rt.minfo;
    debug(PRINTF) import core.stdc.stdio;

    extern (C) void onOutOfMemoryError();
    extern (C) Object _d_newclass(const TypeInfo_Class ci);
    extern (C) void _d_arrayshrinkfit(const TypeInfo ti, void[] arr);
    extern (C) size_t _d_arraysetcapacity(const TypeInfo ti, size_t newcapacity, void *arrptr) pure nothrow;
    extern (C) void rt_finalize(void *data, bool det=true);
}

version (druntime_unittest)
{
    string __unittest_toString(T)(T) { return T.stringof; }
}

// NOTE: For some reason, this declaration method doesn't work
//       in this particular file (and this file only).  It must
//       be a DMD thing.
//alias typeof(int.sizeof)                    size_t;
//alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;

version(D_LP64)
{
    alias ulong size_t;
    alias long  ptrdiff_t;
}
else
{
    alias uint  size_t;
    alias int   ptrdiff_t;
}

alias ptrdiff_t sizediff_t; //For backwards compatibility only.

alias size_t hash_t; //For backwards compatibility only.
alias bool equals_t; //For backwards compatibility only.

alias immutable(char)[]  string;
alias immutable(wchar)[] wstring;
alias immutable(dchar)[] dstring;

/**
 * All D class objects inherit from Object.
 */
class Object
{
    /**
     * Convert Object to a human readable string.
     */
    string toString()
    {
        return this.classinfo.name;
    }

    /**
     * Compute hash function for Object.
     */
    size_t toHash() @trusted nothrow
    {
        // BUG: this prevents a compacting GC from working, needs to be fixed
        return cast(size_t)cast(void*)this;
    }

    /**
     * Compare with another Object obj.
     * Returns:
     *  $(TABLE
     *  $(TR $(TD this &lt; obj) $(TD &lt; 0))
     *  $(TR $(TD this == obj) $(TD 0))
     *  $(TR $(TD this &gt; obj) $(TD &gt; 0))
     *  )
     */
    int opCmp(Object o)
    {
        // BUG: this prevents a compacting GC from working, needs to be fixed
        //return cast(int)cast(void*)this - cast(int)cast(void*)o;

        throw new Exception("need opCmp for class " ~ this.classinfo.name);
        //return this !is o;
    }

    /**
     * Returns !=0 if this object does have the same contents as obj.
     */
    bool opEquals(Object o)
    {
        return this is o;
    }

    interface Monitor
    {
        void lock();
        void unlock();
    }

    /**
     * Create instance of class specified by classname.
     * The class must either have no constructors or have
     * a default constructor.
     * Returns:
     *   null if failed
     */
    static Object factory(string classname)
    {
        auto ci = TypeInfo_Class.find(classname);
        if (ci)
        {
            return ci.create();
        }
        return null;
    }
}

/************************
 * Returns true if lhs and rhs are equal.
 */
bool opEquals(const Object lhs, const Object rhs)
{
    // A hack for the moment.
    return opEquals(cast()lhs, cast()rhs);
}

bool opEquals(Object lhs, Object rhs)
{
    // If aliased to the same object or both null => equal
    if (lhs is rhs) return true;

    // If either is null => non-equal
    if (lhs is null || rhs is null) return false;

    // If same exact type => one call to method opEquals
    if (typeid(lhs) is typeid(rhs) || typeid(lhs).opEquals(typeid(rhs)))
        return lhs.opEquals(rhs);

    // General case => symmetric calls to method opEquals
    return lhs.opEquals(rhs) && rhs.opEquals(lhs);
}

/**
 * Information about an interface.
 * When an object is accessed via an interface, an Interface* appears as the
 * first entry in its vtbl.
 */
struct Interface
{
    TypeInfo_Class   classinfo;  /// .classinfo for this interface (not for containing class)
    void*[]     vtbl;
    ptrdiff_t   offset;     /// offset to Interface 'this' from Object 'this'
}

/**
 * Runtime type information about a class. Can be retrieved for any class type
 * or instance by using the .classinfo property.
 * A pointer to this appears as the first entry in the class's vtbl[].
 */
alias TypeInfo_Class Classinfo;

/**
 * Array of pairs giving the offset and type information for each
 * member in an aggregate.
 */
struct OffsetTypeInfo
{
    size_t   offset;    /// Offset of member from start of object
    TypeInfo ti;        /// TypeInfo for this member
}

/**
 * Runtime type information about a type.
 * Can be retrieved for any type using a
 * <a href="../expression.html#typeidexpression">TypeidExpression</a>.
 */
class TypeInfo
{
    override string toString() const
    {
        // hack to keep const qualifiers for TypeInfo member functions
        return (cast()super).toString();
    }

    override size_t toHash() @trusted const
    {
        try
        {
            auto data = this.toString();
            return hashOf(data.ptr, data.length);
        }
        catch (Throwable)
        {
            // This should never happen; remove when toString() is made nothrow

            // BUG: this prevents a compacting GC from working, needs to be fixed
            return cast(size_t)cast(void*)this;
        }
    }

    override int opCmp(Object o)
    {
        if (this is o)
            return 0;
        TypeInfo ti = cast(TypeInfo)o;
        if (ti is null)
            return 1;
        return dstrcmp(this.toString(), ti.toString());
    }

    override bool opEquals(Object o)
    {
        /* TypeInfo instances are singletons, but duplicates can exist
         * across DLL's. Therefore, comparing for a name match is
         * sufficient.
         */
        if (this is o)
            return true;
        auto ti = cast(const TypeInfo)o;
        return ti && this.toString() == ti.toString();
    }

    /// Returns a hash of the instance of a type.
    size_t getHash(in void* p) @trusted nothrow const { return cast(size_t)p; }

    /// Compares two instances for equality.
    bool equals(in void* p1, in void* p2) const { return p1 == p2; }

    /// Compares two instances for &lt;, ==, or &gt;.
    int compare(in void* p1, in void* p2) const { return 0; }

    /// Returns size of the type.
    @property size_t tsize() nothrow pure const @safe { return 0; }

    /// Swaps two instances of the type.
    void swap(void* p1, void* p2) const
    {
        size_t n = tsize;
        for (size_t i = 0; i < n; i++)
        {
            byte t = (cast(byte *)p1)[i];
            (cast(byte*)p1)[i] = (cast(byte*)p2)[i];
            (cast(byte*)p2)[i] = t;
        }
    }

    /// Get TypeInfo for 'next' type, as defined by what kind of type this is,
    /// null if none.
    @property inout(TypeInfo) next() nothrow pure inout { return null; }

    /// Return default initializer.  If the type should be initialized to all zeros,
    /// an array with a null ptr and a length equal to the type size will be returned.
    // TODO: make this a property, but may need to be renamed to diambiguate with T.init...
    const(void)[] init() nothrow pure const @safe { return null; }

    /// Get flags for type: 1 means GC should scan for pointers
    @property uint flags() nothrow pure const @safe { return 0; }

    /// Get type information on the contents of the type; null if not available
    const(OffsetTypeInfo)[] offTi() const { return null; }
    /// Run the destructor on the object and all its sub-objects
    void destroy(void* p) const {}
    /// Run the postblit on the object and all its sub-objects
    void postblit(void* p) const {}


    /// Return alignment of type
    @property size_t talign() nothrow pure const @safe { return tsize; }

    /** Return internal info on arguments fitting into 8byte.
     * See X86-64 ABI 3.2.3
     */
    version (X86_64) int argTypes(out TypeInfo arg1, out TypeInfo arg2) @safe nothrow
    {
        arg1 = this;
        return 0;
    }

    /** Return info used by the garbage collector to do precise collection.
     */
    @property immutable(void)* rtInfo() nothrow pure const @safe { return null; }
}

class TypeInfo_Typedef : TypeInfo
{
    override string toString() const { return name; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Typedef)o;
        return c && this.name == c.name &&
                    this.base == c.base;
    }

    override size_t getHash(in void* p) const { return base.getHash(p); }
    override bool equals(in void* p1, in void* p2) const { return base.equals(p1, p2); }
    override int compare(in void* p1, in void* p2) const { return base.compare(p1, p2); }
    override @property size_t tsize() nothrow pure const { return base.tsize; }
    override void swap(void* p1, void* p2) const { return base.swap(p1, p2); }

    override @property inout(TypeInfo) next() nothrow pure inout { return base.next; }
    override @property uint flags() nothrow pure const { return base.flags; }
    override const(void)[] init() nothrow pure const @safe { return m_init.length ? m_init : base.init(); }

    override @property size_t talign() nothrow pure const { return base.talign; }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        return base.argTypes(arg1, arg2);
    }

    override @property immutable(void)* rtInfo() const { return base.rtInfo; }

    TypeInfo base;
    string   name;
    void[]   m_init;
}

class TypeInfo_Enum : TypeInfo_Typedef
{

}

class TypeInfo_Pointer : TypeInfo
{
    override string toString() const { return m_next.toString() ~ "*"; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Pointer)o;
        return c && this.m_next == c.m_next;
    }

    override size_t getHash(in void* p) @trusted const
    {
        return cast(size_t)*cast(void**)p;
    }

    override bool equals(in void* p1, in void* p2) const
    {
        return *cast(void**)p1 == *cast(void**)p2;
    }

    override int compare(in void* p1, in void* p2) const
    {
        if (*cast(void**)p1 < *cast(void**)p2)
            return -1;
        else if (*cast(void**)p1 > *cast(void**)p2)
            return 1;
        else
            return 0;
    }

    override @property size_t tsize() nothrow pure const
    {
        return (void*).sizeof;
    }

    override void swap(void* p1, void* p2) const
    {
        void* tmp = *cast(void**)p1;
        *cast(void**)p1 = *cast(void**)p2;
        *cast(void**)p2 = tmp;
    }

    override @property inout(TypeInfo) next() nothrow pure inout { return m_next; }
    override @property uint flags() nothrow pure const { return 1; }

    TypeInfo m_next;
}

class TypeInfo_Array : TypeInfo
{
    override string toString() const { return value.toString() ~ "[]"; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Array)o;
        return c && this.value == c.value;
    }

    override size_t getHash(in void* p) @trusted const
    {
        void[] a = *cast(void[]*)p;
        return hashOf(a.ptr, a.length * value.tsize);
    }

    override bool equals(in void* p1, in void* p2) const
    {
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        if (a1.length != a2.length)
            return false;
        size_t sz = value.tsize;
        for (size_t i = 0; i < a1.length; i++)
        {
            if (!value.equals(a1.ptr + i * sz, a2.ptr + i * sz))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2) const
    {
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        size_t sz = value.tsize;
        size_t len = a1.length;

        if (a2.length < len)
            len = a2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = value.compare(a1.ptr + u * sz, a2.ptr + u * sz);
            if (result)
                return result;
        }
        return cast(int)a1.length - cast(int)a2.length;
    }

    override @property size_t tsize() nothrow pure const
    {
        return (void[]).sizeof;
    }

    override void swap(void* p1, void* p2) const
    {
        void[] tmp = *cast(void[]*)p1;
        *cast(void[]*)p1 = *cast(void[]*)p2;
        *cast(void[]*)p2 = tmp;
    }

    TypeInfo value;

    override @property inout(TypeInfo) next() nothrow pure inout
    {
        return value;
    }

    override @property uint flags() nothrow pure const { return 1; }

    override @property size_t talign() nothrow pure const
    {
        return (void[]).alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        arg1 = typeid(size_t);
        arg2 = typeid(void*);
        return 0;
    }
}

class TypeInfo_StaticArray : TypeInfo
{
    override string toString() const
    {
        char[20] tmp = void;
        return cast(string)(value.toString() ~ "[" ~ tmp.uintToString(len) ~ "]");
    }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_StaticArray)o;
        return c && this.len == c.len &&
                    this.value == c.value;
    }

    override size_t getHash(in void* p) @trusted const
    {
        size_t sz = value.tsize;
        size_t hash = 0;
        for (size_t i = 0; i < len; i++)
            hash += value.getHash(p + i * sz);
        return hash;
    }

    override bool equals(in void* p1, in void* p2) const
    {
        size_t sz = value.tsize;

        for (size_t u = 0; u < len; u++)
        {
            if (!value.equals(p1 + u * sz, p2 + u * sz))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2) const
    {
        size_t sz = value.tsize;

        for (size_t u = 0; u < len; u++)
        {
            int result = value.compare(p1 + u * sz, p2 + u * sz);
            if (result)
                return result;
        }
        return 0;
    }

    override @property size_t tsize() nothrow pure const
    {
        return len * value.tsize;
    }

    override void swap(void* p1, void* p2) const
    {
        void* tmp;
        size_t sz = value.tsize;
        ubyte[16] buffer;
        void* pbuffer;

        if (sz < buffer.sizeof)
            tmp = buffer.ptr;
        else
            tmp = pbuffer = (new void[sz]).ptr;

        for (size_t u = 0; u < len; u += sz)
        {
            size_t o = u * sz;
            memcpy(tmp, p1 + o, sz);
            memcpy(p1 + o, p2 + o, sz);
            memcpy(p2 + o, tmp, sz);
        }
        if (pbuffer)
            GC.free(pbuffer);
    }

    override const(void)[] init() nothrow pure const { return value.init(); }
    override @property inout(TypeInfo) next() nothrow pure inout { return value; }
    override @property uint flags() nothrow pure const { return value.flags; }

    override void destroy(void* p) const
    {
        auto sz = value.tsize;
        p += sz * len;
        foreach (i; 0 .. len)
        {
            p -= sz;
            value.destroy(p);
        }
    }

    override void postblit(void* p) const
    {
        auto sz = value.tsize;
        foreach (i; 0 .. len)
        {
            value.postblit(p);
            p += sz;
        }
    }

    TypeInfo value;
    size_t   len;

    override @property size_t talign() nothrow pure const
    {
        return value.talign;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        arg1 = typeid(void*);
        return 0;
    }
}

class TypeInfo_AssociativeArray : TypeInfo
{
    override string toString() const
    {
        return cast(string)(next.toString() ~ "[" ~ key.toString() ~ "]");
    }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_AssociativeArray)o;
        return c && this.key == c.key &&
                    this.value == c.value;
    }

    override bool equals(in void* p1, in void* p2) @trusted const
    {
        return !!_aaEqual(this, *cast(const void**) p1, *cast(const void**) p2);
    }

    override hash_t getHash(in void* p) nothrow @trusted const
    {
        return _aaGetHash(cast(void*)p, this);
    }

    // BUG: need to add the rest of the functions

    override @property size_t tsize() nothrow pure const
    {
        return (char[int]).sizeof;
    }

    override @property inout(TypeInfo) next() nothrow pure inout { return value; }
    override @property uint flags() nothrow pure const { return 1; }

    TypeInfo value;
    TypeInfo key;

    TypeInfo impl;

    override @property size_t talign() nothrow pure const
    {
        return (char[int]).alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        arg1 = typeid(void*);
        return 0;
    }
}

class TypeInfo_Vector : TypeInfo
{
    override string toString() const { return "__vector(" ~ base.toString() ~ ")"; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Vector)o;
        return c && this.base == c.base;
    }

    override size_t getHash(in void* p) const { return base.getHash(p); }
    override bool equals(in void* p1, in void* p2) const { return base.equals(p1, p2); }
    override int compare(in void* p1, in void* p2) const { return base.compare(p1, p2); }
    override @property size_t tsize() nothrow pure const { return base.tsize; }
    override void swap(void* p1, void* p2) const { return base.swap(p1, p2); }

    override @property inout(TypeInfo) next() nothrow pure inout { return base.next; }
    override @property uint flags() nothrow pure const { return base.flags; }
    override const(void)[] init() nothrow pure const { return base.init(); }

    override @property size_t talign() nothrow pure const { return 16; }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        return base.argTypes(arg1, arg2);
    }

    TypeInfo base;
}

class TypeInfo_Function : TypeInfo
{
    override string toString() const
    {
        return cast(string)(next.toString() ~ "()");
    }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Function)o;
        return c && this.deco == c.deco;
    }

    // BUG: need to add the rest of the functions

    override @property size_t tsize() nothrow pure const
    {
        return 0;       // no size for functions
    }

    TypeInfo next;
    string deco;
}

class TypeInfo_Delegate : TypeInfo
{
    override string toString() const
    {
        return cast(string)(next.toString() ~ " delegate()");
    }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Delegate)o;
        return c && this.deco == c.deco;
    }

    // BUG: need to add the rest of the functions

    override @property size_t tsize() nothrow pure const
    {
        alias int delegate() dg;
        return dg.sizeof;
    }

    override @property uint flags() nothrow pure const { return 1; }

    TypeInfo next;
    string deco;

    override @property size_t talign() nothrow pure const
    {
        alias int delegate() dg;
        return dg.alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        arg1 = typeid(void*);
        arg2 = typeid(void*);
        return 0;
    }
}

/**
 * Runtime type information about a class.
 * Can be retrieved from an object instance by using the
 * $(LINK2 ../property.html#classinfo, .classinfo) property.
 */
class TypeInfo_Class : TypeInfo
{
    override string toString() const { return info.name; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Class)o;
        return c && this.info.name == c.info.name;
    }

    override size_t getHash(in void* p) @trusted const
    {
        auto o = *cast(Object*)p;
        return o ? o.toHash() : 0;
    }

    override bool equals(in void* p1, in void* p2) const
    {
        Object o1 = *cast(Object*)p1;
        Object o2 = *cast(Object*)p2;

        return (o1 is o2) || (o1 && o1.opEquals(o2));
    }

    override int compare(in void* p1, in void* p2) const
    {
        Object o1 = *cast(Object*)p1;
        Object o2 = *cast(Object*)p2;
        int c = 0;

        // Regard null references as always being "less than"
        if (o1 !is o2)
        {
            if (o1)
            {
                if (!o2)
                    c = 1;
                else
                    c = o1.opCmp(o2);
            }
            else
                c = -1;
        }
        return c;
    }

    override @property size_t tsize() nothrow pure const
    {
        return Object.sizeof;
    }

    override @property uint flags() nothrow pure const { return 1; }

    override @property const(OffsetTypeInfo)[] offTi() nothrow pure const
    {
        return m_offTi;
    }

    @property auto info() @safe nothrow pure const { return this; }
    @property auto typeinfo() @safe nothrow pure const { return this; }

    byte[]      init;           /** class static initializer
                                 * (init.length gives size in bytes of class)
                                 */
    string      name;           /// class name
    void*[]     vtbl;           /// virtual function pointer table
    Interface[] interfaces;     /// interfaces this class implements
    TypeInfo_Class   base;           /// base class
    void*       destructor;
    void function(Object) classInvariant;
    uint        m_flags;
    //  1:                      // is IUnknown or is derived from IUnknown
    //  2:                      // has no possible pointers into GC memory
    //  4:                      // has offTi[] member
    //  8:                      // has constructors
    // 16:                      // has xgetMembers member
    // 32:                      // has typeinfo member
    // 64:                      // is not constructable
    void*       deallocator;
    OffsetTypeInfo[] m_offTi;
    void function(Object) defaultConstructor;   // default Constructor

    immutable(void)* m_RTInfo;        // data for precise GC
    override @property immutable(void)* rtInfo() const { return m_RTInfo; }

    /**
     * Search all modules for TypeInfo_Class corresponding to classname.
     * Returns: null if not found
     */
    static const(TypeInfo_Class) find(in char[] classname)
    {
        foreach (m; ModuleInfo)
        {
          if (m)
            //writefln("module %s, %d", m.name, m.localClasses.length);
            foreach (c; m.localClasses)
            {
                //writefln("\tclass %s", c.name);
                if (c.name == classname)
                    return c;
            }
        }
        return null;
    }

    /**
     * Create instance of Object represented by 'this'.
     */
    Object create() const
    {
        if (m_flags & 8 && !defaultConstructor)
            return null;
        if (m_flags & 64) // abstract
            return null;
        Object o = _d_newclass(this);
        if (m_flags & 8 && defaultConstructor)
        {
            defaultConstructor(o);
        }
        return o;
    }
}

alias TypeInfo_Class ClassInfo;

class TypeInfo_Interface : TypeInfo
{
    override string toString() const { return info.name; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Interface)o;
        return c && this.info.name == c.classinfo.name;
    }

    override size_t getHash(in void* p) @trusted const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p;
        Object o = cast(Object)(*cast(void**)p - pi.offset);
        assert(o);
        return o.toHash();
    }

    override bool equals(in void* p1, in void* p2) const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);

        return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }

    override int compare(in void* p1, in void* p2) const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);
        int c = 0;

        // Regard null references as always being "less than"
        if (o1 != o2)
        {
            if (o1)
            {
                if (!o2)
                    c = 1;
                else
                    c = o1.opCmp(o2);
            }
            else
                c = -1;
        }
        return c;
    }

    override @property size_t tsize() nothrow pure const
    {
        return Object.sizeof;
    }

    override @property uint flags() nothrow pure const { return 1; }

    TypeInfo_Class info;
}

class TypeInfo_Struct : TypeInfo
{
    override string toString() const { return name; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto s = cast(const TypeInfo_Struct)o;
        return s && this.name == s.name &&
                    this.init().length == s.init().length;
    }

    override size_t getHash(in void* p) @safe pure nothrow const
    {
        assert(p);
        if (xtoHash)
        {
            return (*xtoHash)(p);
        }
        else
        {
            return hashOf(p, init().length);
        }
    }

    override bool equals(in void* p1, in void* p2) @trusted pure nothrow const
    {
        if (!p1 || !p2)
            return false;
        else if (xopEquals)
            return (*xopEquals)(p1, p2);
        else if (p1 == p2)
            return true;
        else
            // BUG: relies on the GC not moving objects
            return memcmp(p1, p2, init().length) == 0;
    }

    override int compare(in void* p1, in void* p2) @trusted pure nothrow const
    {
        // Regard null references as always being "less than"
        if (p1 != p2)
        {
            if (p1)
            {
                if (!p2)
                    return true;
                else if (xopCmp)
                    return (*xopCmp)(p2, p1);
                else
                    // BUG: relies on the GC not moving objects
                    return memcmp(p1, p2, init().length);
            }
            else
                return -1;
        }
        return 0;
    }

    override @property size_t tsize() nothrow pure const
    {
        return init().length;
    }

    override const(void)[] init() nothrow pure const @safe { return m_init; }

    override @property uint flags() nothrow pure const { return m_flags; }

    override @property size_t talign() nothrow pure const { return m_align; }

    override void destroy(void* p) const
    {
        if (xdtor)
            (*xdtor)(p);
    }

    override void postblit(void* p) const
    {
        if (xpostblit)
            (*xpostblit)(p);
    }

    string name;
    void[] m_init;      // initializer; init.ptr == null if 0 initialize

  @safe pure nothrow
  {
    size_t   function(in void*)           xtoHash;
    bool     function(in void*, in void*) xopEquals;
    int      function(in void*, in void*) xopCmp;
    char[]   function(in void*)           xtoString;

    uint m_flags;
  }
    void function(void*)                    xdtor;
    void function(void*)                    xpostblit;

    uint m_align;

    override @property immutable(void)* rtInfo() const { return m_RTInfo; }

    version (X86_64)
    {
        override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
        {
            arg1 = m_arg1;
            arg2 = m_arg2;
            return 0;
        }
        TypeInfo m_arg1;
        TypeInfo m_arg2;
    }
    immutable(void)* m_RTInfo;                // data for precise GC
}

unittest
{
    struct S
    {
        const bool opEquals(ref const S rhs)
        {
            return false;
        }
    }
    S s;
    assert(!typeid(S).equals(&s, &s));
}

class TypeInfo_Tuple : TypeInfo
{
    TypeInfo[] elements;

    override string toString() const
    {
        string s = "(";
        foreach (i, element; elements)
        {
            if (i)
                s ~= ',';
            s ~= element.toString();
        }
        s ~= ")";
        return s;
    }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;

        auto t = cast(const TypeInfo_Tuple)o;
        if (t && elements.length == t.elements.length)
        {
            for (size_t i = 0; i < elements.length; i++)
            {
                if (elements[i] != t.elements[i])
                    return false;
            }
            return true;
        }
        return false;
    }

    override size_t getHash(in void* p) const
    {
        assert(0);
    }

    override bool equals(in void* p1, in void* p2) const
    {
        assert(0);
    }

    override int compare(in void* p1, in void* p2) const
    {
        assert(0);
    }

    override @property size_t tsize() nothrow pure const
    {
        assert(0);
    }

    override void swap(void* p1, void* p2) const
    {
        assert(0);
    }

    override void destroy(void* p) const
    {
        assert(0);
    }

    override void postblit(void* p) const
    {
        assert(0);
    }

    override @property size_t talign() nothrow pure const
    {
        assert(0);
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        assert(0);
    }
}

class TypeInfo_Const : TypeInfo
{
    override string toString() const
    {
        return cast(string) ("const(" ~ base.toString() ~ ")");
    }

    //override bool opEquals(Object o) { return base.opEquals(o); }
    override bool opEquals(Object o)
    {
        if (this is o)
            return true;

        if (typeid(this) != typeid(o))
            return false;

        auto t = cast(TypeInfo_Const)o;
        return base.opEquals(t.base);
    }

    override size_t getHash(in void *p) const { return base.getHash(p); }
    override bool equals(in void *p1, in void *p2) const { return base.equals(p1, p2); }
    override int compare(in void *p1, in void *p2) const { return base.compare(p1, p2); }
    override @property size_t tsize() nothrow pure const { return base.tsize; }
    override void swap(void *p1, void *p2) const { return base.swap(p1, p2); }

    override @property inout(TypeInfo) next() nothrow pure inout { return base.next; }
    override @property uint flags() nothrow pure const { return base.flags; }
    override const(void)[] init() nothrow pure const { return base.init(); }

    override @property size_t talign() nothrow pure const { return base.talign; }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        return base.argTypes(arg1, arg2);
    }

    TypeInfo base;
}

class TypeInfo_Invariant : TypeInfo_Const
{
    override string toString() const
    {
        return cast(string) ("immutable(" ~ base.toString() ~ ")");
    }
}

class TypeInfo_Shared : TypeInfo_Const
{
    override string toString() const
    {
        return cast(string) ("shared(" ~ base.toString() ~ ")");
    }
}

class TypeInfo_Inout : TypeInfo_Const
{
    override string toString() const
    {
        return cast(string) ("inout(" ~ base.toString() ~ ")");
    }
}

abstract class MemberInfo
{
    @property string name() nothrow pure;
}

class MemberInfo_field : MemberInfo
{
    this(string name, TypeInfo ti, size_t offset)
    {
        m_name = name;
        m_typeinfo = ti;
        m_offset = offset;
    }

    override @property string name() nothrow pure { return m_name; }
    @property TypeInfo typeInfo() nothrow pure { return m_typeinfo; }
    @property size_t offset() nothrow pure { return m_offset; }

    string   m_name;
    TypeInfo m_typeinfo;
    size_t   m_offset;
}

class MemberInfo_function : MemberInfo
{
    this(string name, TypeInfo ti, void* fp, uint flags)
    {
        m_name = name;
        m_typeinfo = ti;
        m_fp = fp;
        m_flags = flags;
    }

    override @property string name() nothrow pure { return m_name; }
    @property TypeInfo typeInfo() nothrow pure { return m_typeinfo; }
    @property void* fp() nothrow pure { return m_fp; }
    @property uint flags() nothrow pure { return m_flags; }

    string   m_name;
    TypeInfo m_typeinfo;
    void*    m_fp;
    uint     m_flags;
}


///////////////////////////////////////////////////////////////////////////////
// Throwable
///////////////////////////////////////////////////////////////////////////////


/**
 * The base class of all thrown objects.
 *
 * All thrown objects must inherit from Throwable. Class $(D Exception), which
 * derives from this class, represents the category of thrown objects that are
 * safe to catch and handle. In principle, one should not catch Throwable
 * objects that are not derived from $(D Exception), as they represent
 * unrecoverable runtime errors. Certain runtime guarantees may fail to hold
 * when these errors are thrown, making it unsafe to continue execution after
 * catching them.
 */
class Throwable : Object
{
    interface TraceInfo
    {
        int opApply(scope int delegate(ref const(char[]))) const;
        int opApply(scope int delegate(ref size_t, ref const(char[]))) const;
        string toString() const;
    }

    string      msg;    /// A message describing the error.

    /**
     * The _file name and line number of the D source code corresponding with
     * where the error was thrown from.
     */
    string      file;
    size_t      line;   /// ditto

    /**
     * The stack trace of where the error happened. This is an opaque object
     * that can either be converted to $(D string), or iterated over with $(D
     * foreach) to extract the items in the stack trace (as strings).
     */
    TraceInfo   info;

    /**
     * A reference to the _next error in the list. This is used when a new
     * $(D Throwable) is thrown from inside a $(D catch) block. The originally
     * caught $(D Exception) will be chained to the new $(D Throwable) via this
     * field.
     */
    Throwable   next;

    @safe pure nothrow this(string msg, Throwable next = null)
    {
        this.msg = msg;
        this.next = next;
        //this.info = _d_traceContext();
    }

    @safe pure nothrow this(string msg, string file, size_t line, Throwable next = null)
    {
        this(msg, next);
        this.file = file;
        this.line = line;
        //this.info = _d_traceContext();
    }

    override string toString()
    {
        char[20] tmp = void;
        char[]   buf;

        if (file)
        {
           buf ~= this.classinfo.name ~ "@" ~ file ~ "(" ~ tmp.uintToString(line) ~ ")";
        }
        else
        {
            buf ~= this.classinfo.name;
        }
        if (msg)
        {
            buf ~= ": " ~ msg;
        }
        if (info)
        {
            try
            {
                buf ~= "\n----------------";
                foreach (t; info)
                    buf ~= "\n" ~ t;
            }
            catch (Throwable)
            {
                // ignore more errors
            }
        }
        return cast(string) buf;
    }
}


alias Throwable.TraceInfo function(void* ptr) TraceHandler;
private __gshared TraceHandler traceHandler = null;


/**
 * Overrides the default trace hander with a user-supplied version.
 *
 * Params:
 *  h = The new trace handler.  Set to null to use the default handler.
 */
extern (C) void  rt_setTraceHandler(TraceHandler h)
{
    traceHandler = h;
}

/**
 * Return the current trace handler
 */
extern (C) TraceHandler rt_getTraceHandler()
{
    return traceHandler;
}

/**
 * This function will be called when an exception is constructed.  The
 * user-supplied trace handler will be called if one has been supplied,
 * otherwise no trace will be generated.
 *
 * Params:
 *  ptr = A pointer to the location from which to generate the trace, or null
 *        if the trace should be generated from within the trace handler
 *        itself.
 *
 * Returns:
 *  An object describing the current calling context or null if no handler is
 *  supplied.
 */
extern (C) Throwable.TraceInfo _d_traceContext(void* ptr = null)
{
    if (traceHandler is null)
        return null;
    return traceHandler(ptr);
}


/**
 * The base class of all errors that are safe to catch and handle.
 *
 * In principle, only thrown objects derived from this class are safe to catch
 * inside a $(D catch) block. Thrown objects not derived from Exception
 * represent runtime errors that should not be caught, as certain runtime
 * guarantees may not hold, making it unsafe to continue program execution.
 */
class Exception : Throwable
{

    /**
     * Creates a new instance of Exception. The next parameter is used
     * internally and should be always be $(D null) when passed by user code.
     * This constructor does not automatically throw the newly-created
     * Exception; the $(D throw) statement should be used for that purpose.
     */
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}

unittest
{
    {
        auto e = new Exception("msg");
        assert(e.file == __FILE__);
        assert(e.line == __LINE__ - 2);
        assert(e.next is null);
        assert(e.msg == "msg");
    }

    {
        auto e = new Exception("msg", new Exception("It's an Excepton!"), "hello", 42);
        assert(e.file == "hello");
        assert(e.line == 42);
        assert(e.next !is null);
        assert(e.msg == "msg");
    }

    {
        auto e = new Exception("msg", "hello", 42, new Exception("It's an Exception!"));
        assert(e.file == "hello");
        assert(e.line == 42);
        assert(e.next !is null);
        assert(e.msg == "msg");
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

    /// The first Exception which was bypassed when this Error was thrown,
    /// or null if no Exceptions were pending.
    Throwable   bypassedException;
}

unittest
{
    {
        auto e = new Error("msg");
        assert(e.file is null);
        assert(e.line == 0);
        assert(e.next is null);
        assert(e.msg == "msg");
        assert(e.bypassedException is null);
    }

    {
        auto e = new Error("msg", new Exception("It's an Excepton!"));
        assert(e.file is null);
        assert(e.line == 0);
        assert(e.next !is null);
        assert(e.msg == "msg");
        assert(e.bypassedException is null);
    }

    {
        auto e = new Error("msg", "hello", 42, new Exception("It's an Exception!"));
        assert(e.file == "hello");
        assert(e.line == 42);
        assert(e.next !is null);
        assert(e.msg == "msg");
        assert(e.bypassedException is null);
    }
}


///////////////////////////////////////////////////////////////////////////////
// ModuleInfo
///////////////////////////////////////////////////////////////////////////////


enum
{
    MIctorstart  = 1,   // we've started constructing it
    MIctordone   = 2,   // finished construction
    MIstandalone = 4,   // module ctor does not depend on other module
                        // ctors being done first
    MItlsctor    = 8,
    MItlsdtor    = 0x10,
    MIctor       = 0x20,
    MIdtor       = 0x40,
    MIxgetMembers = 0x80,
    MIictor      = 0x100,
    MIunitTest   = 0x200,
    MIimportedModules = 0x400,
    MIlocalClasses = 0x800,
    MInew        = 0x80000000        // it's the "new" layout
}


struct ModuleInfo
{
    struct New
    {
        uint flags;
        uint index;                        // index into _moduleinfo_array[]

        /* Order of appearance, depending on flags
         * tlsctor
         * tlsdtor
         * xgetMembers
         * ctor
         * dtor
         * ictor
         * importedModules
         * localClasses
         * name
         */
    }
    struct Old
    {
        string          name;
        ModuleInfo*[]    importedModules;
        TypeInfo_Class[]     localClasses;
        uint            flags;

        void function() ctor;       // module shared static constructor (order dependent)
        void function() dtor;       // module shared static destructor
        void function() unitTest;   // module unit tests

        void* xgetMembers;          // module getMembers() function

        void function() ictor;      // module shared static constructor (order independent)

        void function() tlsctor;        // module thread local static constructor (order dependent)
        void function() tlsdtor;        // module thread local static destructor

        uint index;                        // index into _moduleinfo_array[]

        void*[1] reserved;          // for future expansion
    }

    union
    {
        New n;
        Old o;
    }

    @property bool isNew() nothrow pure { return (n.flags & MInew) != 0; }

    @property uint index() nothrow pure { return isNew ? n.index : o.index; }
    @property void index(uint i) nothrow pure { if (isNew) n.index = i; else o.index = i; }

    @property uint flags() nothrow pure { return isNew ? n.flags : o.flags; }
    @property void flags(uint f) nothrow pure { if (isNew) n.flags = f; else o.flags = f; }

    @property void function() tlsctor() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MItlsctor)
            {
                size_t off = New.sizeof;
                return *cast(typeof(return)*)(cast(void*)(&this) + off);
            }
            return null;
        }
        else
            return o.tlsctor;
    }

    @property void function() tlsdtor() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MItlsdtor)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                return *cast(typeof(return)*)(cast(void*)(&this) + off);
            }
            return null;
        }
        else
            return o.tlsdtor;
    }

    @property void* xgetMembers() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MIxgetMembers)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                if (n.flags & MItlsdtor)
                    off += o.tlsdtor.sizeof;
                return *cast(typeof(return)*)(cast(void*)(&this) + off);
            }
            return null;
        }
        return o.xgetMembers;
    }

    @property void function() ctor() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MIctor)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                if (n.flags & MItlsdtor)
                    off += o.tlsdtor.sizeof;
                if (n.flags & MIxgetMembers)
                    off += o.xgetMembers.sizeof;
                return *cast(typeof(return)*)(cast(void*)(&this) + off);
            }
            return null;
        }
        return o.ctor;
    }

    @property void function() dtor() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MIdtor)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                if (n.flags & MItlsdtor)
                    off += o.tlsdtor.sizeof;
                if (n.flags & MIxgetMembers)
                    off += o.xgetMembers.sizeof;
                if (n.flags & MIctor)
                    off += o.ctor.sizeof;
                return *cast(typeof(return)*)(cast(void*)(&this) + off);
            }
            return null;
        }
        return o.ctor;
    }

    @property void function() ictor() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MIictor)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                if (n.flags & MItlsdtor)
                    off += o.tlsdtor.sizeof;
                if (n.flags & MIxgetMembers)
                    off += o.xgetMembers.sizeof;
                if (n.flags & MIctor)
                    off += o.ctor.sizeof;
                if (n.flags & MIdtor)
                    off += o.ctor.sizeof;
                return *cast(typeof(return)*)(cast(void*)(&this) + off);
            }
            return null;
        }
        return o.ictor;
    }

    @property void function() unitTest() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MIunitTest)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                if (n.flags & MItlsdtor)
                    off += o.tlsdtor.sizeof;
                if (n.flags & MIxgetMembers)
                    off += o.xgetMembers.sizeof;
                if (n.flags & MIctor)
                    off += o.ctor.sizeof;
                if (n.flags & MIdtor)
                    off += o.ctor.sizeof;
                if (n.flags & MIictor)
                    off += o.ictor.sizeof;
                return *cast(typeof(return)*)(cast(void*)(&this) + off);
            }
            return null;
        }
        return o.unitTest;
    }

    @property ModuleInfo*[] importedModules() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MIimportedModules)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                if (n.flags & MItlsdtor)
                    off += o.tlsdtor.sizeof;
                if (n.flags & MIxgetMembers)
                    off += o.xgetMembers.sizeof;
                if (n.flags & MIctor)
                    off += o.ctor.sizeof;
                if (n.flags & MIdtor)
                    off += o.ctor.sizeof;
                if (n.flags & MIictor)
                    off += o.ictor.sizeof;
                if (n.flags & MIunitTest)
                    off += o.unitTest.sizeof;
                auto plength = cast(size_t*)(cast(void*)(&this) + off);
                ModuleInfo** pm = cast(ModuleInfo**)(plength + 1);
                return pm[0 .. *plength];
            }
            return null;
        }
        return o.importedModules;
    }

    @property TypeInfo_Class[] localClasses() nothrow pure
    {
        if (isNew)
        {
            if (n.flags & MIlocalClasses)
            {
                size_t off = New.sizeof;
                if (n.flags & MItlsctor)
                    off += o.tlsctor.sizeof;
                if (n.flags & MItlsdtor)
                    off += o.tlsdtor.sizeof;
                if (n.flags & MIxgetMembers)
                    off += o.xgetMembers.sizeof;
                if (n.flags & MIctor)
                    off += o.ctor.sizeof;
                if (n.flags & MIdtor)
                    off += o.ctor.sizeof;
                if (n.flags & MIictor)
                    off += o.ictor.sizeof;
                if (n.flags & MIunitTest)
                    off += o.unitTest.sizeof;
                if (n.flags & MIimportedModules)
                {
                    auto plength = cast(size_t*)(cast(void*)(&this) + off);
                    off += size_t.sizeof + *plength * plength.sizeof;
                }
                auto plength = cast(size_t*)(cast(void*)(&this) + off);
                TypeInfo_Class* pt = cast(TypeInfo_Class*)(plength + 1);
                return pt[0 .. *plength];
            }
            return null;
        }
        return o.localClasses;
    }

    @property string name() nothrow pure
    {
        if (isNew)
        {
            size_t off = New.sizeof;
            if (n.flags & MItlsctor)
                off += o.tlsctor.sizeof;
            if (n.flags & MItlsdtor)
                off += o.tlsdtor.sizeof;
            if (n.flags & MIxgetMembers)
                off += o.xgetMembers.sizeof;
            if (n.flags & MIctor)
                off += o.ctor.sizeof;
            if (n.flags & MIdtor)
                off += o.ctor.sizeof;
            if (n.flags & MIictor)
                off += o.ictor.sizeof;
            if (n.flags & MIunitTest)
                off += o.unitTest.sizeof;
            if (n.flags & MIimportedModules)
            {
                auto plength = cast(size_t*)(cast(void*)(&this) + off);
                off += size_t.sizeof + *plength * plength.sizeof;
            }
            if (n.flags & MIlocalClasses)
            {
                auto plength = cast(size_t*)(cast(void*)(&this) + off);
                off += size_t.sizeof + *plength * plength.sizeof;
            }
            auto p = cast(immutable(char)*)(cast(void*)(&this) + off);
            auto len = strlen(p);
            return p[0 .. len];
        }
        return o.name;
    }

    alias int delegate(ref ModuleInfo*) ApplyDg;

    static int opApply(scope ApplyDg dg)
    {
        return rt.minfo.moduleinfos_apply(dg);
    }
}


///////////////////////////////////////////////////////////////////////////////
// Monitor
///////////////////////////////////////////////////////////////////////////////

alias Object.Monitor        IMonitor;
alias void delegate(Object) DEvent;

// NOTE: The dtor callback feature is only supported for monitors that are not
//       supplied by the user.  The assumption is that any object with a user-
//       supplied monitor may have special storage or lifetime requirements and
//       that as a result, storing references to local objects within Monitor
//       may not be safe or desirable.  Thus, devt is only valid if impl is
//       null.
struct Monitor
{
    IMonitor impl;
    /* internal */
    DEvent[] devt;
    size_t   refs;
    /* stuff */
}

Monitor* getMonitor(Object h)
{
    return cast(Monitor*) h.__monitor;
}

void setMonitor(Object h, Monitor* m)
{
    h.__monitor = m;
}

void setSameMutex(shared Object ownee, shared Object owner)
in
{
    assert(ownee.__monitor is null);
}
body
{
    auto m = cast(shared(Monitor)*) owner.__monitor;

    if (m is null)
    {
        _d_monitor_create(cast(Object) owner);
        m = cast(shared(Monitor)*) owner.__monitor;
    }

    auto i = m.impl;
    if (i is null)
    {
        atomicOp!("+=")(m.refs, cast(size_t)1);
        ownee.__monitor = owner.__monitor;
        return;
    }
    // If m.impl is set (ie. if this is a user-created monitor), assume
    // the monitor is garbage collected and simply copy the reference.
    ownee.__monitor = owner.__monitor;
}

extern (C) void _d_monitor_create(Object);
extern (C) void _d_monitor_destroy(Object);
extern (C) void _d_monitor_lock(Object);
extern (C) int  _d_monitor_unlock(Object);

extern (C) void _d_monitordelete(Object h, bool det)
{
    // det is true when the object is being destroyed deterministically (ie.
    // when it is explicitly deleted or is a scope object whose time is up).
    Monitor* m = getMonitor(h);

    if (m !is null)
    {
        IMonitor i = m.impl;
        if (i is null)
        {
            auto s = cast(shared(Monitor)*) m;
            if(!atomicOp!("-=")(s.refs, cast(size_t) 1))
            {
                _d_monitor_devt(m, h);
                _d_monitor_destroy(h);
                setMonitor(h, null);
            }
            return;
        }
        // NOTE: Since a monitor can be shared via setSameMutex it isn't safe
        //       to explicitly delete user-created monitors--there's no
        //       refcount and it may have multiple owners.
        /+
        if (det && (cast(void*) i) !is (cast(void*) h))
        {
            destroy(i);
            GC.free(cast(void*)i);
        }
        +/
        setMonitor(h, null);
    }
}

extern (C) void _d_monitorenter(Object h)
{
    Monitor* m = getMonitor(h);

    if (m is null)
    {
        _d_monitor_create(h);
        m = getMonitor(h);
    }

    IMonitor i = m.impl;

    if (i is null)
    {
        _d_monitor_lock(h);
        return;
    }
    i.lock();
}

extern (C) void _d_monitorexit(Object h)
{
    Monitor* m = getMonitor(h);
    IMonitor i = m.impl;

    if (i is null)
    {
        _d_monitor_unlock(h);
        return;
    }
    i.unlock();
}

extern (C) void _d_monitor_devt(Monitor* m, Object h)
{
    if (m.devt.length)
    {
        DEvent[] devt;

        synchronized (h)
        {
            devt = m.devt;
            m.devt = null;
        }
        foreach (v; devt)
        {
            if (v)
                v(h);
        }
        free(devt.ptr);
    }
}

extern (C) void rt_attachDisposeEvent(Object h, DEvent e)
{
    synchronized (h)
    {
        Monitor* m = getMonitor(h);
        assert(m.impl is null);

        foreach (ref v; m.devt)
        {
            if (v is null || v == e)
            {
                v = e;
                return;
            }
        }

        auto len = m.devt.length + 4; // grow by 4 elements
        auto pos = m.devt.length;     // insert position
        auto p = realloc(m.devt.ptr, DEvent.sizeof * len);
        if (!p)
            onOutOfMemoryError();
        m.devt = (cast(DEvent*)p)[0 .. len];
        m.devt[pos+1 .. len] = null;
        m.devt[pos] = e;
    }
}

extern (C) void rt_detachDisposeEvent(Object h, DEvent e)
{
    synchronized (h)
    {
        Monitor* m = getMonitor(h);
        assert(m.impl is null);

        foreach (p, v; m.devt)
        {
            if (v == e)
            {
                memmove(&m.devt[p],
                        &m.devt[p+1],
                        (m.devt.length - p - 1) * DEvent.sizeof);
                m.devt[$ - 1] = null;
                return;
            }
        }
    }
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

    void* _d_assocarrayliteralT(TypeInfo_AssociativeArray ti, in size_t length, ...);
    int _aaEqual(in TypeInfo tiRaw, in void* e1, in void* e2);
    hash_t _aaGetHash(in void* aa, in TypeInfo tiRaw) nothrow;
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
    // Duplicates of the stuff found in druntime/src/rt/aaA.d
    struct Slot
    {
        Slot *next;
        size_t hash;
        Key key;
        version(D_LP64) align(16) _Unqual!Value value; // c.f. rt/aaA.d, aligntsize()
        else align(4) _Unqual!Value value;

        // Stop creating built-in opAssign
        @disable void opAssign(Slot);
    }

    struct Hashtable
    {
        Slot*[] b;
        size_t nodes;
        TypeInfo keyti;
        Slot*[4] binit;
    }

    Hashtable* p;

    struct Range
    {
        // State
        Slot*[] slots;
        Slot* current;

        this(Hashtable* aa)
        {
            if (aa is null) return;
            slots = aa.b;
            nextSlot();
        }

        void nextSlot()
        {
            foreach (i, slot; slots)
            {
                if (!slot) continue;
                current = slot;
                slots = slots.ptr[i .. slots.length];
                break;
            }
        }

    public:
        @property bool empty() const
        {
            return current is null;
        }

        @property ref inout(Slot) front() inout
        {
            assert(current);
            return *current;
        }

        void popFront()
        {
            assert(current);
            current = current.next;
            if (!current)
            {
                slots = slots[1 .. $];
                nextSlot();
            }
        }
    }

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
            Range state;

            this(Hashtable* p)
            {
                state = Range(p);
            }

            @property ref Key front()
            {
                return state.front.key;
            }

            alias state this;
        }

        return Result(p);
    }

    @property auto byValue()
    {
        static struct Result
        {
            Range state;

            this(Hashtable* p)
            {
                state = Range(p);
            }

            @property ref Value front()
            {
                return *cast(Value*)&state.front.value;
            }

            alias state this;
        }

        return Result(p);
    }
}

unittest
{
    int[int] a;
    foreach (i; a.byKey)
    {
        assert(false);
    }
    foreach (i; a.byValue)
    {
        assert(false);
    }
}

unittest
{
    auto a = [ 1:"one", 2:"two", 3:"three" ];
    auto b = a.dup;
    assert(b == [ 1:"one", 2:"two", 3:"three" ]);

    int[] c;
    foreach (k; a.byKey)
    {
        c ~= k;
    }

    assert(c.length == 3);
    c.sort;
    assert(c[0] == 1);
    assert(c[1] == 2);
    assert(c[2] == 3);
}
unittest
{
    // test for bug 5925
    const a = [4:0];
    const b = [4:0];
    assert(a == b);
}

unittest
{
    // test for bug 9052
    static struct Json {
        Json[string] aa;
        void opAssign(Json) {}
        size_t length() const { return aa.length; }
        // This length() instantiates AssociativeArray!(string, const(Json)) to call AA.length(), and
        // inside ref Slot opAssign(Slot p); (which is automatically generated by compiler in Slot),
        // this.value = p.value would actually fail, because both side types of the assignment
        // are const(Json).
    }
}

unittest
{
    // test for bug 8583: ensure Slot and aaA are on the same page wrt value alignment
    string[byte]    aa0 = [0: "zero"];
    string[uint[3]] aa1 = [[1,2,3]: "onetwothree"];
    ushort[uint[3]] aa2 = [[9,8,7]: 987];
    ushort[uint[4]] aa3 = [[1,2,3,4]: 1234];
    string[uint[5]] aa4 = [[1,2,3,4,5]: "onetwothreefourfive"];

    assert(aa0.byValue.front == "zero");
    assert(aa1.byValue.front == "onetwothree");
    assert(aa2.byValue.front == 987);
    assert(aa3.byValue.front == 1234);
    assert(aa4.byValue.front == "onetwothreefourfive");
}

deprecated("Please use destroy instead of clear.")
alias destroy clear;

/++
    Destroys the given object and puts it in an invalid state. It's used to
    destroy an object so that any cleanup which its destructor or finalizer
    does is done and so that it no longer references any other objects. It does
    $(I not) initiate a GC cycle or free any GC memory.
  +/
void destroy(T)(T obj) if (is(T == class))
{
    rt_finalize(cast(void*)obj);
}

void destroy(T)(T obj) if (is(T == interface))
{
    destroy(cast(Object)obj);
}

version(unittest) unittest
{
   interface I { }
   {
       class A: I { string s = "A"; this() {} }
       auto a = new A, b = new A;
       a.s = b.s = "asd";
       destroy(a);
       assert(a.s == "A");

       I i = b;
       destroy(i);
       assert(b.s == "A");
   }
   {
       static bool destroyed = false;
       class B: I
       {
           string s = "B";
           this() {}
           ~this()
           {
               destroyed = true;
           }
       }
       auto a = new B, b = new B;
       a.s = b.s = "asd";
       destroy(a);
       assert(destroyed);
       assert(a.s == "B");

       destroyed = false;
       I i = b;
       destroy(i);
       assert(destroyed);
       assert(b.s == "B");
   }
   // this test is invalid now that the default ctor is not run after clearing
   version(none)
   {
       class C
       {
           string s;
           this()
           {
               s = "C";
           }
       }
       auto a = new C;
       a.s = "asd";
       destroy(a);
       assert(a.s == "C");
   }
}

void destroy(T)(ref T obj) if (is(T == struct))
{
    typeid(T).destroy( &obj );
    auto buf = (cast(ubyte*) &obj)[0 .. T.sizeof];
    auto init = cast(ubyte[])typeid(T).init();
    if(init.ptr is null) // null ptr means initialize to 0s
        buf[] = 0;
    else
        buf[] = init[];
}

version(unittest) unittest
{
   {
       struct A { string s = "A";  }
       A a;
       a.s = "asd";
       destroy(a);
       assert(a.s == "A");
   }
   {
       static int destroyed = 0;
       struct C
       {
           string s = "C";
           ~this()
           {
               destroyed ++;
           }
       }

       struct B
       {
           C c;
           string s = "B";
           ~this()
           {
               destroyed ++;
           }
       }
       B a;
       a.s = "asd";
       a.c.s = "jkl";
       destroy(a);
       assert(destroyed == 2);
       assert(a.s == "B");
       assert(a.c.s == "C" );
   }
}

void destroy(T : U[n], U, size_t n)(ref T obj)
{
    obj[] = U.init;
}

version(unittest) unittest
{
    int[2] a;
    a[0] = 1;
    a[1] = 2;
    destroy(a);
    assert(a == [ 0, 0 ]);
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

version(unittest) unittest
{
   {
       int a = 42;
       destroy(a);
       assert(a == 0);
   }
   {
       float a = 42;
       destroy(a);
       assert(isnan(a));
   }
}

version (unittest)
{
    bool isnan(float x)
    {
        return x != x;
    }
}

/**
 * (Property) Get the current capacity of a slice. The capacity is the size
 * that the slice can grow to before the underlying array must be
 * reallocated or extended.
 *
 * If an append must reallocate a slice with no possibility of extension, then
 * 0 is returned. This happens when the slice references a static array, or
 * if another slice references elements past the end of the current slice.
 *
 * Note: The capacity of a slice may be impacted by operations on other slices.
 */
@property size_t capacity(T)(T[] arr) pure nothrow
{
    return _d_arraysetcapacity(typeid(T[]), 0, cast(void *)&arr);
}
///
unittest
{
    //Static array slice: no capacity
    int[4] sarray = [1, 2, 3, 4];
    int[]  slice  = sarray[];
    assert(sarray.capacity == 0);
    //Appending to slice will reallocate to a new array
    slice ~= 5;
    assert(slice.capacity >= 5);

    //Dynamic array slices
    int[] a = [1, 2, 3, 4];
    int[] b = a[1 .. $];
    int[] c = a[1 .. $ - 1];
    assert(a.capacity != 0);
    assert(a.capacity == b.capacity + 1); //both a and b share the same tail
    assert(c.capacity == 0);              //an append to c must relocate c.
}

/**
 * Reserves capacity for a slice. The capacity is the size
 * that the slice can grow to before the underlying array must be
 * reallocated or extended.
 *
 * The return value is the new capacity of the array (which may be larger than
 * the requested capacity).
 */
size_t reserve(T)(ref T[] arr, size_t newcapacity) pure nothrow
{
    return _d_arraysetcapacity(typeid(T[]), newcapacity, cast(void *)&arr);
}
///
unittest
{
    //Static array slice: no capacity. Reserve relocates.
    int[4] sarray = [1, 2, 3, 4];
    int[]  slice  = sarray[];
    auto u = slice.reserve(8);
    assert(u >= 8);
    assert(sarray.ptr !is slice.ptr);
    assert(slice.capacity == u);

    //Dynamic array slices
    int[] a = [1, 2, 3, 4];
    a.reserve(8); //prepare a for appending 4 more items
    auto p = a.ptr;
    u = a.capacity;
    a ~= [5, 6, 7, 8];
    assert(p == a.ptr);      //a should not have been reallocated
    assert(u == a.capacity); //a should not have been extended
}

/**
 * Assume that it is safe to append to this array. Appends made to this array
 * after calling this function may append in place, even if the array was a
 * slice of a larger array to begin with.
 *
 * Use this only when you are sure no elements are in use beyond the array in
 * the memory block.  If there are, those elements could be overwritten by
 * appending to this array.
 *
 * Calling this function, and then using references to data located after the
 * given array results in undefined behavior.
 */
void assumeSafeAppend(T)(T[] arr)
{
    _d_arrayshrinkfit(typeid(T[]), *(cast(void[]*)&arr));
}
///
unittest
{
    int[] a = [1, 2, 3, 4];
    int[] b = a[1 .. $ - 1];
    assert(a.capacity >= 4);
    assert(b.capacity == 0);
    b.assumeSafeAppend();
    assert(b.capacity >= 3);
}

unittest
{
    int[] arr;
    auto newcap = arr.reserve(2000);
    assert(newcap >= 2000);
    assert(newcap == arr.capacity);
    auto ptr = arr.ptr;
    foreach(i; 0..2000)
        arr ~= i;
    assert(ptr == arr.ptr);
    arr = arr[0..1];
    arr.assumeSafeAppend();
    arr ~= 5;
    assert(ptr == arr.ptr);
}


version (none)
{
    // enforce() copied from Phobos std.contracts for destroy(), left out until
    // we decide whether to use it.


    T _enforce(T, string file = __FILE__, int line = __LINE__)
        (T value, lazy const(char)[] msg = null)
    {
        if (!value) bailOut(file, line, msg);
        return value;
    }

    T _enforce(T, string file = __FILE__, int line = __LINE__)
        (T value, scope void delegate() dg)
    {
        if (!value) dg();
        return value;
    }

    T _enforce(T)(T value, lazy Exception ex)
    {
        if (!value) throw ex();
        return value;
    }

    private void _bailOut(string file, int line, in char[] msg)
    {
        char[21] buf;
        throw new Exception(cast(string)(file ~ "(" ~ ulongToString(buf[], line) ~ "): " ~ (msg ? msg : "Enforcement failed")));
    }
}


/***************************************
 * Helper function used to see if two containers of different
 * types have the same contents in the same sequence.
 */

bool _ArrayEq(T1, T2)(T1[] a1, T2[] a2)
{
    if (a1.length != a2.length)
        return false;
    foreach(i, a; a1)
    {
        if (a != a2[i])
            return false;
    }
    return true;
}


bool _xopEquals(in void*, in void*)
{
    throw new Error("TypeInfo.equals is not implemented");
}

/******************************************
 * Create RTInfo for type T
 */

template RTInfo(T)
{
    enum RTInfo = null;
}
