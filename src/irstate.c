
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/irstate.c
 */

#include <stdio.h>

#include "mars.h"
#include "mtype.h"
#include "declaration.h"
#include "irstate.h"
#include "statement.h"

IRState::IRState(IRState *irs, Statement *s)
{
    prev = irs;
    statement = s;
    symbol = NULL;
    breakBlock = NULL;
    contBlock = NULL;
    switchBlock = NULL;
    defaultBlock = NULL;
    finallyBlock = NULL;
    ident = NULL;
    ehidden = NULL;
    startaddress = NULL;
    if (irs)
    {
        m = irs->m;
        shidden = irs->shidden;
        sclosure = irs->sclosure;
        sthis = irs->sthis;
        blx = irs->blx;
        deferToObj = irs->deferToObj;
        varsInScope = irs->varsInScope;
        labels = irs->labels;
    }
    else
    {
        m = NULL;
        shidden = NULL;
        sclosure = NULL;
        sthis = NULL;
        blx = NULL;
        deferToObj = NULL;
        varsInScope = NULL;
        labels = NULL;
    }
}

IRState::IRState(IRState *irs, Dsymbol *s)
{
    prev = irs;
    statement = NULL;
    symbol = s;
    breakBlock = NULL;
    contBlock = NULL;
    switchBlock = NULL;
    defaultBlock = NULL;
    finallyBlock = NULL;
    ident = NULL;
    ehidden = NULL;
    startaddress = NULL;
    if (irs)
    {
        m = irs->m;
        shidden = irs->shidden;
        sclosure = irs->sclosure;
        sthis = irs->sthis;
        blx = irs->blx;
        deferToObj = irs->deferToObj;
        varsInScope = irs->varsInScope;
        labels = irs->labels;
    }
    else
    {
        m = NULL;
        shidden = NULL;
        sclosure = NULL;
        sthis = NULL;
        blx = NULL;
        deferToObj = NULL;
        varsInScope = NULL;
        labels = NULL;
    }
}

IRState::IRState(Module *m, Dsymbol *s)
{
    prev = NULL;
    statement = NULL;
    this->m = m;
    symbol = s;
    breakBlock = NULL;
    contBlock = NULL;
    switchBlock = NULL;
    defaultBlock = NULL;
    finallyBlock = NULL;
    ident = NULL;
    ehidden = NULL;
    shidden = NULL;
    sclosure = NULL;
    sthis = NULL;
    blx = NULL;
    deferToObj = NULL;
    startaddress = NULL;
    varsInScope = NULL;
    labels = NULL;
}

block *IRState::getBreakBlock(Identifier *ident)
{
    IRState *bc;
    if (ident)
    {
        Statement *related = NULL;
        block *ret = NULL;
        for (bc = this; bc; bc = bc->prev)
        {
            // The label for a breakBlock may actually be some levels up (e.g.
            // on a try/finally wrapping a loop). We'll see if this breakBlock
            // is the one to return once we reach that outer statement (which
            // in many cases will be this same statement).
            if (bc->breakBlock)
            {
                related = bc->statement->getRelatedLabeled();
                ret = bc->breakBlock;
            }
            if (bc->statement == related && bc->prev->ident == ident)
                return ret;
        }
    }
    else
    {
        for (bc = this; bc; bc = bc->prev)
        {
            if (bc->breakBlock)
                return bc->breakBlock;
        }
    }
    return NULL;
}

block *IRState::getContBlock(Identifier *ident)
{
    IRState *bc;

    if (ident)
    {
        block *ret = NULL;
        for (bc = this; bc; bc = bc->prev)
        {
            // The label for a contBlock may actually be some levels up (e.g.
            // on a try/finally wrapping a loop). We'll see if this contBlock
            // is the one to return once we reach that outer statement (which
            // in many cases will be this same statement).
            if (bc->contBlock)
            {
                ret = bc->contBlock;
            }
            if (bc->prev && bc->prev->ident == ident)
                return ret;
        }
    }
    else
    {
        for (bc = this; bc; bc = bc->prev)
        {
            if (bc->contBlock)
                return bc->contBlock;
        }
    }
    return NULL;
}

block *IRState::getSwitchBlock()
{
    IRState *bc;

    for (bc = this; bc; bc = bc->prev)
    {
        if (bc->switchBlock)
            return bc->switchBlock;
    }
    return NULL;
}

block *IRState::getDefaultBlock()
{
    IRState *bc;

    for (bc = this; bc; bc = bc->prev)
    {
        if (bc->defaultBlock)
            return bc->defaultBlock;
    }
    return NULL;
}

block *IRState::getFinallyBlock()
{
    IRState *bc;

    for (bc = this; bc; bc = bc->prev)
    {
        if (bc->finallyBlock)
            return bc->finallyBlock;
    }
    return NULL;
}

FuncDeclaration *IRState::getFunc()
{
    IRState *bc;

    for (bc = this; bc->prev; bc = bc->prev)
    {
    }
    return (FuncDeclaration *)(bc->symbol);
}


/**********************
 * Returns true if do array bounds checking for the current function
 */
bool IRState::arrayBoundsCheck()
{
    bool result;
    switch (global.params.useArrayBounds)
    {
        case BOUNDSCHECKoff:
            result = false;
            break;

        case BOUNDSCHECKon:
            result = true;
            break;

        case BOUNDSCHECKsafeonly:
        {
            result = false;
            FuncDeclaration *fd = getFunc();
            if (fd)
            {   Type *t = fd->type;
                if (t->ty == Tfunction && ((TypeFunction *)t)->trust == TRUSTsafe)
                    result = true;
            }
            break;
        }

        default:
            assert(0);
    }
    return result;
}
