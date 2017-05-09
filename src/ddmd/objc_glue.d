
/* Compiler implementation of the D programming language
 * Copyright (c) 2015 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/_objc_glue.d
 */

module ddmd.objc_glue;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import ddmd.aggregate;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.func;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.objc;

import ddmd.root.stringtable;

import ddmd.backend.dt;
import ddmd.backend.cc;
import ddmd.backend.cdef;
import ddmd.backend.el;
import ddmd.backend.global;
import ddmd.backend.oper;
import ddmd.backend.outbuf;
import ddmd.backend.ty;
import ddmd.backend.type;
import ddmd.backend.mach;
import ddmd.backend.obj;

extern (C++):

enum ObjcSegment
{
    SEGcstring,
    SEGimage_info,
    SEGmethname,
    SEGmodule_info,
    SEGselrefs,
    SEG_MAX,
}

elem *addressElem(elem *e, Type t, bool alwaysCopy = false);

__gshared int[ObjcSegment.SEG_MAX] objc_segList;

int objc_getSegment(ObjcSegment segid)
{
    int *seg = objc_segList.ptr;
    if (seg[segid] != 0)
        return seg[segid];

    // initialize
    int _align = 3;

    with (ObjcSegment)
    {
        seg[SEGcstring] = MachObj.getsegment("__cstring", "__TEXT", _align, S_CSTRING_LITERALS);
        seg[SEGimage_info] = MachObj.getsegment("__objc_imageinfo", "__DATA", _align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGmethname] = MachObj.getsegment("__objc_methname", "__TEXT", _align, S_CSTRING_LITERALS);
        seg[SEGmodule_info] = MachObj.getsegment("__objc_classlist", "__DATA", _align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGselrefs] = MachObj.getsegment("__objc_selrefs", "__DATA", _align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
    }

    return seg[segid];
}

// MARK: ObjcSymbols

__gshared
{
    bool objc_hasSymbols = false;

    Symbol *objc_smsgSend = null;
    Symbol *objc_smsgSend_stret = null;
    Symbol *objc_smsgSend_fpret = null;
    Symbol *objc_smsgSend_fp2ret = null;

    Symbol *objc_simageInfo = null;
    Symbol *objc_smoduleInfo = null;

    StringTable *objc_smethVarNameTable = null;
    StringTable *objc_smethVarRefTable = null;
}

static StringTable *initStringTable(StringTable *stringtable)
{
    stringtable = new StringTable();
    stringtable._init();

    return stringtable;
}

void objc_initSymbols()
{
    objc_hasSymbols = false;

    objc_smsgSend = null;
    objc_smsgSend_stret = null;
    objc_smsgSend_fpret = null;
    objc_smsgSend_fp2ret = null;

    objc_simageInfo = null;
    objc_smoduleInfo = null;

    // clear tables
    objc_smethVarNameTable = initStringTable(objc_smethVarNameTable);
    objc_smethVarRefTable = initStringTable(objc_smethVarRefTable);

    // also wipe out segment numbers
    for (int s = 0; s < ObjcSegment.SEG_MAX; ++s)
        objc_segList[s] = 0;
}

Symbol *objc_getCString(const(char)* str, size_t len, const(char)* symbolName, ObjcSegment segment)
{
    objc_hasSymbols = true;

    // create data
    scope dtb = new DtBuilder();
    dtb.nbytes(cast(uint)(len + 1), str);

    // find segment
    int seg = objc_getSegment(segment);

    // create symbol
    Symbol *s;
    s = symbol_name(symbolName, SCstatic, type_allocn(TYarray, tstypes[TYchar]));
    s.Sdt = dtb.finish();
    s.Sseg = seg;
    return s;
}

Symbol *objc_getMethVarName(const(char)* s, size_t len)
{
    objc_hasSymbols = true;

    StringValue *sv = objc_smethVarNameTable.update(s, len);
    Symbol *sy = cast(Symbol *) sv.ptrvalue;
    if (!sy)
    {
        __gshared size_t classnamecount = 0;
        char[42] namestr;
        sprintf(namestr.ptr, "L_OBJC_METH_VAR_NAME_%lu", classnamecount++);
        sy = objc_getCString(s, len, namestr.ptr, ObjcSegment.SEGmethname);
        sv.ptrvalue = sy;
    }
    return sy;
}

Symbol *objc_getMethVarName(Identifier *ident)
{
    const char* id = ident.toChars();
    return objc_getMethVarName(id, strlen(id));
}

Symbol *objc_getMsgSend(Type ret, bool hasHiddenArg)
{
    if (hasHiddenArg)
    {
        if (!objc_smsgSend_stret)
            objc_smsgSend_stret = symbol_name("_objc_msgSend_stret", SCglobal, type_fake(TYhfunc));
        return objc_smsgSend_stret;
    }
    // not sure if DMD can handle this
    else if (ret.ty == Tcomplex80)
    {
         if (!objc_smsgSend_fp2ret)
             objc_smsgSend_fp2ret = symbol_name("_objc_msgSend_fp2ret", SCglobal, type_fake(TYnfunc));
         return objc_smsgSend_fp2ret;
    }
    else if (ret.ty == Tfloat80)
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
}

Symbol *objc_getImageInfo()
{
    if (objc_simageInfo)
        return objc_simageInfo;

    objc_hasSymbols = true;

    scope dtb = new DtBuilder();
    dtb.dword(0); // version
    dtb.dword(0); // flags

    objc_simageInfo = symbol_name("L_OBJC_IMAGE_INFO", SCstatic, type_allocn(TYarray, tstypes[TYchar]));
    objc_simageInfo.Sdt = dtb.finish();
    objc_simageInfo.Sseg = objc_getSegment(ObjcSegment.SEGimage_info);
    outdata(objc_simageInfo);

    return objc_simageInfo;
}

Symbol *objc_getModuleInfo()
{
    assert(!objc_smoduleInfo); // only allow once per object file
    objc_hasSymbols = true;

    scope dtb = new DtBuilder();

    Symbol* symbol = symbol_name("L_OBJC_LABEL_CLASS_$", SCstatic, type_allocn(TYarray, tstypes[TYchar]));
    symbol.Sdt = dtb.finish();
    symbol.Sseg = objc_getSegment(ObjcSegment.SEGmodule_info);
    outdata(symbol);

    objc_getImageInfo(); // make sure we also generate image info

    return objc_smoduleInfo;
}

// MARK: Module.genmoduleinfo

void objc_Module_genmoduleinfo_classes()
{
    if (objc_hasSymbols)
        objc_getModuleInfo();
}

// MARK: ObjcSelector

Symbol *objc_getMethVarRef(const(char)* s, size_t len)
{
    objc_hasSymbols = true;

    StringValue *sv = objc_smethVarRefTable.update(s, len);
    Symbol *refsymbol = cast(Symbol *) sv.ptrvalue;
    if (refsymbol == null)
    {
        // create data
        scope dtb = new DtBuilder();
        Symbol *sselname = objc_getMethVarName(s, len);
        dtb.xoff(sselname, 0, TYnptr);

        // find segment
        int seg = objc_getSegment(ObjcSegment.SEGselrefs);

        // create symbol
        __gshared size_t selcount = 0;
        char[42] namestr;
        sprintf(namestr.ptr, "L_OBJC_SELECTOR_REFERENCES_%lu", selcount);
        refsymbol = symbol_name(namestr.ptr, SCstatic, type_fake(TYnptr));

        refsymbol.Sdt = dtb.finish();
        refsymbol.Sseg = seg;
        outdata(refsymbol);
        sv.ptrvalue = refsymbol;

        ++selcount;
    }
    return refsymbol;
}

Symbol *objc_getMethVarRef(Identifier ident)
{
    auto id = ident.toChars();
    return objc_getMethVarRef(id, strlen(id));
}

// MARK: callfunc

void objc_callfunc_setupMethodSelector(Type tret, FuncDeclaration fd, Type t, elem *ehidden, elem **esel)
{
    if (fd && fd.selector && !*esel)
    {
        *esel = el_var(objc_getMethVarRef(fd.selector.stringvalue, fd.selector.stringlen));
    }
}

void objc_callfunc_setupMethodCall(elem **ec, elem *ehidden, elem *ethis, TypeFunction tf)
{
    // make objc-style "virtual" call using dispatch function
    assert(ethis);
    Type tret = tf.next;
    *ec = el_var(objc_getMsgSend(tret, ehidden !is null));
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
