/**
 * Associative array implementation.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/root/aav.d, root/_aav.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_aav.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/root/aav.d
 */

module dmd.root.aav;

import core.stdc.string;
import dmd.root.rmem;

nothrow:

private size_t hash(size_t a) pure nothrow @nogc @safe
{
    a ^= (a >> 20) ^ (a >> 12);
    return a ^ (a >> 7) ^ (a >> 4);
}

private struct KeyValueTemplate(K,V)
{
    K key;
    V value;
}

alias Key = void*;
alias Value = void*;

alias KeyValue = KeyValueTemplate!(Key, Value);

private enum KEY_EMPTY = cast(Key)~cast(size_t)0; // support null as key
// deletion not supported

private struct AA
{
private:
    size_t nodes; // total number of aaA nodes
    union
    {
        KeyValue binit; // modes <= 1: most AAs have only one entry
        KeyValue[] b;
    }
}

/****************************************************
 * Determine number of entries in associative array.
 */
private size_t dmd_aaLen(const AA* aa) pure nothrow @nogc @safe
{
    return aa ? aa.nodes : 0;
}

/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there, returning a pointer to a null Value.
 * Create the associative array if it does not already exist.
 */
private Value* dmd_aaGet(AA** paa, Key key) pure nothrow
{
    //printf("paa = %p\n", paa);
    assert(key != KEY_EMPTY);
    auto aa = *paa;
    if (!aa)
    {
        *paa = aa = cast(AA*)mem.xmalloc(AA.sizeof);
        aa.nodes = 1;
        aa.binit.key = key;
        aa.binit.value = null;
        return &aa.binit.value;
    }
    //printf("paa = %p, *paa = %p\n", paa, *paa);
    assert(aa.nodes);
    if (aa.nodes == 1)
    {
        if (key == aa.binit.key)
            return &aa.binit.value;
        aa.b = dmd_aaRehash((&aa.binit)[0..1]);
    }
    else if (aa.nodes * 2 > aa.b.length)
        aa.b = dmd_aaRehash(aa.b[]);

    size_t mask = aa.b.length - 1;
    size_t i = hash(cast(size_t)key) & mask;
    for (size_t j = 1;; i = (i + j) & mask, j++)
    {
        auto bkey = aa.b[i].key;
        if (key == bkey)
            return &aa.b[i].value;
        else if (bkey == KEY_EMPTY)
            break;
    }
    // Not found, create new elem
    //printf("create new one\n");
    ++aa.nodes;
    aa.b[i].key = key;
    return &aa.b[i].value;
}

/*************************************************
 * Get value in associative array indexed by key.
 * Returns NULL if it is not already there.
 */
private Value dmd_aaGetRvalue(AA* aa, Key key) pure nothrow @nogc
{
    //printf("_aaGetRvalue(key = %p)\n", key);
    assert(key != KEY_EMPTY);
    if (!aa)
        return null;
    if (aa.nodes == 1)
        return key == aa.binit.key ? aa.binit.value : null;

    size_t mask = aa.b.length - 1;
    size_t i = hash(cast(size_t)key) & mask;
    for (size_t j = 1;; i = (i + j) & mask, j++)
    {
        auto bkey = aa.b[i].key;
        if (key == bkey)
            return aa.b[i].value;
        else if (bkey == KEY_EMPTY)
            return null;
    }
}

/**
Gets a range of key/values for `aa`.

Returns: a range of key/values for `aa`.
*/
@property auto asRange(AA* aa) pure nothrow @nogc
{
    return AARange!(Key, Value)(aa);
}

private struct AARange(K,V)
{
    AA* aa;
    // current index into bucket array `aa.b`
    size_t bIndex;

    this(AA* aa_) pure nothrow @nogc scope
    {
        aa = aa_;
        toNext();
    }

    @property bool empty() const pure nothrow @nogc @safe
    {
        return bIndex >= buckets().length;
    }

    @property auto front() const pure nothrow @nogc
    {
        return cast(KeyValueTemplate!(K, V))(buckets()[bIndex]);
    }

    void popFront() pure nothrow @nogc
    {
        bIndex++;
        toNext();
    }

    private const(KeyValue[]) buckets() const pure nothrow @nogc @trusted
    {
        return !aa ? null : aa.nodes == 1 ? (&aa.binit)[0..1] : aa.b;
    }

    private void toNext() pure nothrow @nogc
    {
        auto b = buckets();
        while (bIndex < b.length && b[bIndex].key == KEY_EMPTY)
            bIndex++;
    }
}

unittest
{
    AA* aa = null;
    foreach(keyValue; aa.asRange)
        assert(0);

    enum totalKeyLength = 50;
    foreach (i; 1 .. totalKeyLength + 1)
    {
        auto key = cast(void*)i;
        {
            auto valuePtr = dmd_aaGet(&aa, key);
            assert(valuePtr);
            *valuePtr = key;
        }
        bool[totalKeyLength] found;
        size_t rangeCount = 0;
        foreach (keyValue; aa.asRange)
        {
            assert(keyValue.key <= key);
            assert(keyValue.key == keyValue.value);
            rangeCount++;
            assert(!found[cast(size_t)keyValue.key - 1]);
            found[cast(size_t)keyValue.key - 1] = true;
        }
        assert(rangeCount == i);
    }
}

/********************************************
 * Rehash an array.
 */
private KeyValue[] dmd_aaRehash(KeyValue[] b) pure nothrow
{
    //printf("Rehash\n");
    size_t len = b.length * 4;
    auto newb = cast(KeyValue*)mem.xmalloc(KeyValue.sizeof * len);
    newb[0..len] = KeyValue(KEY_EMPTY, null);
    size_t mask = len - 1;
    for (size_t k = 0; k < b.length; k++)
    {
        auto key = b[k].key;
        if (key != KEY_EMPTY)
        {
            size_t i = hash(cast(size_t)key) & mask;
            for (size_t j = 1;; i = (i + j) & mask, j++)
            {
                if (newb[i].key == KEY_EMPTY)
                {
                    newb[i] = b[k];
                    break;
                }
            }
        }
    }
    if (b.length > 1)
        mem.xfree(b.ptr, KeyValue.sizeof * b.length);
    return newb[0..len];
}

unittest
{
    AA* aa = null;
    Value v = dmd_aaGetRvalue(aa, null);
    assert(!v);
    Value* pv = dmd_aaGet(&aa, null);
    assert(pv);
    *pv = cast(void*)3;
    v = dmd_aaGetRvalue(aa, null);
    assert(v == cast(void*)3);
}

struct AssocArray(K,V)
{
    private AA* aa;

    /**
    Returns: The number of key/value pairs.
    */
    @property size_t length() const pure nothrow @nogc @safe
    {
        return dmd_aaLen(aa);
    }

    /**
    Lookup value associated with `key` and return the address to it. If the `key`
    has not been added, it adds it and returns the address to the new value.

    Params:
        key = key to lookup the value for

    Returns: the address to the value associated with `key`. If `key` does not exist, it
             is added and the address to the new value is returned.
    */
    V* getLvalue(const(K) key) pure nothrow
    {
        return cast(V*)dmd_aaGet(&aa, cast(void*)key);
    }

    /**
    Lookup and return the value associated with `key`, if the `key` has not been
    added, it returns null.

    Params:
        key = key to lookup the value for

    Returns: the value associated with `key` if present, otherwise, null.
    */
    V opIndex(const(K) key) pure nothrow @nogc
    {
        return cast(V)dmd_aaGetRvalue(aa, cast(void*)key);
    }

    /**
    Gets a range of key/values for `aa`.

    Returns: a range of key/values for `aa`.
    */
    @property auto asRange() pure nothrow @nogc
    {
        return AARange!(K,V)(aa);
    }
}

///
unittest
{
    auto foo = new Object();
    auto bar = new Object();

    AssocArray!(Object, Object) aa;

    assert(aa[foo] is null);
    assert(aa.length == 0);

    auto fooValuePtr = aa.getLvalue(foo);
    *fooValuePtr = bar;

    assert(aa[foo] is bar);
    assert(aa.length == 1);
}
