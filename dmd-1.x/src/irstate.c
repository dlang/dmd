
// Compiler implementation of the D programming language
// Copyright (c) 1999-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com

#include <stdio.h>

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
    if (irs)
    {
        m = irs->m;
        shidden = irs->shidden;
        sthis = irs->sthis;
        blx = irs->blx;
        deferToObj = irs->deferToObj;
    }
    else
    {
        m = NULL;
        shidden = NULL;
        sthis = NULL;
        blx = NULL;
        deferToObj = NULL;
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
    if (irs)
    {
        m = irs->m;
        shidden = irs->shidden;
        sthis = irs->sthis;
        blx = irs->blx;
        deferToObj = irs->deferToObj;
    }
    else
    {
        m = NULL;
        shidden = NULL;
        sthis = NULL;
        blx = NULL;
        deferToObj = NULL;
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
    sthis = NULL;
    blx = NULL;
    deferToObj = NULL;
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


