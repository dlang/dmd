
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
#include "dt.h"
#include "el.h"
#include "global.h"
#include "mtype.h"
#include "objc.h"
#include "oper.h"
#include "type.h"

elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);

// MARK: ObjcSymbols

Symbol *ObjcSymbols::getFunction(const char* name)
{
    return getGlobal(name, type_fake(TYhfunc));
}

Symbol *ObjcSymbols::getMsgSend(Type *ret, int hasHiddenArg)
{
    if (hasHiddenArg)
    {   if (!msgSend_stret)
        msgSend_stret = symbol_name("_objc_msgSend_stret", SCglobal, type_fake(TYhfunc));
        return msgSend_stret;
    }
    else if (ret->isfloating())
    {   if (!msgSend_fpret)
        msgSend_fpret = symbol_name("_objc_msgSend_fpret", SCglobal, type_fake(TYnfunc));
        return msgSend_fpret;
    }
    else
    {   if (!msgSend)
        msgSend = symbol_name("_objc_msgSend", SCglobal, type_fake(TYnfunc));
        return msgSend;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getMsgSendSuper(int hasHiddenArg)
{
    if (hasHiddenArg)
    {   if (!msgSendSuper_stret)
        msgSendSuper_stret = symbol_name("_objc_msgSendSuper_stret", SCglobal, type_fake(TYhfunc));
        return msgSendSuper_stret;
    }
    else
    {   if (!msgSendSuper)
        msgSendSuper = symbol_name("_objc_msgSendSuper", SCglobal, type_fake(TYnfunc));
        return msgSendSuper;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getMsgSendFixup(Type* returnType, bool hasHiddenArg)
{
    if (hasHiddenArg)
    {
        if (!msgSend_stret_fixup)
            msgSend_stret_fixup = getFunction("_objc_msgSend_stret_fixup");
        return msgSend_stret_fixup;
    }
    else if (returnType->isfloating())
    {
        if (!msgSend_fpret_fixup)
            msgSend_fpret_fixup = getFunction("_objc_msgSend_fpret_fixup");
        return msgSend_fpret_fixup;
    }
    else
    {
        if (!msgSend_fixup)
            msgSend_fixup = getFunction("_objc_msgSend_fixup");
        return msgSend_fixup;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getStringLiteralClassRef()
{
    if (!stringLiteralClassRef)
        stringLiteralClassRef = symbol_name("___CFConstantStringClassReference", SCglobal, type_fake(TYnptr));
    return stringLiteralClassRef;
}

Symbol *ObjcSymbols::getUString(const void *str, size_t len, const char *symbolName)
{
    hassymbols = 1;

    // create data
    dt_t *dt = NULL;
    dtnbytes(&dt, (len + 1)*2, (const char *)str);

    // find segment
    int seg = objc_getsegment(SEGustring);

    // create symbol
    Symbol *s;
    s = symbol_name(symbolName, SCstatic, type_allocn(TYarray, tschar));
    s->Sdt = dt;
    s->Sseg = seg;
    return s;
}

Symbol *ObjcSymbols::getClassReference(ClassDeclaration* cdecl)
{
    hassymbols = 1;
    const char* s = cdecl->objc.ident->string;
    size_t len = cdecl->objc.ident->len;

    StringValue *sv = sclassreftable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        // create data
        dt_t *dt = NULL;
        Symbol *sclsname = getClassName(cdecl);
        dtxoff(&dt, sclsname, 0, TYnptr);

        // find segment for class references
        int seg = objc_getsegment(SEGcls_refs);

        static size_t classrefcount = 0;
        const char* prefix = global.params.isObjcNonFragileAbi ? "L_OBJC_CLASSLIST_REFERENCES_$_" : "L_OBJC_CLASS_REFERENCES_%lu";

        char namestr[42];
        sprintf(namestr, prefix, classrefcount++);
        sy = symbol_name(namestr, SCstatic, type_fake(TYnptr));
        sy->Sdt = dt;
        sy->Sseg = seg;
        outdata(sy);

        sv->ptrvalue = sy;
    }
    return sy;
}

Symbol *ObjcSymbols::getMethVarRef(const char *s, size_t len)
{
    hassymbols = 1;

    StringValue *sv = smethvarreftable->update(s, len);
    Symbol *refsymbol = (Symbol *) sv->ptrvalue;
    if (refsymbol == NULL)
    {
        // create data
        dt_t *dt = NULL;
        Symbol *sselname = getMethVarName(s, len);
        dtxoff(&dt, sselname, 0*0x9877660, TYnptr);

        // find segment
        int seg = objc_getsegment(SEGselrefs);

        // create symbol
        static size_t selcount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_SELECTOR_REFERENCES_%lu", selcount);
        refsymbol = symbol_name(namestr, SCstatic, type_fake(TYnptr));

        refsymbol->Sdt = dt;
        refsymbol->Sseg = seg;
        outdata(refsymbol);
        sv->ptrvalue = refsymbol;

        ++selcount;
    }
    return refsymbol;
}

Symbol *ObjcSymbols::getMethVarRef(Identifier *ident)
{
    return getMethVarRef(ident->string, ident->len);
}

Symbol *ObjcSymbols::getMessageReference(ObjcSelector* selector, Type* returnType, bool hasHiddenArg)
{
    assert(selector->usesVTableDispatch());
    hassymbols = 1;

    Symbol* msgSendFixup = ObjcSymbols::getMsgSendFixup(returnType, hasHiddenArg);
    Symbol* selectorSymbol = getMethVarName(selector->stringvalue, selector->stringlen);
    size_t msgSendFixupLength = strlen(msgSendFixup->Sident);
    size_t fixupSelectorLength = 0;
    const char* fixupSelector = ObjcSelectorBuilder::fixupSelector(selector, msgSendFixup->Sident, msgSendFixupLength, &fixupSelectorLength);

    StringValue *sv = smethvarreftable->update(fixupSelector, fixupSelectorLength);
    Symbol *refsymbol = (Symbol *) sv->ptrvalue;
    if (refsymbol == NULL)
    {
        // create data
        dt_t* dt = NULL;
        dtxoff(&dt, msgSendFixup, 0, TYnptr);
        dtxoff(&dt, selectorSymbol, 0, TYnptr);

        // find segment
        int segment = objc_getsegment(SEGmessage_refs);

        // create symbol
        refsymbol = symbol_name(fixupSelector, SCstatic, type_fake(TYnptr));
        refsymbol->Sdt = dt;
        refsymbol->Sseg = segment;
        refsymbol->Salignment = 16;
        outdata(refsymbol);
        sv->ptrvalue = refsymbol;
    }
    return refsymbol;
}

Symbol *ObjcSymbols::getStringLiteral(const void *str, size_t len, size_t sz)
{
    hassymbols = 1;

    // Objective-C NSString literal (also good for CFString)
    static size_t strcount = 0;
    char namestr[24];
    sprintf(namestr, "l_.str%lu", strcount);
    Symbol *sstr;
    if (sz == 1)
        sstr = getCString((const char *)str, len, namestr);
    else
        sstr = getUString(str, len, namestr);

    dt_t *dt = NULL;
    dtxoff(&dt, getStringLiteralClassRef(), 0, TYnptr);
    dtdword(&dt, sz == 1 ? 1992 : 2000);

    if (global.params.isObjcNonFragileAbi)
        dtdword(&dt, 0); // .space 4

    dtxoff(&dt, sstr, 0, TYnptr);
    dtsize_t(&dt, len);

    sprintf(namestr, "L__unnamed_cfstring_%lu", strcount++);
    Symbol *si = symbol_name(namestr, SCstatic, type_fake(TYnptr));
    si->Sdt = dt;
    si->Sseg = objc_getsegment(SEGcfstring);
    outdata(si);
    return si;
}

// MARK: ObjcSelector

Symbol *ObjcSelector::toRefSymbol()
{
    return ObjcSymbols::getMethVarRef(stringvalue, stringlen);
}

elem *ObjcSelector::toElem()
{
    return el_var(toRefSymbol());
}

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