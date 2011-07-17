
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com

#include <stdio.h>

#include "mars.h"
#include "mtype.h"
#include "declaration.h"
#include "irstate.h"

IRState::IRState(IRState *irs, Statement *s)
{
    prev = irs;
    statement = s;
    symbol = NULL;
    breakBlock = NULL;
    contBlock = NULL;
    switchBlock = NULL;
    defaultBlock = NULL;
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
    ident = NULL;
    ehidden = NULL;
    shidden = NULL;
    sclosure = NULL;
    sthis = NULL;
    blx = NULL;
    deferToObj = NULL;
    startaddress = NULL;
    varsInScope = NULL;
}

block *IRState::getBreakBlock(Identifier *ident)
{
    IRState *bc;

    for (bc = this; bc; bc = bc->prev)
    {
        if (ident)
        {
            if (bc->prev && bc->prev->ident == ident)
                return bc->breakBlock;
        }
        else if (bc->breakBlock)
            return bc->breakBlock;
    }
    return NULL;
}

block *IRState::getContBlock(Identifier *ident)
{
    IRState *bc;

    for (bc = this; bc; bc = bc->prev)
    {
        if (ident)
        {
            if (bc->prev && bc->prev->ident == ident)
                return bc->contBlock;
        }
        else if (bc->contBlock)
            return bc->contBlock;
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

FuncDeclaration *IRState::getFunc()
{
    IRState *bc;

    for (bc = this; bc->prev; bc = bc->prev)
    {
    }
    return (FuncDeclaration *)(bc->symbol);
}


/**********************
 * Return !=0 if do array bounds checking
 */
int IRState::arrayBoundsCheck()
{
    int result = global.params.useArrayBounds;

    if (result == 1)
    {   // For safe functions only
        result = 0;
        FuncDeclaration *fd = getFunc();
        if (fd)
        {   Type *t = fd->type;
            if (t->ty == Tfunction && ((TypeFunction *)t)->trust == TRUSTsafe)
                result = 1;
        }
    }
    return result;
}
