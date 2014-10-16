/**
 * This is a public domain version of qsort.d.  All it does is call C's
 * qsort().
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Martin Nowak
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.qsort;

//debug=qsort;

private import core.stdc.stdlib;

version (linux)
{
    alias extern (C) int function(const void *, const void *, void *) Cmp;
    extern (C) void qsort_r(void *base, size_t nmemb, size_t size, Cmp cmp, void *arg);

    extern (C) void[] _adSort(void[] a, TypeInfo ti)
    {
        extern (C) int cmp(in void* p1, in void* p2, void* ti)
        {
            return (cast(TypeInfo)ti).compare(p1, p2);
        }
        qsort_r(a.ptr, a.length, ti.tsize, &cmp, cast(void*)ti);
        return a;
    }
}
else version (FreeBSD)
{
    alias extern (C) int function(void *, const void *, const void *) Cmp;
    extern (C) void qsort_r(void *base, size_t nmemb, size_t size, void *thunk, Cmp cmp);

    extern (C) void[] _adSort(void[] a, TypeInfo ti)
    {
        extern (C) int cmp(void* ti, in void* p1, in void* p2)
        {
            return (cast(TypeInfo)ti).compare(p1, p2);
        }
        qsort_r(a.ptr, a.length, ti.tsize, cast(void*)ti, &cmp);
        return a;
    }
}
else version (OSX)
{
    alias extern (C) int function(void *, const void *, const void *) Cmp;
    extern (C) void qsort_r(void *base, size_t nmemb, size_t size, void *thunk, Cmp cmp);

    extern (C) void[] _adSort(void[] a, TypeInfo ti)
    {
        extern (C) int cmp(void* ti, in void* p1, in void* p2)
        {
            return (cast(TypeInfo)ti).compare(p1, p2);
        }
        qsort_r(a.ptr, a.length, ti.tsize, cast(void*)ti, &cmp);
        return a;
    }
}
else
{
    private TypeInfo tiglobal;

    extern (C) void[] _adSort(void[] a, TypeInfo ti)
    {
        extern (C) int cmp(in void* p1, in void* p2)
        {
            return tiglobal.compare(p1, p2);
        }
        tiglobal = ti;
        qsort(a.ptr, a.length, ti.tsize, &cmp);
        return a;
    }
}



unittest
{
    debug(qsort) printf("array.sort.unittest()\n");

    int[] a = new int[10];

    a[0] = 23;
    a[1] = 1;
    a[2] = 64;
    a[3] = 5;
    a[4] = 6;
    a[5] = 5;
    a[6] = 17;
    a[7] = 3;
    a[8] = 0;
    a[9] = -1;

    _adSort(*cast(void[]*)&a, typeid(a[0]));

    for (int i = 0; i < a.length - 1; i++)
    {
        //printf("i = %d", i);
        //printf(" %d %d\n", a[i], a[i + 1]);
        assert(a[i] <= a[i + 1]);
    }
}
