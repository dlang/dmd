/**
 * Inline assembler implementation for DMD.
 * https://dlang.org/spec/iasm.html
 *
 * Copyright:   Copyright (C) 2025 by The D Language Foundation, All Rights Reserved
 * Authors:     Walter Bright
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/iasmaarch64.d, _iasmaarch64.d)
 * Documentation:  https://dlang.org/phobos/dmd_iasmaarch64.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/iasmaarch64.d
 */

module dmd.iasm.dmdaarch64;

import core.stdc.stdio;
import core.stdc.stdarg;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.astenums;
import dmd.declaration;
import dmd.denum;
import dmd.dinterpret;
import dmd.dmdparams;
import dmd.dscope;
import dmd.dsymbol;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.funcsem : checkNestedReference;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.location;
import dmd.mtype;
import dmd.optimize;
import dmd.statement;
import dmd.target;
import dmd.tokens;
import dmd.typesem : pointerTo, size;

import dmd.root.ctfloat;
import dmd.common.outbuffer;
import dmd.root.rmem;
import dmd.rootobject;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.global;
import dmd.backend.iasm;

/************************
 * Perform semantic analysis on InlineAsmStatement.
 * Params:
 *      s = inline asm statement
 *      sc = context
 * Returns:
 *      `s` on success, ErrorStatement if errors happened
 */
public Statement inlineAsmAArch64Semantic(InlineAsmStatement s, Scope* sc)
{
    //printf("InlineAsmAArch64Statement.semantic()\n");
    error(s.loc, "AArch64 inline assembler not implemented (yet!)");
    return new ErrorStatement();
}
