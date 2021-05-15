/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright), Dave Fladebo
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/aarray.d
 */

module dmd.backend.aarray;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

alias hash_t = size_t;

version (MARS)
    import dmd.root.hash;

nothrow:
@safe:

/*********************
 * This is the "bucket" used by the AArray.
 */
private struct aaA
{
    aaA *next;
    hash_t hash;        // hash of the key
    /* key   */         // key value goes here
    /* value */         // value value goes here
}

/**************************
 * Associative Array type.
 * Params:
 *      TKey = type that has members Key, getHash(), and equals()
 *      Value = value type
 */

struct AArray(TKey, Value)
{
nothrow:
    alias Key = TKey.Key;       // key type

    ~this()
    {
        destroy();
    }

    /****
     * Frees all the data used by AArray
     */
    @trusted
    void destroy()
    {
        if (buckets)
        {
            foreach (e; buckets)
            {
                while (e)
                {
                    auto en = e;
                    e = e.next;
                    free(en);
                }
            }
            free(buckets.ptr);
            buckets = null;
            nodes = 0;
        }
    }

    /********
     * Returns:
     *   Number of entries in the AArray
     */
    size_t length()
    {
        return nodes;
    }

    /*************************************************
     * Get pointer to value in associative array indexed by key.
     * Add entry for key if it is not already there.
     * Params:
     *  pKey = pointer to key
     * Returns:
     *  pointer to Value
     */
    @trusted
    Value* get(Key* pkey)
    {
        //printf("AArray::get()\n");
        const aligned_keysize = aligntsize(Key.sizeof);

        if (!buckets.length)
        {
            alias aaAp = aaA*;
            const len = prime_list[0];
            auto p = cast(aaAp*)calloc(len, aaAp.sizeof);
            assert(p);
            buckets = p[0 .. len];
        }

        hash_t key_hash = tkey.getHash(pkey);
        const i = key_hash % buckets.length;
        //printf("key_hash = %x, buckets.length = %d, i = %d\n", key_hash, buckets.length, i);
        aaA* e;
        auto pe = &buckets[i];
        while ((e = *pe) != null)
        {
            if (key_hash == e.hash &&
                tkey.equals(pkey, cast(Key*)(e + 1)))
            {
                goto Lret;
            }
            pe = &e.next;
        }

        // Not found, create new elem
        //printf("create new one\n");
        e = cast(aaA *) malloc(aaA.sizeof + aligned_keysize + Value.sizeof);
        assert(e);
        memcpy(e + 1, pkey, Key.sizeof);
        memset(cast(void *)(e + 1) + aligned_keysize, 0, Value.sizeof);
        e.hash = key_hash;
        e.next = null;
        *pe = e;

        ++nodes;
        //printf("length = %d, nodes = %d\n", buckets_length, nodes);
        if (nodes > buckets.length * 4)
        {
            //printf("rehash()\n");
            rehash();
        }

    Lret:
        return cast(Value*)(cast(void*)(e + 1) + aligned_keysize);
    }

    /*************************************************
     * Determine if key is in aa.
     * Params:
     *  pKey = pointer to key
     * Returns:
     *  null    not in aa
     *  !=null  in aa, return pointer to value
     */

    @trusted
    Value* isIn(Key* pkey)
    {
        //printf("AArray.isIn(), .length = %d, .ptr = %p\n", nodes, buckets.ptr);
        if (!nodes)
            return null;

        const key_hash = tkey.getHash(pkey);
        //printf("hash = %d\n", key_hash);
        const i = key_hash % buckets.length;
        auto e = buckets[i];
        while (e != null)
        {
            if (key_hash == e.hash &&
                tkey.equals(pkey, cast(Key*)(e + 1)))
            {
                return cast(Value*)(cast(void*)(e + 1) + aligntsize(Key.sizeof));
            }

            e = e.next;
        }

        // Not found
        return null;
    }


    /*************************************************
     * Delete key entry in aa[].
     * If key is not in aa[], do nothing.
     * Params:
     *  pKey = pointer to key
     */

    @trusted
    void del(Key *pkey)
    {
        if (!nodes)
            return;

        const key_hash = tkey.getHash(pkey);
        //printf("hash = %d\n", key_hash);
        const i = key_hash % buckets.length;
        auto pe = &buckets[i];
        aaA* e;
        while ((e = *pe) != null)       // null means not found
        {
            if (key_hash == e.hash &&
                tkey.equals(pkey, cast(Key*)(e + 1)))
            {
                *pe = e.next;
                --nodes;
                free(e);
                break;
            }
            pe = &e.next;
        }
    }


    /********************************************
     * Produce array of keys from aa.
     * Returns:
     *  malloc'd array of keys
     */

    @trusted
    Key[] keys()
    {
        if (!nodes)
            return null;

        auto p = cast(Key *)malloc(nodes * Key.sizeof);
        assert(p);
        auto q = p;
        foreach (e; buckets)
        {
            while (e)
            {
                memcpy(q, e + 1, Key.sizeof);
                ++q;
                e = e.next;
            }
        }
        return p[0 .. nodes];
    }

    /********************************************
     * Produce array of values from aa.
     * Returns:
     *  malloc'd array of values
     */

    @trusted
    Value[] values()
    {
        if (!nodes)
            return null;

        const aligned_keysize = aligntsize(Key.sizeof);
        auto p = cast(Value *)malloc(nodes * Value.sizeof);
        assert(p);
        auto q = p;
        foreach (e; buckets)
        {
            while (e)
            {
                memcpy(q, cast(void*)(e + 1) + aligned_keysize, Value.sizeof);
                ++q;
                e = e.next;
            }
        }
        return p[0 .. nodes];
    }

    /********************************************
     * Rehash an array.
     */

    @trusted
    void rehash()
    {
        //printf("Rehash\n");
        if (!nodes)
            return;

        size_t newbuckets_length = prime_list[$ - 1];

        foreach (prime; prime_list[0 .. $ - 1])
        {
            if (nodes <= prime)
            {
                newbuckets_length = prime;
                break;
            }
        }
        auto newbuckets = cast(aaA**)calloc(newbuckets_length, (aaA*).sizeof);
        assert(newbuckets);

        foreach (e; buckets)
        {
            while (e)
            {
                auto en = e.next;
                auto b = &newbuckets[e.hash % newbuckets_length];
                e.next = *b;
                *b = e;
                e = en;
            }
        }

        free(buckets.ptr);
        buckets = null;
        buckets = newbuckets[0 .. newbuckets_length];
    }

    alias applyDg = nothrow int delegate(Key*, Value*);
    /*********************************************
     * For each element in the AArray,
     * call dg(Key* pkey, Value* pvalue)
     * If dg returns !=0, stop and return that value.
     * Params:
     *  dg = delegate to call for each key/value pair
     * Returns:
     *  !=0 : value returned by first dg() call that returned non-zero
     *  0   : no entries in aa, or all dg() calls returned 0
     */

    @trusted
    int apply(applyDg dg)
    {
        if (!nodes)
            return 0;

        //printf("AArray.apply(aa = %p, keysize = %d, dg = %p)\n", &this, Key.sizeof, dg);

        const aligned_keysize = aligntsize(Key.sizeof);

        foreach (e; buckets)
        {
            while (e)
            {
                auto result = dg(cast(Key*)(e + 1), cast(Value*)(cast(void*)(e + 1) + aligned_keysize));
                if (result)
                    return result;
                e = e.next;
            }
        }

        return 0;
    }

  private:

    aaA*[] buckets;
    size_t nodes;               // number of nodes
    TKey tkey;
}

private:

/**********************************
 * Align to next pointer boundary, so value
 * will be aligned.
 * Params:
 *      tsize = offset to be aligned
 * Returns:
 *      aligned offset
 */

size_t aligntsize(size_t tsize)
{
    // Is pointer alignment on the x64 4 bytes or 8?
    return (tsize + size_t.sizeof - 1) & ~(size_t.sizeof - 1);
}

immutable uint[14] prime_list =
[
               97,           389,
             1543,          6151,
           24_593,        98_317,
          393_241,     1_572_869,
        6_291_469,    25_165_843,
      100_663_319,   402_653_189,
    1_610_612_741, 4_294_967_291U,
];

/***************************************************************/

/***
 * A TKey for basic types
 * Params:
 *      K = a basic type
 */
public struct Tinfo(K)
{
nothrow:
    alias Key = K;

    static hash_t getHash(Key* pk)
    {
        return cast(hash_t)*pk;
    }

    static bool equals(Key* pk1, Key* pk2)
    {
        return *pk1 == *pk2;
    }
}

/***************************************************************/

/****
 * A TKey that is a string
 */
public struct TinfoChars
{
nothrow:
    alias Key = const(char)[];

    static hash_t getHash(Key* pk)
    {
        version (MARS)
        {
            auto buf = *pk;
            return calcHash(cast(const(ubyte[]))buf);
        }
        else
        {
            auto buf = *pk;
            hash_t hash = 0;
            foreach (v; buf)
                hash = hash * 11 + v;
            return hash;
        }
    }

    @trusted
    static bool equals(Key* pk1, Key* pk2)
    {
        auto buf1 = *pk1;
        auto buf2 = *pk2;
        return buf1.length == buf2.length &&
               memcmp(buf1.ptr, buf2.ptr, buf1.length) == 0;
    }
}

// Interface for C++ code
public extern (C++) struct AAchars
{
nothrow:
    alias AA = AArray!(TinfoChars, uint);
    AA aa;

    @trusted
    static AAchars* create()
    {
        auto a = cast(AAchars*)calloc(1, AAchars.sizeof);
        assert(a);
        return a;
    }

    @trusted
    static void destroy(AAchars* aac)
    {
        aac.aa.destroy();
        free(aac);
    }

    @trusted
    extern(D) uint* get(const(char)[] buf)
    {
        return aa.get(&buf);
    }

    uint length()
    {
        return cast(uint)aa.length();
    }
}

/***************************************************************/

// Key is the slice specified by (*TinfoPair.pbase)[Pair.start .. Pair.end]

public struct Pair { uint start, end; }

public struct TinfoPair
{
nothrow:
    alias Key = Pair;

    ubyte** pbase;

    @trusted
    hash_t getHash(Key* pk)
    {
        version (MARS)
        {
            auto buf = (*pbase)[pk.start .. pk.end];
            return calcHash(buf);
        }
        else
        {
            auto buf = (*pbase)[pk.start .. pk.end];
            hash_t hash = 0;
            foreach (v; buf)
                hash = hash * 11 + v;
            return hash;
        }
    }

    @trusted
    bool equals(Key* pk1, Key* pk2)
    {
        const len1 = pk1.end - pk1.start;
        const len2 = pk2.end - pk2.start;

        auto buf1 = *pk1;
        auto buf2 = *pk2;
        return len1 == len2 &&
               memcmp(*pbase + pk1.start, *pbase + pk2.start, len1) == 0;
    }
}

// Interface for C++ code
public extern (C++) struct AApair
{
nothrow:
    alias AA = AArray!(TinfoPair, uint);
    AA aa;

    @trusted
    static AApair* create(ubyte** pbase)
    {
        auto a = cast(AApair*)calloc(1, AApair.sizeof);
        assert(a);
        a.aa.tkey.pbase = pbase;
        return a;
    }

    @trusted
    static void destroy(AApair* aap)
    {
        aap.aa.destroy();
        free(aap);
    }

    @trusted
    uint* get(uint start, uint end)
    {
        auto p = Pair(start, end);
        return aa.get(&p);
    }

    uint length()
    {
        return cast(uint)aa.length();
    }
}

// Interface for C++ code
public extern (C++) struct AApair2
{
nothrow:
    alias AA = AArray!(TinfoPair, Pair);
    AA aa;

    @trusted
    static AApair2* create(ubyte** pbase)
    {
        auto a = cast(AApair2*)calloc(1, AApair2.sizeof);
        assert(a);
        a.aa.tkey.pbase = pbase;
        return a;
    }

    @trusted
    static void destroy(AApair2* aap)
    {
        aap.aa.destroy();
        free(aap);
    }

    @trusted
    Pair* get(uint start, uint end)
    {
        auto p = Pair(start, end);
        return aa.get(&p);
    }

    uint length()
    {
        return cast(uint)aa.length();
    }
}

/*************************************************************/

@system unittest
{
    int dg(int* pk, bool* pv) { return 3; }
    int dgz(int* pk, bool* pv) { return 0; }

    AArray!(Tinfo!int, bool) aa;
    aa.rehash();
    assert(aa.keys() == null);
    assert(aa.values() == null);
    assert(aa.apply(&dg) == 0);

    assert(aa.length == 0);
    int k = 8;
    aa.del(&k);
    bool v = true;
    assert(!aa.isIn(&k));
    bool *pv = aa.get(&k);
    *pv = true;
    int j = 9;
    pv = aa.get(&j);
    *pv = false;
    aa.rehash();

    assert(aa.length() == 2);
    assert(*aa.get(&k) == true);
    assert(*aa.get(&j) == false);

    assert(aa.apply(&dg) == 3);
    assert(aa.apply(&dgz) == 0);

    aa.del(&k);
    assert(aa.length() == 1);
    assert(!aa.isIn(&k));
    assert(*aa.isIn(&j) == false);

    auto keys = aa.keys();
    assert(keys.length == 1);
    assert(keys[0] == 9);

    auto values = aa.values();
    assert(values.length == 1);
    assert(values[0] == false);

    AArray!(Tinfo!int, bool) aa2;
    int key = 10;
    bool* getpv = aa2.get(&key);
    aa2.apply(delegate(int* pk, bool* pv) @trusted {
        assert(pv is getpv);
        return 0;
    });
}

@system unittest
{
    const(char)* buf = "abcb";
    auto aap = AApair.create(cast(ubyte**)&buf);
    auto pu = aap.get(1,2);
    *pu = 10;
    assert(aap.length == 1);
    pu = aap.get(3,4);
    assert(*pu == 10);
    AApair.destroy(aap);
}
