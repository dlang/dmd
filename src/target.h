
// Copyright (c) 2013 by Digital Mars
// All Rights Reserved
// written by Iain Buclaw
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef TARGET_H
#define TARGET_H

// This file contains a data structure that describes a back-end target.
// At present it is incomplete, but in future it should grow to contain
// most or all target machine and target O/S specific information.

class Type;

struct Target
{
    static int ptrsize;
    static int realsize;        // size a real consumes in memory
    static int realpad;         // 'padding' added to the CPU real size to bring it up to realsize
    static int realalignsize;   // alignment for reals
    static bool reverseCppOverloads; // with dmc, overloaded functions are grouped and in reverse order

    static void init();
    static unsigned alignsize(Type* type);
    static unsigned fieldalign(Type* type);
    static unsigned critsecsize();
};

#endif
