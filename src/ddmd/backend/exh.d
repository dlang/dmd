/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1993-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/exh.d
 */

module ddmd.backend.exh;

import ddmd.backend.cc;
import ddmd.backend.cdef;
import ddmd.backend.el;
import ddmd.backend.type;

extern (C++):
@nogc:
nothrow:

struct Aobject
{
    Symbol *AOsym;              // Symbol for active object
    targ_size_t AOoffset;       // offset from that object
    Symbol *AOfunc;             // cleanup function
}


/* except.c */
void  except_init();
void  except_term();
elem *except_obj_ctor(elem *e,Symbol *s,targ_size_t offset,Symbol *sdtor);
elem *except_obj_dtor(elem *e,Symbol *s,targ_size_t offset);
elem *except_throw_expression();
type *except_declaration(Symbol *cv);
void  except_exception_spec(type *t);
void  except_index_set(int index);
int   except_index_get();
void  except_pair_setoffset(void *p,targ_size_t offset);
void  except_pair_append(void *p, int index);
void  except_push(void *p,elem *e,block *b);
void  except_pop(void *p,elem *e,block *b);
void  except_mark();
void  except_release();
Symbol *except_gensym();
Symbol *except_gentables();
void except_fillInEHTable(Symbol *s);
void  except_reset();

/* pdata.c */
void win64_pdata(Symbol *sf);

