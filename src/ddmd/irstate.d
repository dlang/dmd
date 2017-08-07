/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _irstate.d)
 */

module ddmd.irstate;

import ddmd.root.array;

import ddmd.arraytypes;
import ddmd.backend.type;
import ddmd.dmodule;
import ddmd.dsymbol;
import ddmd.func;
import ddmd.identifier;
import ddmd.statement;
import ddmd.globals;
import ddmd.mtype;

import ddmd.backend.cc;
import ddmd.backend.el;

/****************************************
 * Our label symbol, with vector to keep track of forward references.
 */

extern (C++) struct Label
{
    block *lblock;      // The block to which the label is defined.
    block *fwdrefs;     // The first use of the label before it is defined.
}

/***********************************************************
 */
struct IRState
{
    IRState* prev;
    Statement statement;
    Module m;                       // module
    Dsymbol symbol;
    Identifier ident;
    Symbol* shidden;                // hidden parameter to function
    Symbol* sthis;                  // 'this' parameter to function (member and nested)
    Symbol* sclosure;               // pointer to closure instance
    Blockx* blx;
    Dsymbols* deferToObj;           // array of Dsymbol's to run toObjFile(bool multiobj) on later
    elem* ehidden;                  // transmit hidden pointer to CallExp::toElem()
    Symbol* startaddress;
    Array!(elem*)* varsInScope;      // variables that are in scope that will need destruction later
    Label*[void*]* labels;          // table of labels used/declared in function

    block* breakBlock;
    block* contBlock;
    block* switchBlock;
    block* defaultBlock;
    block* finallyBlock;

    extern (D) this(IRState* irs, Statement s)
    {
        prev = irs;
        statement = s;
        if (irs)
        {
            m = irs.m;
            shidden = irs.shidden;
            sclosure = irs.sclosure;
            sthis = irs.sthis;
            blx = irs.blx;
            deferToObj = irs.deferToObj;
            varsInScope = irs.varsInScope;
            labels = irs.labels;
        }
    }

    extern (D) this(IRState* irs, Dsymbol s)
    {
        prev = irs;
        symbol = s;
        if (irs)
        {
            m = irs.m;
            shidden = irs.shidden;
            sclosure = irs.sclosure;
            sthis = irs.sthis;
            blx = irs.blx;
            deferToObj = irs.deferToObj;
            varsInScope = irs.varsInScope;
            labels = irs.labels;
        }
    }

    extern (D) this(Module m, Dsymbol s)
    {
        this.m = m;
        symbol = s;
    }

    /****
     * Access labels AA from C++ code.
     * Params:
     *  s = key
     * Returns:
     *  pointer to value if it's there, null if not
     */
    extern (C++) Label** lookupLabel(Statement s)
    {
        return cast(void*)s in *labels;
    }

    /****
     * Access labels AA from C++ code.
     * Params:
     *  s = key
     *  label = value
     */
    extern (C++) void insertLabel(Statement s, Label* label)
    {
        (*labels)[cast(void*)s] = label;
    }

    extern (C++) block* getBreakBlock(Identifier ident)
    {
        IRState* bc;
        if (ident)
        {
            Statement related = null;
            block* ret = null;
            for (bc = &this; bc; bc = bc.prev)
            {
                // The label for a breakBlock may actually be some levels up (e.g.
                // on a try/finally wrapping a loop). We'll see if this breakBlock
                // is the one to return once we reach that outer statement (which
                // in many cases will be this same statement).
                if (bc.breakBlock)
                {
                    related = bc.statement.getRelatedLabeled();
                    ret = bc.breakBlock;
                }
                if (bc.statement == related && bc.prev.ident == ident)
                    return ret;
            }
        }
        else
        {
            for (bc = &this; bc; bc = bc.prev)
            {
                if (bc.breakBlock)
                    return bc.breakBlock;
            }
        }
        return null;
    }

    extern (C++) block* getContBlock(Identifier ident)
    {
        IRState* bc;
        if (ident)
        {
            block* ret = null;
            for (bc = &this; bc; bc = bc.prev)
            {
                // The label for a contBlock may actually be some levels up (e.g.
                // on a try/finally wrapping a loop). We'll see if this contBlock
                // is the one to return once we reach that outer statement (which
                // in many cases will be this same statement).
                if (bc.contBlock)
                {
                    ret = bc.contBlock;
                }
                if (bc.prev && bc.prev.ident == ident)
                    return ret;
            }
        }
        else
        {
            for (bc = &this; bc; bc = bc.prev)
            {
                if (bc.contBlock)
                    return bc.contBlock;
            }
        }
        return null;
    }

    extern (C++) block* getSwitchBlock()
    {
        IRState* bc;
        for (bc = &this; bc; bc = bc.prev)
        {
            if (bc.switchBlock)
                return bc.switchBlock;
        }
        return null;
    }

    extern (C++) block* getDefaultBlock()
    {
        IRState* bc;
        for (bc = &this; bc; bc = bc.prev)
        {
            if (bc.defaultBlock)
                return bc.defaultBlock;
        }
        return null;
    }

    extern (C++) block* getFinallyBlock()
    {
        IRState* bc;
        for (bc = &this; bc; bc = bc.prev)
        {
            if (bc.finallyBlock)
                return bc.finallyBlock;
        }
        return null;
    }

    extern (C++) FuncDeclaration getFunc()
    {
        IRState* bc;
        for (bc = &this; bc.prev; bc = bc.prev)
        {
        }
        return cast(FuncDeclaration)bc.symbol;
    }

    /**********************
     * Returns true if do array bounds checking for the current function
     */
    extern (C++) bool arrayBoundsCheck()
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
                FuncDeclaration fd = getFunc();
                if (fd)
                {
                    Type t = fd.type;
                    if (t.ty == Tfunction && (cast(TypeFunction)t).trust == TRUSTsafe)
                        result = true;
                }
                break;
            }
        default:
            assert(0);
        }
        return result;
    }
}
