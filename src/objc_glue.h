
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_glue.h
 */

#ifndef DMD_OBJC_GLUE_H
#define DMD_OBJC_GLUE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

enum ObjcSegment
{
    SEGcat_inst_meth,
    SEGcat_cls_meth,
    SEGstring_object,
    SEGcstring_object,
    SEGmessage_refs,
    SEGsel_fixup,
    SEGcls_refs,
    SEGclass,
    SEGmeta_class,
    SEGcls_meth,
    SEGinst_meth,
    SEGprotocol,
    SEGcstring,
    SEGustring,
    SEGcfstring,
    SEGcategory,
    SEGclass_vars,
    SEGinstance_vars,
    SEGmodule_info,
    SEGsymbols,
    SEGprotocol_ext,
    SEGclass_ext,
    SEGproperty,
    SEGimage_info,
    SEGmethname,
    SEGmethtype,
    SEGclassname,
    SEGselrefs,
    SEGobjc_const,
    SEGobjc_ivar,
    SEGobjc_protolist,
    SEG_MAX
};

void error (const char* format, ...);
char *prefixSymbolName(const char *name, size_t name_len, const char *prefix, size_t prefix_len);
int objc_getsegment(ObjcSegment segid);

#endif /* DMD_OBJC_GLUE_H */
