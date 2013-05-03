
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

struct Type;

struct Target
{
    static int ptrsize;
    static int realsize;        // size a real consumes in memory
    static int realpad;         // 'padding' added to the CPU real size to bring it up to realsize
    static int realalignsize;   // alignment for reals
    
    static bool bytesbigendian;   // bytes order in word
    static bool wordsbigendian;   // words order in multi-word object
    static bool floatbigendian;   // bytes order in floating point types
    
    static void init();
    static unsigned alignsize(Type* type);
    static void toTargetFloatBO (void *p, unsigned size);
    static void toTargetWordBO (void *p, unsigned size);
};

#endif
