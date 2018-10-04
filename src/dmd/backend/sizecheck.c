/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/sizecheck.c, backend/sizecheck.c)
 */

// Configure the back end (optimizer and code generator)

#include        <stdio.h>
#include        <ctype.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "global.h"
#include        "oper.h"
#include        "code.h"
#include        "type.h"
#include        "dt.h"
#include        "cgcv.h"


// cc.d
unsigned Srcpos::sizeCheck() { return sizeof(Srcpos); }
unsigned Pstate::sizeCheck() { return sizeof(Pstate); }
unsigned Cstate::sizeCheck() { return sizeof(Cstate); }
unsigned Blockx::sizeCheck() { return sizeof(Blockx); }
unsigned block::sizeCheck()  { return sizeof(block);  }
unsigned func_t::sizeCheck() { return sizeof(func_t); }
unsigned baseclass_t::sizeCheck() { return sizeof(baseclass_t); }
unsigned template_t::sizeCheck() { return sizeof(template_t); }
unsigned struct_t::sizeCheck() { return sizeof(struct_t); }
unsigned Symbol::sizeCheck() { return sizeof(Symbol); }
unsigned param_t::sizeCheck() { return sizeof(param_t); }
unsigned Declar::sizeCheck() { return sizeof(Declar); }
unsigned dt_t::sizeCheck() { return sizeof(dt_t); }

// cdef.d
unsigned Config::sizeCheck() { return sizeof(Config); }
unsigned Configv::sizeCheck() { return sizeof(Configv); }
unsigned eve::sizeCheck() { return sizeof(eve); }

// el.d

// type.d
unsigned TYPE::sizeCheck() { return sizeof(type); }
