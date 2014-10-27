
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
#include "global.h"
#include "mtype.h"
#include "oper.h"

elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);

// MARK: callfunc

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

// MARK: toElem

void objc_toElem_visit_StringExp_Tclass(StringExp *se, elem *&e)
{
    Symbol *si = ObjcSymbols::getStringLiteral(se->string, se->len, se->sz);
    e = el_ptr(si);
}

void objc_toElem_visit_NewExp_Tclass(IRState *irs, NewExp *ne, Type *&ectype, TypeClass *tclass, ClassDeclaration *cd, elem *&ex, elem *&ey, elem *&ez)
{
    elem *ei;
    Symbol *si;

    if (ne->onstack)
        ne->error("cannot allocate Objective-C class on the stack");

    if (ne->objcalloc)
    {
        // Call allocator func with class reference
        ex = el_var(ObjcSymbols::getClassReference(cd));
        ex = callfunc(ne->loc, irs, 0, ne->type, ex, ne->objcalloc->type,
                      ne->objcalloc, ne->objcalloc->type, NULL, ne->newargs, NULL);
    }
    else
    {
        ne->error("Cannot allocate Objective-C class, missing 'alloc' function.");
        exit(-1);
    }

    // FIXME: skipping initialization (actually, all fields will be zeros)
    // Need to assign each non-zero field separately.

    //si = tclass->sym->toInitializer();
    //ei = el_var(si);

    if (cd->isNested())
    {
        ey = el_same(&ex);
        ez = el_copytree(ey);
    }
    else if (ne->member)
        ez = el_same(&ex);

    //ex = el_una(OPind, TYstruct, ex);
    //ex = el_bin(OPstreq, TYnptr, ex, ei);
    //ex->Enumbytes = cd->size(loc);
    //ex = el_una(OPaddr, TYnptr, ex);
    ectype = tclass;
}

bool objc_toElem_visit_NewExp_Tclass_isDirectCall(bool isObjc)
{
#if DMD_OBJC
    // Call Objective-C constructor (not a direct call)
    return !isObjc;
#else
    // Call constructor
    return true;
#endif
}

void objc_toElem_visit_AssertExp_callInvariant(symbol *&ts, elem *&einv, Type *t1)
{
    ts = symbol_genauto(Type_toCtype(t1));
    // Call Objective-C invariant
    einv = el_bin(OPcall, TYvoid, el_var(rtlsym[RTLSYM_DINVARIANT_OBJC]), el_var(ts));
}

void objc_toElem_visit_DotVarExp_nonFragileAbiOffset(VarDeclaration *v, Type *tb1, elem *&offset)
{
    if (global.params.isObjcNonFragileAbi && tb1->ty == Tclass)
    {
        ClassDeclaration* cls = ((TypeClass*) tb1)->sym;
        if (cls->objc.objc)
        {
            NonFragileAbiObjcClassDeclaration objcClass(cls);
            offset = el_var(objcClass.getIVarOffset(v));
        }
    }
}

elem * objc_toElem_visit_ObjcSelectorExp(ObjcSelectorExp *ose)
{
    elem *result = NULL;

    if (ose->func)
        result = ose->func->objc.selector->toElem();
    else if (ose->selname)
        result = ObjcSelector::lookup(ose->selname)->toElem();
    else
        assert(0);

    return result;
}

void objc_toElem_visit_CallExp_selector(IRState *irs, CallExp *ce, elem *&ec, elem *&esel)
{
    assert(ce->argument0);
    ec = toElem(ce->argument0, irs);
    esel = toElem(ce->e1, irs);
}

ControlFlow objc_toElem_visit_CastExp_Tclass_fromObjc(int &rtl, ClassDeclaration *cdfrom, ClassDeclaration *cdto)
{
    if (cdto->objc.objc)
    {   // casting from objc type to objc type, use objc function
        if (cdto->isInterfaceDeclaration())
            rtl = RTLSYM_INTERFACE_CAST_OBJC;
        else if (cdfrom->objc.objc)
            rtl = RTLSYM_DYNAMIC_CAST_OBJC;

        return CFnone;
    }
    else
    {
        // casting from objc type to non-objc type, always null
        return CFgoto;
    }

}

ControlFlow objc_toElem_visit_CastExp_Tclass_toObjc()
{
    // casting from non-objc type to objc type, always null
    return CFgoto;
}

void objc_toElem_visit_CastExp_Tclass_fromObjcToObjcInterface(int &rtl)
{
    rtl = RTLSYM_INTERFACE_CAST_OBJC;
}

void objc_toElem_visit_CastExp_Tclass_assertNoOffset(int offset, ClassDeclaration *cdfrom)
{
    if (cdfrom->objc.objc)
        assert(offset == 0); // no offset for Objective-C objects/interfaces
}

ControlFlow objc_toElem_visit_CastExp_Tclass_toObjcCall(elem *&e, int rtl, ClassDeclaration *cdto)
{
    if (cdto->objc.objc)
    {
        elem *esym;
        if (cdto->isInterfaceDeclaration())
            esym = el_ptr(ObjcSymbols::getProtocolSymbol(cdto));
        else
            esym = el_var(ObjcSymbols::getClassReference(cdto));

        elem *ep = el_param(esym, e);
        e = el_bin(OPcall, TYnptr, el_var(rtlsym[rtl]), ep);
        return CFgoto;
    }

    return CFnone;
}

elem *objc_toElem_visit_ObjcDotClassExp(IRState *irs, ObjcDotClassExp *odce)
{
    elem *e = toElem(odce->e1, irs);
    if (!odce->noop)
    {
        TypeFunction *tf = new TypeFunction(NULL, odce->type, 0, LINKobjc);
        FuncDeclaration *fd = new FuncDeclaration(Loc(), Loc(), NULL, STCstatic, tf);
        fd->protection = PROTpublic;
        fd->linkage = LINKobjc;
        fd->objc.selector = ObjcSelector::lookup("class", 5, 0);

        Expression *ef = new VarExp(Loc(), fd);
        Expression *ec = new CallExp(odce->loc, ef);
        e = toElem(ec, irs);
    }
    return e;
}

elem *objc_toElem_visit_ObjcClassRefExp(ObjcClassRefExp *ocre)
{
    return el_var(ObjcSymbols::getClassReference(ocre->cdecl));
}

elem *objc_toElem_visit_ObjcProtocolOfExp(ObjcProtocolOfExp *e)
{
    return el_ptr(ObjcSymbols::getProtocolSymbol(e->idecl));
}