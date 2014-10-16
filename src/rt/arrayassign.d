/**
 * Implementation of array assignment support routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arrayassign;

private
{
    import rt.util.array;
    import rt.util.string;
    import core.stdc.string;
    import core.stdc.stdlib;
    debug(PRINTF) import core.stdc.stdio;
}

/**
 * Does array assignment (not construction) from another
 * array of the same element type.
 * ti is the element type.
 * Handles overlapping copies.
 */
extern (C) void[] _d_arrayassign(TypeInfo ti, void[] from, void[] to)
{
    debug(PRINTF) printf("_d_arrayassign(from = %p,%d, to = %p,%d) size = %d\n", from.ptr, from.length, to.ptr, to.length, ti.tsize);

    auto element_size = ti.tsize;

    enforceRawArraysConformable("copy", element_size, from, to, true);

    /* Need a temporary buffer tmp[] big enough to hold one element
     */
    void[16] buf = void;
    void[] tmp;
    if (element_size > buf.sizeof)
        tmp = alloca(element_size)[0 .. element_size];
    else
        tmp = buf[];


    if (to.ptr <= from.ptr)
    {
        foreach (i; 0 .. to.length)
        {
            void* pto   = to.ptr   + i * element_size;
            void* pfrom = from.ptr + i * element_size;
            memcpy(tmp.ptr, pto, element_size);
            memcpy(pto, pfrom, element_size);
            ti.postblit(pto);
            ti.destroy(tmp.ptr);
        }
    }
    else
    {
        for (auto i = to.length; i--; )
        {
            void* pto   = to.ptr   + i * element_size;
            void* pfrom = from.ptr + i * element_size;
            memcpy(tmp.ptr, pto, element_size);
            memcpy(pto, pfrom, element_size);
            ti.postblit(pto);
            ti.destroy(tmp.ptr);
        }
    }
    return to;
}

/**
 * Does array initialization (not assignment) from another
 * array of the same element type.
 * ti is the element type.
 */
extern (C) void[] _d_arrayctor(TypeInfo ti, void[] from, void[] to)
{
    debug(PRINTF) printf("_d_arrayctor(from = %p,%d, to = %p,%d) size = %d\n", from.ptr, from.length, to.ptr, to.length, ti.tsize);


    auto element_size = ti.tsize;

    enforceRawArraysConformable("initialization", element_size, from, to);

    size_t i;
    try
    {
        for (i = 0; i < to.length; i++)
        {
            // Copy construction is defined as bit copy followed by postblit.
            memcpy(to.ptr + i * element_size, from.ptr + i * element_size, element_size);
            ti.postblit(to.ptr + i * element_size);
        }
    }
    catch (Throwable o)
    {
        /* Destroy, in reverse order, what we've constructed so far
         */
        while (i--)
        {
            ti.destroy(to.ptr + i * element_size);
        }

        throw o;
    }
    return to;
}


/**
 * Do assignment to an array.
 *      p[0 .. count] = value;
 */
extern (C) void* _d_arraysetassign(void* p, void* value, int count, TypeInfo ti)
{
    void* pstart = p;

    auto element_size = ti.tsize;

    //Need a temporary buffer tmp[] big enough to hold one element
    void[16] buf = void;
    void[] tmp;
    if (element_size > buf.sizeof)
    {
        tmp = alloca(element_size)[0 .. element_size];
    }
    else
        tmp = buf[];

    foreach (i; 0 .. count)
    {
        memcpy(tmp.ptr, p, element_size);
        memcpy(p, value, element_size);
        ti.postblit(p);
        ti.destroy(tmp.ptr);
        p += element_size;
    }
    return pstart;
}

/**
 * Do construction of an array.
 *      ti[count] p = value;
 */
extern (C) void* _d_arraysetctor(void* p, void* value, int count, TypeInfo ti)
{
    void* pstart = p;
    auto element_size = ti.tsize;

    try
    {
        foreach (i; 0 .. count)
        {
            // Copy construction is defined as bit copy followed by postblit.
            memcpy(p, value, element_size);
            ti.postblit(p);
            p += element_size;
        }
    }
    catch (Throwable o)
    {
        // Destroy, in reverse order, what we've constructed so far
        while (p > pstart)
        {
            p -= element_size;
            ti.destroy(p);
        }

        throw o;
    }
    return pstart;
}
