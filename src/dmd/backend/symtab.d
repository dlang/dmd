/**
 * Symbol table array.
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/symtab.d, backend/_symtab.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_symtab.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/symtab.d
 */

module dmd.backend.symtab;

import core.stdc.stdio;
import core.stdc.stdlib;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.mem;


extern (C++):

nothrow:
@safe:

alias SYMIDX = size_t;    // symbol table index

alias MEM_PH_MALLOC = mem_malloc;
alias MEM_PH_CALLOC = mem_calloc;
alias MEM_PH_FREE = mem_free;
alias MEM_PH_FREEFP = mem_freefp;
alias MEM_PH_STRDUP = mem_strdup;
alias MEM_PH_REALLOC = mem_realloc;

void stackoffsets(ref symtab_t, bool);

private void err_nomem();

struct symtab_t
{
  nothrow:
    alias T = Symbol*;
    alias capacity = symmax;

    /**********************
     * Set useable length of array.
     * Params:
     *  length = minimum number of elements in array
     */
    void setLength(size_t length)
    {
        @trusted
        static void enlarge(ref symtab_t barray, size_t length)
        {
            pragma(inline, false);
            const newcap = (barray.capacity == 0)
                ? length
                : (length + (length >> 1) + 15) & ~15;

            T* p;
            if (config.flags2 & (CFG2phgen | CFG2phuse | CFG2phauto | CFG2phautoy))
                p = cast(T*) MEM_PH_REALLOC(barray.tab, newcap * T.sizeof);
            else
                p = cast(T*) realloc(barray.tab, newcap * T.sizeof);

            if (length && !p)
            {
                version (unittest)
                    assert(0);
                else
                    err_nomem();
            }
            barray.tab = p;
            barray.length = length;
            barray.capacity = newcap;
            //barray.array = p[0 .. length];
        }

        if (length <= capacity)
            this.length = length;               // the fast path
            //array = array.ptr[0 .. length];   // the fast path
        else
            enlarge(this, length);              // the slow path
    }

    @trusted
    ref inout(T) opIndex(size_t i) inout nothrow pure @nogc
    {
        assert(i < length);
        return tab[i];
    }

    @trusted
    extern (D) inout(T)[] opSlice() inout nothrow pure @nogc
    {
        return tab[0 .. length];
    }

    @trusted
    extern (D) inout(T)[] opSlice(size_t a, size_t b) inout nothrow pure @nogc
    {
        assert(a <= b && b <= length);
        return tab[a .. b];
    }

    @trusted
    void dtor()
    {
        if (config.flags2 & (CFG2phgen | CFG2phuse | CFG2phauto | CFG2phautoy))
            MEM_PH_FREE(tab);
        else
            free(tab);
        length = 0;
        tab = null;
        symmax = 0;
    }

    SYMIDX length;              // 1 past end
    SYMIDX symmax;              // max # of entries in tab[] possible
    T* tab;                     // local Symbol table
}

