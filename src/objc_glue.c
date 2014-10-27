
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_glue.c
 */

#include <stdlib.h>
#include <string.h>

#include "declaration.h"
#include "mars.h"
#include "objc_glue.h"
#include "outbuf.h"

#include "cc.h"
#include "mach.h"
#include "obj.h"

// MARK: Utility

void error (const char* format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::error(Loc(), format, ap);
    va_end(ap);
}

// Utility for concatenating names with a prefix
char *prefixSymbolName(const char *name, size_t name_len, const char *prefix, size_t prefix_len)
{
    // Ensure we have a long-enough buffer for the symbol name. Previous buffer is reused.
    static char *sname = NULL;
    static size_t sdim = 0;
    if (name_len + prefix_len + 1 >= sdim)
    {   sdim = name_len + prefix_len + 12;
        sname = (char *)realloc(sname, sdim);
    }

    // Create symbol name L_OBJC_CLASS_PROTOCOLS_<ProtocolName>
    memmove(sname, prefix, prefix_len);
    memmove(sname+prefix_len, name, name_len);
    sname[prefix_len+name_len] = 0;

    return sname;
}

int seg_list[SEG_MAX] = {0};

int objc_getsegment(ObjcSegment segid)
{
    int *seg = seg_list;
    if (seg[segid] != 0)
        return seg[segid];

    // initialize
    int align = 2;

    if (global.params.isObjcNonFragileAbi)
    {
        align = 3;

        seg[SEGselrefs] = MachObj::getsegment("__objc_selrefs", "__DATA", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
        seg[SEGcls_refs] = MachObj::getsegment("__objc_classrefs", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGimage_info] = MachObj::getsegment("__objc_imageinfo", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGmethname] = MachObj::getsegment("__objc_methname", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGmethtype] = MachObj::getsegment("__objc_methtype", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclassname] = MachObj::getsegment("__objc_classname", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclass] = MachObj::getsegment("__objc_data", "__DATA", align, S_REGULAR);
        seg[SEGmeta_class] = MachObj::getsegment("__objc_data", "__DATA", align, S_REGULAR);
        seg[SEGmodule_info] = MachObj::getsegment("__objc_classlist", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGprotocol] = MachObj::getsegment("__datacoal_nt", "__DATA", align, S_COALESCED);
        seg[SEGcat_cls_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_REGULAR);
        seg[SEGcat_inst_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_REGULAR);
        seg[SEGcls_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGinstance_vars] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);

        seg[SEGmessage_refs] = MachObj::getsegment("__objc_msgrefs", "__DATA", align, S_COALESCED);
        seg[SEGobjc_const] = MachObj::getsegment("__objc_const", "__DATA", align, S_REGULAR);
        seg[SEGinst_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGobjc_ivar] = MachObj::getsegment("__objc_ivar", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGobjc_protolist] = MachObj::getsegment("__objc_protolist", "__DATA", align, S_COALESCED | S_ATTR_NO_DEAD_STRIP);
        seg[SEGproperty] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
    }

    else
    {
        seg[SEGselrefs] = MachObj::getsegment("__message_refs", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
        seg[SEGcls_refs] = MachObj::getsegment("__cls_refs", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
        seg[SEGimage_info] = MachObj::getsegment("__image_info", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGmethname] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGmethtype] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclassname] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclass] = MachObj::getsegment("__class", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGmeta_class] = MachObj::getsegment("__meta_class", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGinst_meth] = MachObj::getsegment("__inst_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGmodule_info] = MachObj::getsegment("__module_info", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGprotocol] = MachObj::getsegment("__protocol", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGcat_cls_meth] = MachObj::getsegment("__cat_cls_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGcat_inst_meth] = MachObj::getsegment("__cat_inst_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGproperty] = MachObj::getsegment("__property", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_REGULAR);
        seg[SEGcls_meth] = MachObj::getsegment("__cls_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGinstance_vars] = MachObj::getsegment("__instance_vars", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);

        seg[SEGclass_ext] = MachObj::getsegment("__class_ext", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_REGULAR);
    }

    seg[SEGstring_object] = MachObj::getsegment("__string_object", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcstring_object] = MachObj::getsegment("__cstring_object", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGsel_fixup] = MachObj::getsegment("__sel_fixup", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcstring] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
    seg[SEGustring] = MachObj::getsegment("__ustring", "__TEXT", align, S_REGULAR);
    seg[SEGcfstring] = MachObj::getsegment("__cfstring", "__DATA", align, S_REGULAR);
    seg[SEGcategory] = MachObj::getsegment("__category", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGclass_vars] = MachObj::getsegment("__class_vars", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGsymbols] = MachObj::getsegment("__symbols", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGprotocol_ext] = MachObj::getsegment("__protocol_ext", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    
    return seg[segid];
}

// MARK: toObjFile

void objc_FuncDeclaration_toObjFile_extraArgument(FuncDeclaration *self, size_t &pi)
{
    if (self->objc.selector)
        pi += 1; // Extra arument for Objective-C selector
}

void objc_FuncDeclaration_toObjFile_selfCmd(FuncDeclaration *self, Symbol **params, size_t &pi)
{
    if (self->objc.selector)
    {
        // Need to add Objective-C self and _cmd arguments as last/first parameters
        //        error("Objective-C method ABI not implemented yet.");
        assert(self->objc.vcmd);
        Symbol *sobjccmd = toSymbol(self->objc.vcmd);

        // sthis becomes first parameter
        memmove(params + 1, params, pi * sizeof(params[0]));
        params[0] = sobjccmd;
        pi += 1;
    }
}

// MARK: Module::genobjfile

void objc_Module_genobjfile_initSymbols()
{
    ObjcSymbols::init();
}
