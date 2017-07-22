
/* Compiler implementation of the D programming language
 * Copyright (c) 2015 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_glue.c
 */

#include <stdlib.h>
#include <string.h>

#include "aggregate.h"
#include "declaration.h"
#include "dt.h"
#include "cc.h"
#include "el.h"
#include "global.h"
#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "objc.h"
#include "oper.h"
#include "outbuf.h"
#include "type.h"

#include "mach.h"
#include "obj.h"

enum ObjcSegment
{
    SEGcstring,
    SEGimage_info,
    SEGmethname,
    SEGmodule_info,
    SEGselrefs,
    SEG_MAX
};

elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);

int objc_segList[SEG_MAX] = {0};

int objc_getSegment(ObjcSegment segid)
{
    int *seg = objc_segList;
    if (seg[segid] != 0)
        return seg[segid];

    // initialize
    int align = 3;

    seg[SEGcstring] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
    seg[SEGimage_info] = MachObj::getsegment("__objc_imageinfo", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
    seg[SEGmethname] = MachObj::getsegment("__objc_methname", "__TEXT", align, S_CSTRING_LITERALS);
    seg[SEGmodule_info] = MachObj::getsegment("__objc_classlist", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
    seg[SEGselrefs] = MachObj::getsegment("__objc_selrefs", "__DATA", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);

    return seg[segid];
}

// MARK: ObjcSymbols

bool objc_hasSymbols = false;

Symbol *objc_smsgSend = NULL;
Symbol *objc_smsgSend_stret = NULL;
Symbol *objc_smsgSend_fpret = NULL;
Symbol *objc_smsgSend_fp2ret = NULL;

Symbol *objc_simageInfo = NULL;
Symbol *objc_smoduleInfo = NULL;

StringTable *objc_smethVarNameTable = NULL;
StringTable *objc_smethVarRefTable = NULL;

static StringTable *initStringTable(StringTable *stringtable)
{
    stringtable = new StringTable();
    stringtable->_init();

    return stringtable;
}

extern int objc_segList[SEG_MAX];

void objc_initSymbols()
{
    objc_hasSymbols = false;

    objc_smsgSend = NULL;
    objc_smsgSend_stret = NULL;
    objc_smsgSend_fpret = NULL;
    objc_smsgSend_fp2ret = NULL;

    objc_simageInfo = NULL;
    objc_smoduleInfo = NULL;

    // clear tables
    objc_smethVarNameTable = initStringTable(objc_smethVarNameTable);
    objc_smethVarRefTable = initStringTable(objc_smethVarRefTable);

    // also wipe out segment numbers
    for (int s = 0; s < SEG_MAX; ++s)
        objc_segList[s] = 0;
}

Symbol *objc_getCString(const char *str, size_t len, const char *symbolName, ObjcSegment segment)
{
    objc_hasSymbols = true;

    // create data
    dt_t *dt = NULL;
    dtnbytes(&dt, len + 1, str);

    // find segment
    int seg = objc_getSegment(segment);

    // create symbol
    Symbol *s;
    s = symbol_name(symbolName, SCstatic, type_allocn(TYarray, tschar));
    s->Sdt = dt;
    s->Sseg = seg;
    return s;
}

Symbol *objc_getMethVarName(const char *s, size_t len)
{
    objc_hasSymbols = true;

    StringValue *sv = objc_smethVarNameTable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        static size_t classnamecount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_METH_VAR_NAME_%lu", classnamecount++);
        sy = objc_getCString(s, len, namestr, SEGmethname);
        sv->ptrvalue = sy;
    }
    return sy;
}

Symbol *objc_getMethVarName(Identifier *ident)
{
    return objc_getMethVarName(ident->string, ident->len);
}

Symbol *objc_getMsgSend(Type *ret, bool hasHiddenArg)
{
    if (hasHiddenArg)
    {
        if (!objc_smsgSend_stret)
            objc_smsgSend_stret = symbol_name("_objc_msgSend_stret", SCglobal, type_fake(TYhfunc));
        return objc_smsgSend_stret;
    }
    // not sure if DMD can handle this
    else if (ret->ty == Tcomplex80)
    {
         if (!objc_smsgSend_fp2ret)
             objc_smsgSend_fp2ret = symbol_name("_objc_msgSend_fp2ret", SCglobal, type_fake(TYnfunc));
         return objc_smsgSend_fp2ret;
    }
    else if (ret->ty == Tfloat80)
    {
        if (!objc_smsgSend_fpret)
            objc_smsgSend_fpret = symbol_name("_objc_msgSend_fpret", SCglobal, type_fake(TYnfunc));
        return objc_smsgSend_fpret;
    }
    else
    {
        if (!objc_smsgSend)
            objc_smsgSend = symbol_name("_objc_msgSend", SCglobal, type_fake(TYnfunc));
        return objc_smsgSend;
    }
    assert(0);
    return NULL;
}

Symbol *objc_getImageInfo()
{
    assert(!objc_simageInfo); // only allow once per object file
    objc_hasSymbols = true;

    dt_t *dt = NULL;
    dtdword(&dt, 0); // version
    dtdword(&dt, 0); // flags

    objc_simageInfo = symbol_name("L_OBJC_IMAGE_INFO", SCstatic, type_allocn(TYarray, tschar));
    objc_simageInfo->Sdt = dt;
    objc_simageInfo->Sseg = objc_getSegment(SEGimage_info);
    outdata(objc_simageInfo);

    return objc_simageInfo;
}

Symbol *objc_getModuleInfo()
{
    assert(!objc_smoduleInfo); // only allow once per object file
    objc_hasSymbols = true;

    dt_t *dt = NULL;

    Symbol* symbol = symbol_name("L_OBJC_LABEL_CLASS_$", SCstatic, type_allocn(TYarray, tschar));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getSegment(SEGmodule_info);
    outdata(symbol);

    objc_getImageInfo(); // make sure we also generate image info

    return objc_smoduleInfo;
}

// MARK: Module::genmoduleinfo

void objc_Module_genmoduleinfo_classes()
{
    if (objc_hasSymbols)
        objc_getModuleInfo();
}

// MARK: ObjcSelector

Symbol *objc_getMethVarRef(const char *s, size_t len)
{
    objc_hasSymbols = true;

    StringValue *sv = objc_smethVarRefTable->update(s, len);
    Symbol *refsymbol = (Symbol *) sv->ptrvalue;
    if (refsymbol == NULL)
    {
        // create data
        dt_t *dt = NULL;
        Symbol *sselname = objc_getMethVarName(s, len);
        dtxoff(&dt, sselname, 0, TYnptr);

        // find segment
        int seg = objc_getSegment(SEGselrefs);

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

Symbol *objc_getMethVarRef(Identifier *ident)
{
    return objc_getMethVarRef(ident->string, ident->len);
}

// MARK: callfunc

void objc_callfunc_setupMethodSelector(Type *tret, FuncDeclaration *fd, Type *t, elem *ehidden, elem **esel)
{
    if (fd && fd->objc.selector && !*esel)
    {
        *esel = el_var(objc_getMethVarRef(fd->objc.selector->stringvalue, fd->objc.selector->stringlen));
    }
}

void objc_callfunc_setupMethodCall(elem **ec, elem *ehidden, elem *ethis, TypeFunction *tf)
{
    // make objc-style "virtual" call using dispatch function
    assert(ethis);
    Type *tret = tf->next;
    *ec = el_var(objc_getMsgSend(tret, ehidden != 0));
}

void objc_callfunc_setupEp(elem *esel, elem **ep, int reverse)
{
    if (esel)
    {
        // using objc-style "virtual" call
        // add hidden argument (second to 'this') for selector used by dispatch function
        if (reverse)
            *ep = el_param(esel,*ep);
        else
            *ep = el_param(*ep,esel);
    }
}
