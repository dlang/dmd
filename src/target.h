
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

#include <stdlib.h> //for size_t

class Type;
class Mangler;
class Dsymbol;
struct Loc;
//enum LINK;

struct Target
{
    static int ptrsize;
    static int realsize;        // size a real consumes in memory
    static int realpad;         // 'padding' added to the CPU real size to bring it up to realsize
    static int realalignsize;   // alignment for reals

    static void init();
    static unsigned alignsize(Type* type);
    static unsigned fieldalign(Type* type);
    static unsigned critsecsize();
    
    /*
     * mangle stuff
     */
    //mangle specified symbol with spesified linkage
    static const char *mangleSymbol(Dsymbol* sym, size_t link);
    
    //Mangle validation is compiler implementation specific.
    static bool validateMangle(Loc, const void *mangle, size_t len);
    
};

#endif
