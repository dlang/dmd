/**
 * Global variables for PARSER
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/var.d, backend/var.d)
 */

module dmd.backend.var;

import core.stdc.stdio;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.goh;
import dmd.backend.blockopt : BlockOpt;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;


nothrow:
@safe:

__gshared:

/* Global flags:
 */

bool debuga = 0; /// cg - watch assignaddr()
bool debugb = 0; /// watch block optimization
bool debugc = 0; /// watch code generated
bool debugd = 0; /// watch debug information generated
bool debuge = 0; /// dump eh info
bool debugf = 0; /// trees after dooptim
bool debugg = 0; /// trees for code generator
bool debugo = 0; /// watch optimizer
bool debugr = 0; /// watch register allocation
bool debugs = 0; /// watch common subexp eliminator
bool debugt = 0; /// do test points
bool debugu = 0;
bool debugw = 0; /// watch progress
bool debugx = 0; /// suppress predefined CPP stuff
bool debugy = 0; /// watch output to il buffer


GlobalOptimizer go;
BlockOpt bo;

/* From debug.c */

Obj objmod = null;
