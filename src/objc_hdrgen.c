
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_hdrgen.c
 */

#include "aggregate.h"
#include "declaration.h"
#include "objc.h"
#include "outbuffer.h"

// MARK: toCBuffer

void objc_toCBuffer_visit_ObjcSelectorExp(OutBuffer *buf, ObjcSelectorExp *e)
{
    buf->writeByte('&');
    if (e->func)
        buf->writestring(e->func->toChars());
    else
        buf->writestring(e->selname);
}

void objc_toCBuffer_visit_ObjcDotClassExp(OutBuffer *buf, HdrGenState *hgs, ObjcDotClassExp *e)
{
    toCBuffer(e->e1, buf, hgs);
    buf->writestring(".class");
}

void objc_toCBuffer_visit_ObjcClassRefExp(OutBuffer *buf, ObjcClassRefExp *e)
{
    buf->writestring(e->cdecl->objc.ident->string);
    buf->writestring(".class");
}

void objc_toCBuffer_visit_ObjcProtocolOfExp(OutBuffer *buf, HdrGenState *hgs, ObjcProtocolOfExp *e)
{
    toCBuffer(e->e1, buf, hgs);
    buf->writestring(".protocolof");
}
