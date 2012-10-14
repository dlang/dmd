
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include        <stdio.h>
#include        <string.h>
#include        <stddef.h>

#include        "mars.h"

#include        "cc.h"
#include        "global.h"
#include        "oper.h"
#include        "code.h"
#include        "type.h"
#include        "dt.h"
#include        "cgcv.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

extern void ph_init();

extern Global global;
extern int REALSIZE;

Config config;
Configv configv;

struct Environment;

/**************************************
 * Initialize config variables.
 */

void out_config_init()
{
    //printf("out_config_init()\n");
    Param *params = &global.params;

    if (!config.target_cpu)
    {   config.target_cpu = TARGET_PentiumPro;
        config.target_scheduler = config.target_cpu;
    }
    config.fulltypes = CVNONE;
    config.fpxmmregs = FALSE;
    config.inline8087 = 1;
    config.memmodel = 0;
    config.flags |= CFGuchar;   // make sure TYchar is unsigned
    tytab[TYchar] |= TYFLuns;
#if TARGET_WINDOS
    if (params->is64bit)
    {   config.exe = EX_WIN64;
        config.fpxmmregs = TRUE;

        // Not sure we really need these two lines, try removing them later
        config.flags |= CFGnoebp;
        config.flags |= CFGalwaysframe;
    }
    else
    {   config.exe = EX_NT;
        config.flags2 |= CFG2seh;       // Win32 eh
    }

    if (params->run)
        config.wflags |= WFexe;         // EXE file only optimizations
    else if (params->link && !global.params.deffile)
        config.wflags |= WFexe;         // EXE file only optimizations
    else if (params->exefile)           // if writing out EXE file
    {   size_t len = strlen(params->exefile);
        if (len >= 4 && stricmp(params->exefile + len - 3, "exe") == 0)
            config.wflags |= WFexe;
    }
    config.flags4 |= CFG4underscore;
#endif
#if TARGET_LINUX
    if (params->is64bit)
    {   config.exe = EX_LINUX64;
        config.fpxmmregs = TRUE;
    }
    else
        config.exe = EX_LINUX;
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (params->pic)
        config.flags3 |= CFG3pic;
#endif
#if TARGET_OSX
    config.fpxmmregs = TRUE;
    if (params->is64bit)
    {   config.exe = EX_OSX64;
        config.fpxmmregs = TRUE;
    }
    else
        config.exe = EX_OSX;
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (params->pic)
        config.flags3 |= CFG3pic;
#endif
#if TARGET_FREEBSD
    if (params->is64bit)
    {   config.exe = EX_FREEBSD64;
        config.fpxmmregs = TRUE;
    }
    else
        config.exe = EX_FREEBSD;
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (params->pic)
        config.flags3 |= CFG3pic;
#endif
#if TARGET_OPENBSD
    if (params->is64bit)
    {   config.exe = EX_OPENBSD64;
        config.fpxmmregs = TRUE;
    }
    else
        config.exe = EX_OPENBSD;
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (params->pic)
        config.flags3 |= CFG3pic;
#endif
#if TARGET_SOLARIS
    if (params->is64bit)
    {   config.exe = EX_SOLARIS64;
        config.fpxmmregs = TRUE;
    }
    else
        config.exe = EX_SOLARIS;
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (params->pic)
        config.flags3 |= CFG3pic;
#endif
    config.flags2 |= CFG2nodeflib;      // no default library
    config.flags3 |= CFG3eseqds;
#if 0
    if (env->getEEcontext()->EEcompile != 2)
        config.flags4 |= CFG4allcomdat;
    if (env->nochecks())
        config.flags4 |= CFG4nochecks;  // no runtime checking
#elif TARGET_OSX
#else
    config.flags4 |= CFG4allcomdat;
#endif
    if (params->trace)
        config.flags |= CFGtrace;       // turn on profiler
    if (params->nofloat)
        config.flags3 |= CFG3wkfloat;

    configv.verbose = params->verbose;

    if (params->optimize)
        go_flag((char *)"-o");

    if (params->symdebug)
    {
#if SYMDEB_DWARF
        configv.addlinenumbers = 1;
        config.fulltypes = (params->symdebug == 1) ? CVDWARF_D : CVDWARF_C;
#endif
#if SYMDEB_CODEVIEW
        if (params->is64bit)
        {
        }
        else
        {
        configv.addlinenumbers = 1;
        config.fulltypes = CV4;
        }
#endif
        if (!params->optimize)
            config.flags |= CFGalwaysframe;
    }
    else
    {
        configv.addlinenumbers = 0;
        config.fulltypes = CVNONE;
        //config.flags &= ~CFGalwaysframe;
    }

    if (params->alwaysframe)
        config.flags &= ~CFGalwaysframe;

#ifdef DEBUG
    debugb = params->debugb;
    debugc = params->debugc;
    debugf = params->debugf;
    debugr = params->debugr;
    debugw = params->debugw;
    debugx = params->debugx;
    debugy = params->debugy;
#endif
}

/*******************************
 * Redo tables from 8086/286 to ILP32
 */

void util_set32()
{
    _tyrelax[TYenum] = TYlong;
    _tyrelax[TYint]  = TYlong;
    _tyrelax[TYuint] = TYlong;

    tyequiv[TYint] = TYlong;
    tyequiv[TYuint] = TYulong;

    for (int i = 0; i < 1; ++i)
    {   tysize[TYenum + i] = LONGSIZE;
        tysize[TYint  + i] = LONGSIZE;
        tysize[TYuint + i] = LONGSIZE;
        tysize[TYjhandle + i] = LONGSIZE;
        tysize[TYnptr + i] = LONGSIZE;
        tysize[TYnref + i] = LONGSIZE;
    }

    for (int i = 0; i < 1; ++i)
    {   tyalignsize[TYenum + i] = LONGSIZE;
        tyalignsize[TYint  + i] = LONGSIZE;
        tyalignsize[TYuint + i] = LONGSIZE;
        tyalignsize[TYnullptr + i] = LONGSIZE;
        tyalignsize[TYnptr + i] = LONGSIZE;
        tyalignsize[TYnref + i] = LONGSIZE;
    }
}

/*******************************
 * Redo tables from 8086/286 to LP64.
 */

void util_set64()
{
    _tyrelax[TYenum] = TYlong;
    _tyrelax[TYint]  = TYlong;
    _tyrelax[TYuint] = TYlong;

    tyequiv[TYint] = TYlong;
    tyequiv[TYuint] = TYulong;

    for (int i = 0; i < 1; ++i)
    {   tysize[TYenum + i] = LONGSIZE;
        tysize[TYint  + i] = LONGSIZE;
        tysize[TYuint + i] = LONGSIZE;
        tysize[TYjhandle + i] = 8;
        tysize[TYnptr + i] = 8;
        tysize[TYnref + i] = 8;
        tysize[TYldouble + i] = REALSIZE;
        tysize[TYildouble + i] = REALSIZE;
        tysize[TYcldouble + i] = 2 * REALSIZE;

        tyalignsize[TYenum + i] = LONGSIZE;
        tyalignsize[TYint  + i] = LONGSIZE;
        tyalignsize[TYuint + i] = LONGSIZE;
        tyalignsize[TYnullptr + i] = 8;
        tyalignsize[TYjhandle + i] = 8;
        tyalignsize[TYnptr + i] = 8;
        tyalignsize[TYnref + i] = 8;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS || TARGET_OSX || TARGET_WINDOS
        tyalignsize[TYldouble + i] = 16;
        tyalignsize[TYildouble + i] = 16;
        tyalignsize[TYcldouble + i] = 16;
#else
        assert(0);
#endif
        tytab[TYjfunc + i] &= ~TYFLpascal;  // set so caller cleans the stack (as in C)
    }

    TYptrdiff = TYllong;
    TYsize = TYullong;
    TYsize_t = TYullong;
}

/***********************************
 * Return aligned 'offset' if it is of size 'size'.
 */

targ_size_t align(targ_size_t size, targ_size_t offset)
{
    switch (size)
    {
        case 1:
            break;
        case 2:
        case 4:
        case 8:
            offset = (offset + size - 1) & ~(size - 1);
            break;
        default:
            if (size >= 16)
                offset = (offset + 15) & ~15;
            else
                offset = (offset + REGSIZE - 1) & ~(REGSIZE - 1);
            break;
    }
    return offset;
}

/*******************************
 * Get size of ty
 */

targ_size_t size(tym_t ty)
{
    int sz = (tybasic(ty) == TYvoid) ? 1 : tysize(ty);
#ifdef DEBUG
    if (sz == -1)
        WRTYxx(ty);
#endif
    assert(sz!= -1);
    return sz;
}

/*******************************
 * Replace (e) with ((stmp = e),stmp)
 */

elem *exp2_copytotemp(elem *e)
{
    //printf("exp2_copytotemp()\n");
    elem_debug(e);
    Symbol *stmp = symbol_genauto(e);
    elem *eeq = el_bin(OPeq,e->Ety,el_var(stmp),e);
    elem *er = el_bin(OPcomma,e->Ety,eeq,el_var(stmp));
    if (tybasic(e->Ety) == TYstruct || tybasic(e->Ety) == TYarray)
    {
        eeq->Eoper = OPstreq;
        eeq->ET = e->ET;
        eeq->E1->ET = e->ET;
        er->ET = e->ET;
        er->E2->ET = e->ET;
    }
    return er;
}

/****************************
 * Generate symbol of type ty at DATA:offset
 */

symbol *symboldata(targ_size_t offset,tym_t ty)
{
    symbol *s = symbol_generate(SClocstat, type_fake(ty));
    s->Sfl = FLdata;
    s->Soffset = offset;
    symbol_keep(s);             // keep around
    return s;
}

/************************************
 * Add symbol to slist.
 */

static list_t slist;

void slist_add(Symbol *s)
{
    list_prepend(&slist,s);
}

/*************************************
 */

void slist_reset()
{
    //printf("slist_reset()\n");
    for (list_t sl = slist; sl; sl = list_next(sl))
    {   Symbol *s = list_symbol(sl);

#if MACHOBJ
        s->Soffset = 0;
#endif
        s->Sxtrnnum = 0;
        s->Stypidx = 0;
        s->Sflags &= ~(STRoutdef | SFLweak);
        if (s->Sclass == SCglobal || s->Sclass == SCcomdat ||
            s->Sfl == FLudata || s->Sclass == SCstatic)
        {   s->Sclass = SCextern;
            s->Sfl = FLextern;
        }
    }
}


/**************************************
 */

void backend_init()
{
    ph_init();
    block_init();

    cod3_setdefault();
    if (global.params.is64bit)
    {
        util_set64();
        type_init();
        cod3_set64();
    }
    else
    {
        util_set32();
        type_init();
        cod3_set32();
    }

    rtlsym_init(); // uses fregsaved, so must be after it's set inside cod3_set*

    out_config_init();
}

void backend_term()
{
}
