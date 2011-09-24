// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Bit operations for GCC and I386

#ifndef GCCBITOPS_H
#define GCCBITOPS_H 1

inline int _inline_bsf(int w)
{   int index;

    __asm__ __volatile__
    (
        "bsfl %1, %0 \n\t"
        : "=r" (index)
        : "r" (w)
    );
    return index;
}


inline int _inline_bt(unsigned *p, int i)
{
    char result;

    __asm__ __volatile__
    (
        "btl %2,%1      \n\t"
        "setc %0        \n\t"
        :"=r" (result)
        :"m" (*p), "r" (i)
    );
    return result;
}

inline int _inline_bts(unsigned *p, int i)
{
    char result;

    __asm__ __volatile__
    (
        "btsl %2,%1     \n\t"
        "setc %0        \n\t"
        :"=r" (result)
        :"m" (*p), "r" (i)
    );
    return result;
}

inline int _inline_btr(unsigned *p, int i)
{
    char result;

    __asm__ __volatile__
    (
        "btrl %2,%1     \n\t"
        "setc %0        \n\t"
        :"=r" (result)
        :"m" (*p), "r" (i)
    );
    return result;
}

#endif
