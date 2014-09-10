
/* Compiler implementation of the D programming language
 * Copyright (c) 2013-2014 by Digital Mars
 * All Rights Reserved
 * written by Iain Buclaw
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/target.h
 */

#ifndef TARGET_H
#define TARGET_H

// This file contains a data structure that describes a back-end target.
// At present it is incomplete, but in future it should grow to contain
// most or all target machine and target O/S specific information.

class Expression;
class Type;

struct Target
{
    static int ptrsize;
    static int realsize;        // size a real consumes in memory
    static int realpad;         // 'padding' added to the CPU real size to bring it up to realsize
    static int realalignsize;   // alignment for reals
    static bool reverseCppOverloads; // with dmc, overloaded functions are grouped and in reverse order
    static int c_longsize;           // size of a C 'long' or 'unsigned long' type
    static int c_long_doublesize;    // size of a C 'long double'

    static void init();
    static unsigned alignsize(Type* type);
    static unsigned fieldalign(Type* type);
    static unsigned critsecsize();
    static Type *va_listType();  // get type of va_list
    static Expression *paintAsType(Expression *e, Type *type);
    static int checkVectorType(int sz, Type *type);
};

#endif
