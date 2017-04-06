
/* Compiler implementation of the D programming language
 * Copyright (c) 2013-2014 by Digital Mars
 * All Rights Reserved
 * written by Iain Buclaw
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/target.h
 */

#ifndef TARGET_H
#define TARGET_H

// This file contains a data structure that describes a back-end target.
// At present it is incomplete, but in future it should grow to contain
// most or all target machine and target O/S specific information.
#include "globals.h"

class Expression;
class Type;
class Module;
struct OutBuffer;

struct Target
{
    static int ptrsize;
    static int realsize;             // size a real consumes in memory
    static int realpad;              // 'padding' added to the CPU real size to bring it up to realsize
    static int realalignsize;        // alignment for reals
    static bool realislongdouble;    // distinguish between C 'long double' and '__float128'
    static bool reverseCppOverloads; // with dmc and cl, overloaded functions are grouped and in reverse order
    static bool cppExceptions;       // set if catching C++ exceptions is supported
    static int c_longsize;           // size of a C 'long' or 'unsigned long' type
    static int c_long_doublesize;    // size of a C 'long double'
    static int classinfosize;        // size of 'ClassInfo'

#ifdef IN_LLVM
    struct RealProperties
    {
        // implemented in gen/target.cpp
        static real_t max();
        static real_t min_normal();
        static real_t nan();
        static real_t snan();
        static real_t infinity();
        static real_t epsilon();

        static real_t host_max();
        static real_t host_min_normal();
        static real_t host_nan();
        static real_t host_snan();
        static real_t host_infinity();
        static real_t host_epsilon();

        static int64_t dig;
        static int64_t mant_dig;
        static int64_t max_exp;
        static int64_t min_exp;
        static int64_t max_10_exp;
        static int64_t min_10_exp;
    };
#endif

    static void _init();
    // Type sizes and support.
    static unsigned alignsize(Type *type);
    static unsigned fieldalign(Type *type);
    static unsigned critsecsize();
    static Type *va_listType();  // get type of va_list
    static int checkVectorType(int sz, Type *type);
    // CTFE support for cross-compilation.
    static Expression *paintAsType(Expression *e, Type *type);
    // ABI and backend.
    static void loadModule(Module *m);
    static void prefixName(OutBuffer *buf, LINK linkage);
};

#endif
