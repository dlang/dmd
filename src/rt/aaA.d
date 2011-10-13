/**
 * Implementation of associative arrays.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.aaA;

private
{
    import core.stdc.stdarg;
    import core.stdc.string;
    import core.stdc.stdio;

    enum BlkAttr : uint
    {
        FINALIZE    = 0b0000_0001,
        NO_SCAN     = 0b0000_0010,
        NO_MOVE     = 0b0000_0100,
        APPENDABLE  = 0b0000_1000,
        NO_INTERIOR = 0b0001_0000,
        ALL_BITS    = 0b1111_1111
    }

    extern (C) void* gc_malloc( size_t sz, uint ba = 0 );
    extern (C) void  gc_free( void* p );
    
    // Convenience function to make sure the NO_INTERIOR gets set on the
    // aaA arrays.
    aaA*[] newaaA(size_t len) 
    {
        auto ptr = cast(aaA**) gc_malloc(
            len * (aaA*).sizeof, BlkAttr.NO_INTERIOR);
        auto ret = ptr[0..len];
        ret[] = null;
        return ret;
    }
}

// Auto-rehash and pre-allocate - Dave Fladebo

static immutable size_t[] prime_list = [
              31UL,
              97UL,            389UL,
           1_543UL,          6_151UL,
          24_593UL,         98_317UL,
          393_241UL,      1_572_869UL,
        6_291_469UL,     25_165_843UL,
      100_663_319UL,    402_653_189UL,
    1_610_612_741UL,  4_294_967_291UL,
//  8_589_934_513UL, 17_179_869_143UL
];

/* This is the type of the return value for dynamic arrays.
 * It should be a type that is returned in registers.
 * Although DMD will return types of Array in registers,
 * gcc will not, so we instead use a 'long'.
 */
alias void[] ArrayRet_t;

struct Array
{
    size_t length;
    void* ptr;
}

struct aaA
{
    aaA *next;
    hash_t hash;
    /* key   */
    /* value */
}

struct BB
{
    aaA*[] b;
    size_t nodes;       // total number of aaA nodes
    TypeInfo keyti;     // TODO: replace this with TypeInfo_AssociativeArray when available in _aaGet()
    aaA*[4] binit;      // initial value of b[]
}

/* This is the type actually seen by the programmer, although
 * it is completely opaque.
 */

struct AA
{
    BB* a;
}

/**********************************
 * Align to next pointer boundary, so that
 * GC won't be faced with misaligned pointers
 * in value.
 */

size_t aligntsize(size_t tsize)
{
    version (X86_64)
        // Size of key needed to align value on 16 bytes
        return (tsize + 15) & ~(15);
    else
        return (tsize + size_t.sizeof - 1) & ~(size_t.sizeof - 1);
}

extern (C):

/*************************************************
 * Invariant for aa.
 */

/+
void _aaInvAh(aaA*[] aa)
{
    for (size_t i = 0; i < aa.length; i++)
    {
        if (aa[i])
            _aaInvAh_x(aa[i]);
    }
}

private int _aaCmpAh_x(aaA *e1, aaA *e2)
{   int c;

    c = e1.hash - e2.hash;
    if (c == 0)
    {
        c = e1.key.length - e2.key.length;
        if (c == 0)
            c = memcmp((char *)e1.key, (char *)e2.key, e1.key.length);
    }
    return c;
}

private void _aaInvAh_x(aaA *e)
{
    hash_t key_hash;
    aaA *e1;
    aaA *e2;

    key_hash = getHash(e.key);
    assert(key_hash == e.hash);

    while (1)
    {   int c;

        e1 = e.left;
        if (e1)
        {
            _aaInvAh_x(e1);             // ordinary recursion
            do
            {
                c = _aaCmpAh_x(e1, e);
                assert(c < 0);
                e1 = e1.right;
            } while (e1 != null);
        }

        e2 = e.right;
        if (e2)
        {
            do
            {
                c = _aaCmpAh_x(e, e2);
                assert(c < 0);
                e2 = e2.left;
            } while (e2 != null);
            e = e.right;                // tail recursion
        }
        else
            break;
    }
}
+/

/****************************************************
 * Determine number of entries in associative array.
 */

size_t _aaLen(AA aa)
in
{
    //printf("_aaLen()+\n");
    //_aaInv(aa);
}
out (result)
{
    size_t len = 0;

    if (aa.a)
    {
        foreach (e; aa.a.b)
        {
            while (e)
            {   len++;
                e = e.next;
            }
        }
    }
    assert(len == result);

    //printf("_aaLen()-\n");
}
body
{
    return aa.a ? aa.a.nodes : 0;
}


/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there.
 */

// retained for backwards compatibility
void* _aaGet(AA* aa, TypeInfo keyti, size_t valuesize, ...)
{
    return _aaGetX(aa, keyti, valuesize, cast(void*)(&valuesize + 1));
}

void* _aaGetX(AA* aa, TypeInfo keyti, size_t valuesize, void* pkey)
in
{
    assert(aa);
}
out (result)
{
    assert(result);
    assert(aa.a);
    assert(aa.a.b.length);
    //assert(_aaInAh(*aa.a, key));
}
body
{
    size_t i;
    aaA *e;
    //printf("keyti = %p\n", keyti);
    //printf("aa = %p\n", aa);
    immutable keytitsize = keyti.tsize();

    if (!aa.a)
    {   aa.a = new BB();
        aa.a.b = aa.a.binit;
    }
    //printf("aa = %p\n", aa);
    //printf("aa.a = %p\n", aa.a);
    aa.a.keyti = keyti;

    auto key_hash = keyti.getHash(pkey);
    //printf("hash = %d\n", key_hash);
    i = key_hash % aa.a.b.length;
    auto pe = &aa.a.b[i];
    while ((e = *pe) !is null)
    {
        if (key_hash == e.hash)
        {
            auto c = keyti.compare(pkey, e + 1);
            if (c == 0)
                goto Lret;
        }
        pe = &e.next;
    }

    // Not found, create new elem
    //printf("create new one\n");
    size_t size = aaA.sizeof + aligntsize(keytitsize) + valuesize;
    e = cast(aaA *) gc_malloc(size);
    e.next = null;
    e.hash = key_hash;
    ubyte* ptail = cast(ubyte*)(e + 1);
    memcpy(ptail, pkey, keytitsize);
    memset(ptail + aligntsize(keytitsize), 0, valuesize); // zero value
    *pe = e;

    auto nodes = ++aa.a.nodes;
    //printf("length = %d, nodes = %d\n", aa.a.b.length, nodes);
    if (nodes > aa.a.b.length * 4)
    {
        //printf("rehash\n");
        _aaRehash(aa,keyti);
    }

Lret:
    return cast(void *)(e + 1) + aligntsize(keytitsize);
}


/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Returns null if it is not already there.
 */

void* _aaGetRvalue(AA aa, TypeInfo keyti, size_t valuesize, ...)
{
    return _aaGetRvalueX(aa, keyti, valuesize, cast(void*)(&valuesize + 1));
}

void* _aaGetRvalueX(AA aa, TypeInfo keyti, size_t valuesize, void* pkey)
{
    //printf("_aaGetRvalue(valuesize = %u)\n", valuesize);
    if (!aa.a)
        return null;

    auto keysize = aligntsize(keyti.tsize());
    auto len = aa.a.b.length;

    if (len)
    {
        auto key_hash = keyti.getHash(pkey);
        //printf("hash = %d\n", key_hash);
        size_t i = key_hash % len;
        auto e = aa.a.b[i];
        while (e !is null)
        {
            if (key_hash == e.hash)
            {
                auto c = keyti.compare(pkey, e + 1);
                if (c == 0)
                    return cast(void *)(e + 1) + keysize;
            }
            e = e.next;
        }
    }
    return null;    // not found, caller will throw exception
}


/*************************************************
 * Determine if key is in aa.
 * Returns:
 *      null    not in aa
 *      !=null  in aa, return pointer to value
 */

void* _aaIn(AA aa, TypeInfo keyti, ...)
{
    return _aaInX(aa, keyti, cast(void*)(&keyti + 1));
}

void* _aaInX(AA aa, TypeInfo keyti, void* pkey)
in
{
}
out (result)
{
    //assert(result == 0 || result == 1);
}
body
{
    if (aa.a)
    {
        //printf("_aaIn(), .length = %d, .ptr = %x\n", aa.a.length, cast(uint)aa.a.ptr);
        auto len = aa.a.b.length;

        if (len)
        {
            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            const i = key_hash % len;
            auto e = aa.a.b[i];
            while (e !is null)
            {
                if (key_hash == e.hash)
                {
                    auto c = keyti.compare(pkey, e + 1);
                    if (c == 0)
                        return cast(void *)(e + 1) + aligntsize(keyti.tsize());
                }
                e = e.next;
            }
        }
    }

    // Not found
    return null;
}

/*************************************************
 * Delete key entry in aa[].
 * If key is not in aa[], do nothing.
 */

void _aaDel(AA aa, TypeInfo keyti, ...)
{
    return _aaDelX(aa, keyti, cast(void*)(&keyti + 1));
}

void _aaDelX(AA aa, TypeInfo keyti, void* pkey)
{
    aaA *e;

    if (aa.a && aa.a.b.length)
    {
        auto key_hash = keyti.getHash(pkey);
        //printf("hash = %d\n", key_hash);
        size_t i = key_hash % aa.a.b.length;
        auto pe = &aa.a.b[i];
        while ((e = *pe) !is null) // null means not found
        {
            if (key_hash == e.hash)
            {
                auto c = keyti.compare(pkey, e + 1);
                if (c == 0)
                {
                    *pe = e.next;
                    aa.a.nodes--;
                    gc_free(e);
                    break;
                }
            }
            pe = &e.next;
        }
    }
}


/********************************************
 * Produce array of values from aa.
 */

ArrayRet_t _aaValues(AA aa, size_t keysize, size_t valuesize)
{
    size_t resi;
    Array a;

    auto alignsize = aligntsize(keysize);

    if (aa.a)
    {
        a.length = _aaLen(aa);
        a.ptr = cast(byte*) gc_malloc(a.length * valuesize,
                                      valuesize < (void*).sizeof ? BlkAttr.NO_SCAN : 0);
        resi = 0;
        foreach (e; aa.a.b)
        {
            while (e)
            {
                memcpy(a.ptr + resi * valuesize,
                       cast(byte*)e + aaA.sizeof + alignsize,
                       valuesize);
                resi++;
                e = e.next;
            }
        }
        assert(resi == a.length);
    }
    return *cast(ArrayRet_t*)(&a);
}


/********************************************
 * Rehash an array.
 */

void* _aaRehash(AA* paa, TypeInfo keyti)
in
{
    //_aaInvAh(paa);
}
out (result)
{
    //_aaInvAh(result);
}
body
{
    //printf("Rehash\n");
    if (paa.a)
    {
        BB newb;
        auto aa = paa.a;
        auto len = _aaLen(*paa);
        if (len)
        {   size_t i;

            for (i = 0; i < prime_list.length - 1; i++)
            {
                if (len <= prime_list[i])
                    break;
            }
            len = prime_list[i];
            newb.b = newaaA(len);

            foreach (e; aa.b)
            {
                while (e)
                {   auto enext = e.next;
                    const j = e.hash % len;
                    e.next = newb.b[j];
                    newb.b[j] = e;
                    e = enext;
                }
            }
            if (aa.b.ptr == aa.binit.ptr)
                aa.binit[] = null;
            else
                delete aa.b;

            newb.nodes = aa.nodes;
            newb.keyti = aa.keyti;
        }

        *paa.a = newb;
    }
    return (*paa).a;
}

/********************************************
 * Produce array of N byte keys from aa.
 */

ArrayRet_t _aaKeys(AA aa, size_t keysize)
{
    auto len = _aaLen(aa);
    if (!len)
        return null;
    auto res = (cast(byte*) gc_malloc(len * keysize,
                                 !(aa.a.keyti.flags() & 1) ? BlkAttr.NO_SCAN : 0))[0 .. len * keysize];
    size_t resi = 0;
    foreach (e; aa.a.b)
    {
        while (e)
        {
            memcpy(&res[resi * keysize], cast(byte*)(e + 1), keysize);
            resi++;
            e = e.next;
        }
    }
    assert(resi == len);

    Array a;
    a.length = len;
    a.ptr = res.ptr;
    return *cast(ArrayRet_t*)(&a);
}

unittest
{
    int[string] aa;

    aa["hello"] = 3;
    assert(aa["hello"] == 3);
    aa["hello"]++;
    assert(aa["hello"] == 4);

    assert(aa.length == 1);

    string[] keys = aa.keys;
    assert(keys.length == 1);
    assert(memcmp(keys[0].ptr, cast(char*)"hello", 5) == 0);

    int[] values = aa.values;
    assert(values.length == 1);
    assert(values[0] == 4);

    aa.rehash;
    assert(aa.length == 1);
    assert(aa["hello"] == 4);

    aa["foo"] = 1;
    aa["bar"] = 2;
    aa["batz"] = 3;

    assert(aa.keys.length == 4);
    assert(aa.values.length == 4);

    foreach(a; aa.keys)
    {
        assert(a.length != 0);
        assert(a.ptr != null);
        //printf("key: %.*s -> value: %d\n", a.length, a.ptr, aa[a]);
    }

    foreach(v; aa.values)
    {
        assert(v != 0);
        //printf("value: %d\n", v);
    }
}


/**********************************************
 * 'apply' for associative arrays - to support foreach
 */

// dg is D, but _aaApply() is C
extern (D) alias int delegate(void *) dg_t;

int _aaApply(AA aa, size_t keysize, dg_t dg)
{   int result;

    //printf("_aaApply(aa = x%llx, keysize = %d, dg = x%llx)\n", aa.a, keysize, dg);

    auto alignsize = aligntsize(keysize);

    if (aa.a)
    {
    Loop:
        foreach (e; aa.a.b)
        {
            while (e)
            {
                result = dg(cast(void *)(e + 1) + alignsize);
                if (result)
                    break Loop;
                e = e.next;
            }
        }
    }
    return result;
}

// dg is D, but _aaApply2() is C
extern (D) alias int delegate(void *, void *) dg2_t;

int _aaApply2(AA aa, size_t keysize, dg2_t dg)
{   int result;

    //printf("_aaApply(aa = x%llx, keysize = %d, dg = x%llx)\n", aa.a, keysize, dg);

    auto alignsize = aligntsize(keysize);

    if (aa.a)
    {
    Loop:
        foreach (e; aa.a.b)
        {
            while (e)
            {
                result = dg(cast(void *)(e + 1), cast(void *)(e + 1) + alignsize);
                if (result)
                    break Loop;
                e = e.next;
            }
        }
    }
    return result;
}


/***********************************
 * Construct an associative array of type ti from
 * length pairs of key/value pairs.
 */

extern (C)
BB* _d_assocarrayliteralT(TypeInfo_AssociativeArray ti, size_t length, ...)
{
    auto valuesize = ti.next.tsize();           // value size
    auto keyti = ti.key;
    auto keysize = keyti.tsize();               // key size
    BB* result;

    //printf("_d_assocarrayliteralT(keysize = %d, valuesize = %d, length = %d)\n", keysize, valuesize, length);
    //printf("tivalue = %.*s\n", ti.next.classinfo.name);
    if (length == 0 || valuesize == 0 || keysize == 0)
    {
        ;
    }
    else
    {
        va_list q;
        version(X86_64) va_start(q, __va_argsave); else va_start(q, length);

        result = new BB();
        result.keyti = keyti;
        size_t i;

        for (i = 0; i < prime_list.length - 1; i++)
        {
            if (length <= prime_list[i])
                break;
        }
        auto len = prime_list[i];
        result.b = newaaA(len);

        size_t keystacksize   = (keysize   + int.sizeof - 1) & ~(int.sizeof - 1);
        size_t valuestacksize = (valuesize + int.sizeof - 1) & ~(int.sizeof - 1);

        size_t keytsize = aligntsize(keysize);

        for (size_t j = 0; j < length; j++)
        {   void* pkey = q;
            q += keystacksize;
            void* pvalue = q;
            q += valuestacksize;
            aaA* e;

            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            i = key_hash % len;
            auto pe = &result.b[i];
            while (1)
            {
                e = *pe;
                if (!e)
                {
                    // Not found, create new elem
                    //printf("create new one\n");
                    e = cast(aaA *) cast(void*) new void[aaA.sizeof + keytsize + valuesize];
                    memcpy(e + 1, pkey, keysize);
                    e.hash = key_hash;
                    *pe = e;
                    result.nodes++;
                    break;
                }
                if (key_hash == e.hash)
                {
                    auto c = keyti.compare(pkey, e + 1);
                    if (c == 0)
                        break;
                }
                pe = &e.next;
            }
            memcpy(cast(void *)(e + 1) + keytsize, pvalue, valuesize);
        }

        va_end(q);
    }
    return result;
}

extern (C)
BB* _d_assocarrayliteralTX(TypeInfo_AssociativeArray ti, void[] keys, void[] values)
{
    auto valuesize = ti.next.tsize();           // value size
    auto keyti = ti.key;
    auto keysize = keyti.tsize();               // key size
    auto length = keys.length;
    BB* result;

    //printf("_d_assocarrayliteralT(keysize = %d, valuesize = %d, length = %d)\n", keysize, valuesize, length);
    //printf("tivalue = %.*s\n", ti.next.classinfo.name);
    assert(length == values.length);
    if (length == 0 || valuesize == 0 || keysize == 0)
    {
        ;
    }
    else
    {
        result = new BB();
        result.keyti = keyti;

        size_t i;
        for (i = 0; i < prime_list.length - 1; i++)
        {
            if (length <= prime_list[i])
                break;
        }
        auto len = prime_list[i];
        result.b = newaaA(len);

        size_t keytsize = aligntsize(keysize);

        for (size_t j = 0; j < length; j++)
        {   auto pkey = keys.ptr + j * keysize;
            auto pvalue = values.ptr + j * valuesize;
            aaA* e;

            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            i = key_hash % len;
            auto pe = &result.b[i];
            while (1)
            {
                e = *pe;
                if (!e)
                {
                    // Not found, create new elem
                    //printf("create new one\n");
                    e = cast(aaA *) cast(void*) new void[aaA.sizeof + keytsize + valuesize];
                    memcpy(e + 1, pkey, keysize);
                    e.hash = key_hash;
                    *pe = e;
                    result.nodes++;
                    break;
                }
                if (key_hash == e.hash)
                {
                    auto c = keyti.compare(pkey, e + 1);
                    if (c == 0)
                        break;
                }
                pe = &e.next;
            }
            memcpy(cast(void *)(e + 1) + keytsize, pvalue, valuesize);
        }
    }
    return result;
}


/***********************************
 * Compare AA contents for equality.
 * Returns:
 *      1       equal
 *      0       not equal
 */
int _aaEqual(TypeInfo tiRaw, AA e1, AA e2)
{
    //printf("_aaEqual()\n");
    //printf("keyti = %.*s\n", ti.key.classinfo.name);
    //printf("valueti = %.*s\n", ti.next.classinfo.name);

    if (e1.a is e2.a)
        return 1;

    size_t len = _aaLen(e1);
    if (len != _aaLen(e2))
        return 0;

    // Check for Bug 5925. ti_raw could be a TypeInfo_Const, we need to unwrap
    //   it until reaching a real TypeInfo_AssociativeArray.
    TypeInfo_AssociativeArray ti;
    while (true)
    {
        if ((ti = cast(TypeInfo_AssociativeArray)tiRaw) !is null)
            break;
        else if (auto tiConst = cast(TypeInfo_Const)tiRaw) {
            // The member in object_.d and object.di differ. This is to ensure
            //  the file can be compiled both independently in unittest and
            //  collectively in generating the library. Fixing object.di
            //  requires changes to std.format in Phobos, fixing object_.d
            //  makes Phobos's unittest fail, so this hack is employed here to
            //  avoid irrelevant changes.
            static if (is(typeof(&tiConst.base) == TypeInfo*))
                tiRaw = tiConst.base;
            else
                tiRaw = tiConst.next;
        } else
            assert(0);  // ???
    }

    /* Algorithm: Visit each key/value pair in e1. If that key doesn't exist
     * in e2, or if the value in e1 doesn't match the one in e2, the arrays
     * are not equal, and exit early.
     * After all pairs are checked, the arrays must be equal.
     */

    auto keyti = ti.key;
    auto valueti = ti.next;
    const keysize = aligntsize(keyti.tsize());
    const len2 = e2.a.b.length;

    int _aaKeys_x(aaA* e)
    {
        do
        {
            auto pkey = cast(void*)(e + 1);
            auto pvalue = pkey + keysize;
            //printf("key = %d, value = %g\n", *cast(int*)pkey, *cast(double*)pvalue);

            // We have key/value for e1. See if they exist in e2

            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            const i = key_hash % len2;
            auto f = e2.a.b[i];
            while (1)
            {
                //printf("f is %p\n", f);
                if (f is null)
                    return 0;                   // key not found, so AA's are not equal
                if (key_hash == f.hash)
                {
                    //printf("hash equals\n");
                    auto c = keyti.compare(pkey, f + 1);
                    if (c == 0)
                    {   // Found key in e2. Compare values
                        //printf("key equals\n");
                        auto pvalue2 = cast(void *)(f + 1) + keysize;
                        if (valueti.equals(pvalue, pvalue2))
                        {
                            //printf("value equals\n");
                            break;
                        }
                        else
                            return 0;           // values don't match, so AA's are not equal
                    }
                }
                f = f.next;
            }

            // Look at next entry in e1
            e = e.next;
        } while (e !is null);
        return 1;                       // this subtree matches
    }

    foreach (e; e1.a.b)
    {
        if (e)
        {   if (_aaKeys_x(e) == 0)
                return 0;
        }
    }

    return 1;           // equal
}
