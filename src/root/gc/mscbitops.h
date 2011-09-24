// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Bit operations for MSC and I386

#ifndef MSCBITOPS_H
#define MSCBITOPS_H 1

inline int _inline_bsf(int w)
{   int index;

    index = 0;
    while (!(w & 1))
    {   index++;
        w >>= 1;
    }
    return index;
}

#endif
