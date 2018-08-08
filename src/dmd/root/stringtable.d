/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/stringtable.d, root/_stringtable.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_stringtable.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/stringtable.d
 */

module dmd.root.stringtable;

import core.stdc.string;
import dmd.root.rmem, dmd.root.hash;

enum POOL_BITS = 12;
enum POOL_SIZE = (1U << POOL_BITS);

private size_t nextpow2(size_t val) pure nothrow @nogc @safe
{
    size_t res = 1;
    while (res < val)
        res <<= 1;
    return res;
}

enum loadFactor = 0.8;

struct StringEntry
{
    uint hash;
    uint vptr;
}

// StringValue is a variable-length structure. It has neither proper c'tors nor a
// factory method because the only thing which should be creating these is StringTable.
struct StringValue
{
    void* ptrvalue;
    size_t length;

nothrow:
pure:
    extern (C++) char* lstring()
    {
        return cast(char*)(&this + 1);
    }

    extern (C++) size_t len() const
    {
        return length;
    }

    extern (C++) const(char)* toDchars() const
    {
        return cast(const(char)*)(&this + 1);
    }
}

struct StringTable
{
private:
    StringEntry* table;
    size_t tabledim;
    ubyte** pools;
    size_t npools;
    size_t nfill;
    size_t count;

public:
    extern (C++) void _init(size_t size = 0) nothrow
    {
        size = nextpow2(cast(size_t)(size / loadFactor));
        if (size < 32)
            size = 32;
        table = cast(StringEntry*)mem.xcalloc(size, (table[0]).sizeof);
        tabledim = size;
        pools = null;
        npools = nfill = 0;
        count = 0;
    }

    extern (C++) void reset(size_t size = 0) nothrow
    {
        for (size_t i = 0; i < npools; ++i)
            mem.xfree(pools[i]);
        mem.xfree(table);
        mem.xfree(pools);
        table = null;
        pools = null;
        _init(size);
    }

    extern (C++) ~this() nothrow
    {
        for (size_t i = 0; i < npools; ++i)
            mem.xfree(pools[i]);
        mem.xfree(table);
        mem.xfree(pools);
        table = null;
        pools = null;
    }

    /**
    Looks up the given string in the string table and returns its associated
    value.

    Params:
     s = the string to look up
     length = the length of $(D_PARAM s)
     str = the string to look up

    Returns: the string's associated value, or `null` if the string doesn't
     exist in the string table
    */
    extern (C++) inout(StringValue)* lookup(const(char)* s, size_t length) inout nothrow pure
    {
        const(hash_t) hash = calcHash(s, length);
        const(size_t) i = findSlot(hash, s, length);
        // printf("lookup %.*s %p\n", (int)length, s, table[i].value ?: NULL);
        return getValue(table[i].vptr);
    }

    /// ditto
    inout(StringValue)* lookup(const(char)[] str) inout nothrow pure
    {
        return lookup(str.ptr, str.length);
    }

    /**
    Inserts the given string and the given associated value into the string
    table.

    Params:
     s = the string to insert
     length = the length of $(D_PARAM s)
     ptrvalue = the value to associate with the inserted string
     str = the string to insert
     value = the value to associate with the inserted string

    Returns: the newly inserted value, or `null` if the string table already
     contains the string
    */
    extern (C++) StringValue* insert(const(char)* s, size_t length, void* ptrvalue) nothrow
    {
        const(hash_t) hash = calcHash(s, length);
        size_t i = findSlot(hash, s, length);
        if (table[i].vptr)
            return null; // already in table
        if (++count > tabledim * loadFactor)
        {
            grow();
            i = findSlot(hash, s, length);
        }
        table[i].hash = hash;
        table[i].vptr = allocValue(s, length, ptrvalue);
        // printf("insert %.*s %p\n", (int)length, s, table[i].value ?: NULL);
        return getValue(table[i].vptr);
    }

    /// ditto
    StringValue* insert(const(char)[] str, void* value) nothrow
    {
        return insert(str.ptr, str.length, value);
    }

    extern (C++) StringValue* update(const(char)* s, size_t length) nothrow
    {
        const(hash_t) hash = calcHash(s, length);
        size_t i = findSlot(hash, s, length);
        if (!table[i].vptr)
        {
            if (++count > tabledim * loadFactor)
            {
                grow();
                i = findSlot(hash, s, length);
            }
            table[i].hash = hash;
            table[i].vptr = allocValue(s, length, null);
        }
        // printf("update %.*s %p\n", (int)length, s, table[i].value ?: NULL);
        return getValue(table[i].vptr);
    }

    StringValue* update(const(char)[] name) nothrow
    {
        return update(name.ptr, name.length);
    }

    /********************************
     * Walk the contents of the string table,
     * calling fp for each entry.
     * Params:
     *      fp = function to call. Returns !=0 to stop
     * Returns:
     *      last return value of fp call
     */
    extern (C++) int apply(int function(const(StringValue)*) fp)
    {
        foreach (const se; table[0 .. tabledim])
        {
            if (!se.vptr)
                continue;
            const sv = getValue(se.vptr);
            int result = (*fp)(sv);
            if (result)
                return result;
        }
        return 0;
    }

private:
nothrow:
    uint allocValue(const(char)* s, size_t length, void* ptrvalue)
    {
        const(size_t) nbytes = StringValue.sizeof + length + 1;
        if (!npools || nfill + nbytes > POOL_SIZE)
        {
            pools = cast(ubyte**)mem.xrealloc(pools, ++npools * (pools[0]).sizeof);
            pools[npools - 1] = cast(ubyte*)mem.xmalloc(nbytes > POOL_SIZE ? nbytes : POOL_SIZE);
            nfill = 0;
        }
        StringValue* sv = cast(StringValue*)&pools[npools - 1][nfill];
        sv.ptrvalue = ptrvalue;
        sv.length = length;
        .memcpy(sv.lstring(), s, length);
        sv.lstring()[length] = 0;
        const(uint) vptr = cast(uint)(npools << POOL_BITS | nfill);
        nfill += nbytes + (-nbytes & 7); // align to 8 bytes
        return vptr;
    }

    inout(StringValue)* getValue(uint vptr) inout pure
    {
        if (!vptr)
            return null;
        const(size_t) idx = (vptr >> POOL_BITS) - 1;
        const(size_t) off = vptr & POOL_SIZE - 1;
        return cast(inout(StringValue)*)&pools[idx][off];
    }

    size_t findSlot(hash_t hash, const(char)* s, size_t length) const pure
    {
        // quadratic probing using triangular numbers
        // http://stackoverflow.com/questions/2348187/moving-from-linear-probing-to-quadratic-probing-hash-collisons/2349774#2349774
        for (size_t i = hash & (tabledim - 1), j = 1;; ++j)
        {
            const(StringValue)* sv;
            auto vptr = table[i].vptr;
            if (!vptr || table[i].hash == hash && (sv = getValue(vptr)).length == length && .memcmp(s, sv.toDchars(), length) == 0)
                return i;
            i = (i + j) & (tabledim - 1);
        }
    }

    void grow()
    {
        const odim = tabledim;
        auto otab = table;
        tabledim *= 2;
        table = cast(StringEntry*)mem.xcalloc(tabledim, (table[0]).sizeof);
        foreach (const se; otab[0 .. odim])
        {
            if (!se.vptr)
                continue;
            const sv = getValue(se.vptr);
            table[findSlot(se.hash, sv.toDchars(), sv.length)] = se;
        }
        mem.xfree(otab);
    }
}
