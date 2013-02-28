/**
 * This is a public domain version of qsort.d.  All it does is call C's
 * qsort().
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
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

struct Array
{
    size_t length;
    void*  ptr;
}

private TypeInfo tiglobal;

extern (C) int cmp(in void* p1, in void* p2)
{
    return tiglobal.compare(p1, p2);
}

extern (C) void[] _adSort(void[] a, TypeInfo ti)
{
    tiglobal = ti;
    qsort(a.ptr, a.length, cast(size_t)ti.tsize, &cmp);
    return a;
}



unittest
{
    debug(qsort) printf("array.sort.unittest()\n");

    int a[] = new int[10];

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

    a.sort;

    for (int i = 0; i < a.length - 1; i++)
    {
        //printf("i = %d", i);
        //printf(" %d %d\n", a[i], a[i + 1]);
        assert(a[i] <= a[i + 1]);
    }
}
