
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2015 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/irstate.h
 */

#ifndef DMD_CONTEXT_H
#define DMD_CONTEXT_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

class Module;
class Statement;
struct block;
class Dsymbol;
class Identifier;
struct Symbol;
class FuncDeclaration;
struct Blockx;
struct elem;
#include "arraytypes.h"

struct IRState
{
    IRState *prev;
    Statement *statement;
    Module *m;                  // module
    Dsymbol *symbol;
    Identifier *ident;
    Symbol *shidden;            // hidden parameter to function
    Symbol *sthis;              // 'this' parameter to function (member and nested)
    Symbol *sclosure;           // pointer to closure instance
    Blockx *blx;
    Dsymbols *deferToObj;       // array of Dsymbol's to run toObjFile(bool multiobj) on later
    elem *ehidden;              // transmit hidden pointer to CallExp::toElem()
    Symbol *startaddress;
    VarDeclarations *varsInScope; // variables that are in scope that will need destruction later
    AA **labels;                // table of labels used/declared in function

    block *breakBlock;
    block *contBlock;
    block *switchBlock;
    block *defaultBlock;
    block *finallyBlock;

    IRState(IRState *irs, Statement *s);
    IRState(IRState *irs, Dsymbol *s);
    IRState(Module *m, Dsymbol *s);

    block *getBreakBlock(Identifier *ident);
    block *getContBlock(Identifier *ident);
    block *getSwitchBlock();
    block *getDefaultBlock();
    block *getFinallyBlock();
    FuncDeclaration *getFunc();
    bool arrayBoundsCheck();
};

#endif /* DMD_CONTEXT_H */
