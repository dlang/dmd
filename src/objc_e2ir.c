
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_e2ir.c
 */

#include "aggregate.h"
#include "declaration.h"
#include "cc.h"
#include "el.h"
#include "mtype.h"

elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);

void objc_callfunc_setupSelector(elem *ec, FuncDeclaration *fd, elem *esel, Type *t, TypeFunction *&tf, elem *&ethis)
{
    assert(!fd);
    assert(esel);
    assert(t->nextOf()->ty == Tfunction);
    tf = (TypeFunction *)(t->nextOf());
    ethis = ec;
}

void objc_callfunc_setupMethodSelector(Type *tret, FuncDeclaration *fd, Type *t, elem *ehidden, elem *&esel)
{
    if (fd && fd->objc.selector && !esel)
    {
        if (fd->objc.selector->usesVTableDispatch())
        {
            elem* messageReference = el_var(ObjcSymbols::getMessageReference(fd->objc.selector, tret, ehidden != 0));
            esel = addressElem(messageReference, t);
        }

        else
            esel = fd->objc.selector->toElem();
    }
}

void objc_callfunc_setupEp(elem *esel, elem *&ep, int reverse)
{
    if (esel)
    {
        // using objc-style "virtual" call
        // add hidden argument (second to 'this') for selector used by dispatch function
        if (reverse)
            ep = el_param(esel,ep);
        else
            ep = el_param(ep,esel);
    }
}

void objc_callfunc_checkThisForSelector(elem *esel, elem *ethis)
{
    if (esel)
    {
        // All functions with a selector need a this pointer.
        assert(ethis);
    }
}

void objc_callfunc_setupMethodCall(int directcall, elem *&ec, FuncDeclaration *fd, Type *t, elem *&ehidden, elem *&ethis, TypeFunction *tf, Symbol *sfunc)
{
    if (fd->fbody && (!fd->isVirtual() || directcall || fd->isFinal()))
    {
        // make static call
        // this is an optimization that the Objective-C compiler
        // does not make, we do it only if the function to call is
        // defined in D code (has a body)
        ec = el_var(sfunc);
    }
    else if (directcall)
    {
        // call through Objective-C runtime dispatch
        ec = el_var(ObjcSymbols::getMsgSendSuper(ehidden != 0));

        // need to change this pointer to a pointer to an two-word
        // objc_super struct of the form { this ptr, class ptr }.
        AggregateDeclaration *ad = fd->isThis();
        ClassDeclaration *cd = ad->isClassDeclaration();
        assert(cd /* call to objc_msgSendSuper with no class delcaration */);

        // FIXME: faking delegate type and objc_super types
        elem *eclassref = el_var(ObjcSymbols::getClassReference(cd));
        elem *esuper = el_pair(TYdelegate, ethis, eclassref);

        ethis = addressElem(esuper, t); // get a pointer to our objc_super struct
    }
    else
    {
        // make objc-style "virtual" call using dispatch function
        assert(ethis);
        Type *tret = tf->next;

        if (fd->objc.selector->usesVTableDispatch())
            ec = el_var(ObjcSymbols::getMsgSendFixup(tret, ehidden != 0));
        else
            ec = el_var(ObjcSymbols::getMsgSend(tret, ehidden != 0));
    }
}

void objc_callfunc_setupSelectorCall(elem *&ec, elem *ehidden, elem *ethis, TypeFunction *tf)
{
    // make objc-style "virtual" call using dispatch function
    assert(ethis);
    Type *tret = tf->next;
    ec = el_var(ObjcSymbols::getMsgSend(tret, ehidden != 0));
}
