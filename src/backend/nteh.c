// Copyright (C) 1994-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

// Support for NT exception handling

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "dt.h"
#if SCPP
#include        "scope.h"
#endif
#include        "exh.h"

#if !SPP && NTEXCEPTIONS

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

static symbol *s_table;
static symbol *s_context;
static char s_name_context_tag[] = "__nt_context";
static char s_name_context[] = "__context";
static char s_name_ecode[] = "__ecode";

static char text_nt[] =
    "struct __nt_context {"
        "int esp; int info; int prev; int handler; int stable; int sindex; int ebp;"
     "};\n";

// member stable is not used for MARS or C++

int nteh_EBPoffset_sindex()     { return -4; }
int nteh_EBPoffset_prev()       { return -nteh_contextsym_size() + 8; }
int nteh_EBPoffset_info()       { return -nteh_contextsym_size() + 4; }
int nteh_EBPoffset_esp()        { return -nteh_contextsym_size() + 0; }

int nteh_offset_sindex()        { return MARS ? 16 : 20; }
int nteh_offset_sindex_seh()    { return 20; }
int nteh_offset_info()          { return 4; }

/***********************************
 */

unsigned char *nteh_context_string()
{
    if (config.flags2 & CFG2seh)
        return (unsigned char *)text_nt;
    else
        return NULL;
}

/*******************************
 * Get symbol for scope table for current function.
 * Returns:
 *      symbol of table
 */

STATIC symbol *nteh_scopetable()
{   symbol *s;
    type *t;

    if (!s_table)
    {
        t = type_alloc(TYint);
        s = symbol_generate(SCstatic,t);
        s->Sseg = UNKNOWN;
        symbol_keep(s);
        s_table = s;
    }
    return s_table;
}

/*************************************
 */

void nteh_filltables()
{
#if MARS
    symbol *s = s_table;
    symbol_debug(s);
    except_fillInEHTable(s);
#endif
}

/****************************
 * Generate and output scope table.
 * Not called for NTEH C++ exceptions
 */

void nteh_gentables()
{
    symbol *s = s_table;
    symbol_debug(s);
#if MARS
    //except_fillInEHTable(s);
#else
    /* NTEH table for C.
     * The table consists of triples:
     *  parent index
     *  filter address
     *  handler address
     */
    unsigned fsize = 4;             // target size of function pointer
    dt_t **pdt = &s->Sdt;
    int sz = 0;                     // size so far

    for (block *b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BC_try)
        {   dt_t *dt;
            block *bhandler;

            pdt = dtdword(pdt,b->Blast_index);  // parent index

            // If try-finally
            if (list_nitems(b->Bsucc) == 2)
            {
                pdt = dtdword(pdt,0);           // filter address
                bhandler = list_block(list_next(b->Bsucc));
                assert(bhandler->BC == BC_finally);
                // To successor of BC_finally block
                bhandler = list_block(bhandler->Bsucc);
            }
            else // try-except
            {
                bhandler = list_block(list_next(b->Bsucc));
                assert(bhandler->BC == BC_filter);
                pdt = dtcoff(pdt,bhandler->Boffset);    // filter address
                bhandler = list_block(list_next(list_next(b->Bsucc)));
                assert(bhandler->BC == BC_except);
            }
            pdt = dtcoff(pdt,bhandler->Boffset);        // handler address
            sz += 4 + fsize * 2;
        }
    }
    assert(sz != 0);
#endif

    outdata(s);                 // output the scope table
#if MARS
    nteh_framehandler(s);
#endif
    s_table = NULL;
}

/**************************
 * Declare frame variables.
 */

void nteh_declarvars(Blockx *bx)
{   symbol *s;

    //printf("nteh_declarvars()\n");
#if MARS
    if (!(bx->funcsym->Sfunc->Fflags3 & Fnteh)) // if haven't already done it
    {   bx->funcsym->Sfunc->Fflags3 |= Fnteh;
        s = symbol_name(s_name_context,SCbprel,tsint);
        s->Soffset = -5 * 4;            // -6 * 4 for C __try, __except, __finally
        s->Sflags |= SFLfree | SFLnodebug;
        type_setty(&s->Stype,mTYvolatile | TYint);
        symbol_add(s);
        bx->context = s;
    }
#else
    if (!(funcsym_p->Sfunc->Fflags3 & Fnteh))   // if haven't already done it
    {   funcsym_p->Sfunc->Fflags3 |= Fnteh;
        if (!s_context)
            s_context = scope_search(s_name_context_tag,CPP ? SCTglobal : SCTglobaltag);
        symbol_debug(s_context);

        s = symbol_name(s_name_context,SCbprel,s_context->Stype);
        s->Soffset = -6 * 4;            // -5 * 4 for C++
        s->Sflags |= SFLfree;
        symbol_add(s);
        type_setty(&s->Stype,mTYvolatile | TYstruct);

        s = symbol_name(s_name_ecode,SCauto,type_alloc(mTYvolatile | TYint));
        s->Sflags |= SFLfree;
        symbol_add(s);
    }
#endif
}

/**************************************
 * Generate elem that sets the context index into the scope table.
 */

#if MARS
elem *nteh_setScopeTableIndex(Blockx *blx, int scope_index)
{
    elem *e;
    Symbol *s;

    s = blx->context;
    symbol_debug(s);
    e = el_var(s);
    e->EV.sp.Voffset = nteh_offset_sindex();
    return el_bin(OPeq, TYint, e, el_long(TYint, scope_index));
}
#endif


/**********************************
 * Return pointer to context symbol.
 */

symbol *nteh_contextsym()
{   SYMIDX si;
    symbol *sp;

    for (si = 0; 1; si++)
    {   assert(si < globsym.top);
        sp = globsym.tab[si];
        symbol_debug(sp);
        if (strcmp(sp->Sident,s_name_context) == 0)
            return sp;
    }
}

/**********************************
 * Return size of context symbol on stack.
 */

unsigned nteh_contextsym_size()
{   int sz;

    if (usednteh & NTEH_try)
    {
#if MARS
        sz = 5 * 4;
#elif SCPP
        sz = 6 * 4;
#else
        assert(0);
#endif
        assert(usedalloca != 1);
    }
    else if (usednteh & NTEHcpp)
    {   sz = 5 * 4;                     // C++ context record
        assert(usedalloca != 1);
    }
    else if (usednteh & NTEHpassthru)
    {   sz = 1 * 4;
    }
    else
        sz = 0;                         // no context record
    return sz;
}

/**********************************
 * Return pointer to ecode symbol.
 */

symbol *nteh_ecodesym()
{   SYMIDX si;
    symbol *sp;

    for (si = 0; 1; si++)
    {   assert(si < globsym.top);
        sp = globsym.tab[si];
        symbol_debug(sp);
        if (strcmp(sp->Sident,s_name_ecode) == 0)
            return sp;
    }
}

/*********************************
 * Mark EH variables as used so that they don't get optimized away.
 */

void nteh_usevars()
{
#if SCPP
    // Turn off SFLdead and SFLunambig in Sflags
    nteh_contextsym()->Sflags &= ~(SFLdead | SFLunambig);
    nteh_contextsym()->Sflags |= SFLread;
    nteh_ecodesym()->Sflags   &= ~(SFLdead | SFLunambig);
    nteh_ecodesym()->Sflags   |= SFLread;
#else
    // Turn off SFLdead and SFLunambig in Sflags
    nteh_contextsym()->Sflags &= ~SFLdead;
    nteh_contextsym()->Sflags |= SFLread;
#endif
}

#if TX86
/*********************************
 * Generate NT exception handling function prolog.
 */

code *nteh_prolog()
{
    code cs;
    code *c1;
    code *c;

    if (usednteh & NTEHpassthru)
    {
        /* An sindex value of -2 is a magic value that tells the
         * stack unwinder to skip this frame.
         */
        assert(config.exe & (EX_LINUX | EX_LINUX64 | EX_OSX | EX_OSX64 | EX_FREEBSD | EX_FREEBSD64 | EX_SOLARIS | EX_SOLARIS64 | EX_OPENBSD | EX_OPENBSD64));
        cs.Iop = 0x68;
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL2 = FLconst;
        cs.IEV2.Vint = -2;
        return gen(CNIL,&cs);                   // PUSH -2
    }

    /* Generate instance of struct __nt_context on stack frame:
        [  ]                                    // previous ebp already there
        push    -1                              // sindex
        mov     EDX,FS:__except_list
        push    offset FLAT:scope_table         // stable (not for MARS or C++)
        push    offset FLAT:__except_handler3   // handler
        push    EDX                             // prev
        mov     FS:__except_list,ESP
        sub     ESP,8                           // info, esp for __except support
     */

//    useregs(mAX);                     // What is this for?

    cs.Iop = 0x68;
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL2 = FLconst;
    cs.IEV2.Vint = -1;
    c1 = gen(CNIL,&cs);                 // PUSH -1

    if (MARS || (usednteh & NTEHcpp))
    {
        // PUSH &framehandler
        cs.IFL2 = FLframehandler;
#if MARS
        nteh_scopetable();
#endif
    }
    else
    {
        // Do stable
        cs.Iflags |= CFoff;
        cs.IFL2 = FLextern;
        cs.IEVsym2 = nteh_scopetable();
        cs.IEVoffset2 = 0;
        c1 = gen(c1,&cs);                       // PUSH &scope_table

        cs.IFL2 = FLextern;
        cs.IEVsym2 = rtlsym[RTLSYM_EXCEPT_HANDLER3];
        makeitextern(rtlsym[RTLSYM_EXCEPT_HANDLER3]);
    }
    c = gen(NULL,&cs);                          // PUSH &__except_handler3

    if (config.exe == EX_NT)
    {
        makeitextern(rtlsym[RTLSYM_EXCEPT_LIST]);
    #if 0
        cs.Iop = 0xFF;
        cs.Irm = modregrm(0,6,BPRM);
        cs.Iflags = CFfs;
        cs.Irex = 0;
        cs.IFL1 = FLextern;
        cs.IEVsym1 = rtlsym[RTLSYM_EXCEPT_LIST];
        cs.IEVoffset1 = 0;
        gen(c,&cs);                             // PUSH FS:__except_list
    #else
        useregs(mDX);
        cs.Iop = 0x8B;
        cs.Irm = modregrm(0,DX,BPRM);
        cs.Iflags = CFfs;
        cs.Irex = 0;
        cs.IFL1 = FLextern;
        cs.IEVsym1 = rtlsym[RTLSYM_EXCEPT_LIST];
        cs.IEVoffset1 = 0;
        gen(c1,&cs);                            // MOV EDX,FS:__except_list

        gen1(c,0x50 + DX);                      // PUSH EDX
    #endif
        cs.Iop = 0x89;
        NEWREG(cs.Irm,SP);
        gen(c,&cs);                             // MOV FS:__except_list,ESP
    }

    c = cod3_stackadj(c, 8);

    return cat(c1,c);
}

/*********************************
 * Generate NT exception handling function epilog.
 */

code *nteh_epilog()
{
    if (!(config.flags2 & CFG2seh))
        return NULL;

    /* Generate:
        mov     ECX,__context[EBP].prev
        mov     FS:__except_list,ECX
     */
    code cs;
    code *c;
    unsigned reg;

#if MARS
    reg = CX;
#else
    reg = (tybasic(funcsym_p->Stype->Tnext->Tty) == TYvoid) ? AX : CX;
#endif
    useregs(mask[reg]);

    cs.Iop = 0x8B;
    cs.Irm = modregrm(2,reg,BPRM);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FLconst;
    // EBP offset of __context.prev
    cs.IEV1.Vint = nteh_EBPoffset_prev();
    c = gen(CNIL,&cs);

    cs.Iop = 0x89;
    cs.Irm = modregrm(0,reg,BPRM);
    cs.Iflags |= CFfs;
    cs.IFL1 = FLextern;
    cs.IEVsym1 = rtlsym[RTLSYM_EXCEPT_LIST];
    cs.IEVoffset1 = 0;
    return gen(c,&cs);
}

/**************************
 * Set/Reset ESP from context.
 */

code *nteh_setsp(int op)
{   code cs;

    cs.Iop = op;
    cs.Irm = modregrm(2,SP,BPRM);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FLconst;
    // EBP offset of __context.esp
    cs.IEV1.Vint = nteh_EBPoffset_esp();
    return gen(CNIL,&cs);               // MOV ESP,__context[EBP].esp
}

/****************************
 * Put out prolog for BC_filter block.
 */

code *nteh_filter(block *b)
{   code *c;
    code cs;

    assert(b->BC == BC_filter);
    c = CNIL;
    if (b->Bflags & BFLehcode)          // if referenced __ecode
    {
        /* Generate:
                mov     EAX,__context[EBP].info
                mov     EAX,[EAX]
                mov     EAX,[EAX]
                mov     __ecode[EBP],EAX
         */

        c = getregs(mAX);

        cs.Iop = 0x8B;
        cs.Irm = modregrm(2,AX,BPRM);
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL1 = FLconst;
        // EBP offset of __context.info
        cs.IEV1.Vint = nteh_EBPoffset_info();
        c = gen(c,&cs);                 // MOV EAX,__context[EBP].info
        cs.Irm = modregrm(0,AX,0);
        gen(c,&cs);                     // MOV EAX,[EAX]
        gen(c,&cs);                     // MOV EAX,[EAX]
        cs.Iop = 0x89;
        cs.Irm = modregrm(2,AX,BPRM);
        cs.IFL1 = FLauto;
        cs.IEVsym1 = nteh_ecodesym();
        cs.IEVoffset1 = 0;
        gen(c,&cs);                     // MOV __ecode[EBP],EAX
    }
    return c;
}

/*******************************
 * Generate C++ or D frame handler.
 */

void nteh_framehandler(symbol *scopetable)
{
    // Generate:
    //  MOV     EAX,&scope_table
    //  JMP     __cpp_framehandler

    if (scopetable)
    {
        symbol_debug(scopetable);
        code *c = gencs(NULL,0xB8+AX,0,FLextern,scopetable);  // MOV EAX,&scope_table
#if MARS
        gencs(c,0xE9,0,FLfunc,rtlsym[RTLSYM_D_HANDLER]);      // JMP _d_framehandler
#else
        gencs(c,0xE9,0,FLfunc,rtlsym[RTLSYM_CPP_HANDLER]);    // JMP __cpp_framehandler
#endif

        pinholeopt(c,NULL);
        codout(c);
        code_free(c);
    }
}

/*********************************
 * Generate code to set scope index.
 */

code *nteh_patchindex(code* c, int sindex)
{
    c->IEV2.Vsize_t = sindex;
    return c;
}

code *nteh_gensindex(int sindex)
{   code *c;

    if (!(config.flags2 & CFG2seh))
        return NULL;

    // Generate:
    //  MOV     -4[EBP],sindex

    c = genc(NULL,0xC7,modregrm(1,0,BP),FLconst,(targ_uns)nteh_EBPoffset_sindex(),FLconst,sindex);      // 7 bytes long
    c->Iflags |= CFvolatile;
#ifdef DEBUG
    //assert(GENSINDEXSIZE == calccodsize(c));
#endif
    return c;
}

/*********************************
 * Generate code for setjmp().
 */

code *cdsetjmp(elem *e,regm_t *pretregs)
{   code cs;
    code *c;
    regm_t retregs;
    unsigned stackpushsave;
    unsigned flag;

    c = NULL;
    stackpushsave = stackpush;
#if SCPP
    if (CPP && (funcsym_p->Sfunc->Fflags3 & Fcppeh || usednteh & NTEHcpp))
    {
        /*  If in C++ try block
            If the frame that is calling setjmp has a try,catch block then
            the call to setjmp3 is as follows:
              __setjmp3(environment,3,__cpp_longjmp_unwind,trylevel,funcdata);

            __cpp_longjmp_unwind is a routine in the RTL. This is a
            stdcall routine that will deal with unwinding for CPP Frames.
            trylevel is the value that gets incremented at each catch,
            constructor invocation.
            funcdata is the same value that you put into EAX prior to
            cppframehandler getting called.
         */
        symbol *s;

        s = except_gensym();
        if (!s)
            goto L1;

        c = gencs(c,0x68,0,FLextern,s);                 // PUSH &scope_table
        stackpush += 4;
        genadjesp(c,4);

        c = genc1(c,0xFF,modregrm(1,6,BP),FLconst,(targ_uns)-4);
                                                // PUSH trylevel
        stackpush += 4;
        genadjesp(c,4);

        cs.Iop = 0x68;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IFL2 = FLextern;
        cs.IEVsym2 = rtlsym[RTLSYM_CPP_LONGJMP];
        cs.IEVoffset2 = 0;
        c = gen(c,&cs);                         // PUSH &_cpp_longjmp_unwind
        stackpush += 4;
        genadjesp(c,4);

        flag = 3;
    }
    else
#endif
    if (funcsym_p->Sfunc->Fflags3 & Fnteh)
    {
        /*  If in NT SEH try block
            If the frame that is calling setjmp has a try, except block
            then the call to setjmp3 is as follows:
              __setjmp3(environment,2,__seh_longjmp_unwind,trylevel);
            __seth_longjmp_unwind is supplied by the RTL and is a stdcall
            function. It is the name that MSOFT uses, we should
            probably use the same one.
            trylevel is the value that you increment at each try and
            decrement at the close of the try.  This corresponds to the
            index field of the ehrec.
         */
        int sindex_off;

        sindex_off = 20;                // offset of __context.sindex
        cs.Iop = 0xFF;
        cs.Irm = modregrm(2,6,BPRM);
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL1 = FLbprel;
        cs.IEVsym1 = nteh_contextsym();
        cs.IEVoffset1 = sindex_off;
        c = gen(c,&cs);                 // PUSH scope_index
        stackpush += 4;
        genadjesp(c,4);

        cs.Iop = 0x68;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IFL2 = FLextern;
        cs.IEVsym2 = rtlsym[RTLSYM_LONGJMP];
        cs.IEVoffset2 = 0;
        c = gen(c,&cs);                 // PUSH &_seh_longjmp_unwind
        stackpush += 4;
        genadjesp(c,4);

        flag = 2;
    }
    else
    {
        /*  If the frame calling setjmp has neither a try..except, nor a
            try..catch, then call setjmp3 as follows:
            _setjmp3(environment,0)
         */
    L1:
        flag = 0;
    }

    cs.Iop = 0x68;
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL2 = FLconst;
    cs.IEV2.Vint = flag;
    c = gen(c,&cs);                     // PUSH flag
    stackpush += 4;
    genadjesp(c,4);

    c = cat(c,params(e->E1,REGSIZE));

    c = cat(c,getregs(~rtlsym[RTLSYM_SETJMP3]->Sregsaved & (ALLREGS | mES)));
    gencs(c,0xE8,0,FLfunc,rtlsym[RTLSYM_SETJMP3]);      // CALL __setjmp3

    c = cod3_stackadj(c, -(stackpush - stackpushsave));
    genadjesp(c,-(stackpush - stackpushsave));

    stackpush = stackpushsave;
    retregs = regmask(e->Ety, TYnfunc);
    return cat(c,fixresult(e,retregs,pretregs));
}

/****************************************
 * Call _local_unwind(), which means call the __finally blocks until
 * index is reached.
 */

code *nteh_unwind(regm_t retregs,unsigned index)
{   code *c;
    code cs;
    code *cs1;
    code *cs2;
    regm_t desregs;
    int reg;
    int local_unwind;

    // Shouldn't this always be CX?
#if SCPP
    reg = AX;
#else
    reg = CX;
#endif

#if MARS
    local_unwind = RTLSYM_D_LOCAL_UNWIND2;
#else
    local_unwind = RTLSYM_LOCAL_UNWIND2;
#endif
    desregs = (~rtlsym[local_unwind]->Sregsaved & (ALLREGS)) | mask[reg];
    gensaverestore(retregs & desregs,&cs1,&cs2);

    c = getregs(desregs);

    cs.Iop = 0x8D;
    cs.Irm = modregrm(2,reg,BPRM);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FLconst;
    // EBP offset of __context.prev
    cs.IEV1.Vint = nteh_EBPoffset_prev();
    c = gen(c,&cs);                             // LEA  ECX,contextsym

    genc2(c,0x68,0,index);                      // PUSH index
    gen1(c,0x50 + reg);                         // PUSH ECX

#if MARS
    //gencs(c,0xB8+AX,0,FLextern,nteh_scopetable());    // MOV EAX,&scope_table
    gencs(c,0x68,0,FLextern,nteh_scopetable());         // PUSH &scope_table

    gencs(c,0xE8,0,FLfunc,rtlsym[local_unwind]);        // CALL __d_local_unwind2()
    cod3_stackadj(c, -12);
#else
    gencs(c,0xE8,0,FLfunc,rtlsym[local_unwind]);        // CALL __local_unwind2()
    cod3_stackadj(c, -8);
#endif

    c = cat4(cs1,c,cs2,NULL);
    return c;
}

/****************************************
 * Call _local_unwind(), which means call the __finally blocks until
 * index is reached.
 */

#if 0 // Replaced with inline calls to __finally blocks

code *linux_unwind(regm_t retregs,unsigned index)
{   code *c;
    code *cs1;
    code *cs2;
    int i;
    regm_t desregs;
    int reg;
    int local_unwind;

    // Shouldn't this always be CX?
#if SCPP
    reg = AX;
#else
    reg = CX;
#endif

#if MARS
    local_unwind = RTLSYM_D_LOCAL_UNWIND2;
#else
    local_unwind = RTLSYM_LOCAL_UNWIND2;
#endif
    desregs = (~rtlsym[local_unwind]->Sregsaved & (ALLREGS)) | mask[reg];
    gensaverestore(retregs & desregs,&cs1,&cs2);

    c = getregs(desregs);
    c = genc2(c,0x68,0,index);                  // PUSH index

#if MARS
//    gencs(c,0x68,0,FLextern,nteh_scopetable());               // PUSH &scope_table

    gencs(c,0xE8,0,FLfunc,rtlsym[local_unwind]);        // CALL __d_local_unwind2()
    cod3_stackadj(c, -4);
#else
    gencs(c,0xE8,0,FLfunc,rtlsym[local_unwind]);        // CALL __local_unwind2()
    cod3_stackadj(c, -8);
#endif

    c = cat4(cs1,c,cs2,NULL);
    return c;
}

#endif

/*************************************************
 * Set monitor, hook monitor exception handler.
 */

#if MARS

code *nteh_monitor_prolog(Symbol *shandle)
{
    /*
     *  PUSH    handle
     *  PUSH    offset _d_monitor_handler
     *  PUSH    FS:__except_list
     *  MOV     FS:__except_list,ESP
     *  CALL    _d_monitor_prolog
     */
    code *c1 = NULL;
    code *c;
    code cs;
    Symbol *s;
    regm_t desregs;

    assert(config.flags2 & CFG2seh);    // BUG: figure out how to implement for other EX's

    if (shandle->Sclass == SCfastpar)
    {   assert(shandle->Spreg != DX);
        assert(shandle->Spreg2 == NOREG);
        c = gen1(NULL,0x50 + shandle->Spreg);   // PUSH shandle
    }
    else
    {
        // PUSH shandle
#if 0
        c = genc1(NULL,0xFF,modregrm(2,6,4),FLconst,4 * (1 + needframe) + shandle->Soffset + localsize);
        c->Isib = modregrm(0,4,SP);
#else
        useregs(mCX);
        c = genc1(NULL,0x8B,modregrm(2,CX,4),FLconst,4 * (1 + needframe) + shandle->Soffset + localsize);
        c->Isib = modregrm(0,4,SP);
        gen1(c,0x50 + CX);                      // PUSH ECX
#endif
    }

    s = rtlsym[RTLSYM_MONITOR_HANDLER];
    c = gencs(c,0x68,0,FLextern,s);             // PUSH offset _d_monitor_handler
    makeitextern(s);

#if 0
    cs.Iop = 0xFF;
    cs.Irm = modregrm(0,6,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FLextern;
    cs.IEVsym1 = rtlsym[RTLSYM_EXCEPT_LIST];
    cs.IEVoffset1 = 0;
    gen(c,&cs);                         // PUSH FS:__except_list
#else
    useregs(mDX);
    cs.Iop = 0x8B;
    cs.Irm = modregrm(0,DX,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FLextern;
    cs.IEVsym1 = rtlsym[RTLSYM_EXCEPT_LIST];
    cs.IEVoffset1 = 0;
    c1 = gen(c1,&cs);                   // MOV EDX,FS:__except_list

    gen1(c,0x50 + DX);                  // PUSH EDX
#endif

    s = rtlsym[RTLSYM_MONITOR_PROLOG];
    desregs = ~s->Sregsaved & ALLREGS;
    c = cat(c,getregs(desregs));
    c = gencs(c,0xE8,0,FLfunc,s);       // CALL _d_monitor_prolog

    cs.Iop = 0x89;
    NEWREG(cs.Irm,SP);
    gen(c,&cs);                         // MOV FS:__except_list,ESP

    return cat(c1,c);
}

#endif

/*************************************************
 * Release monitor, unhook monitor exception handler.
 * Input:
 *      retregs         registers to not destroy
 */

#if MARS

code *nteh_monitor_epilog(regm_t retregs)
{
    /*
     *  CALL    _d_monitor_epilog
     *  POP     FS:__except_list
     */
    code cs;
    code *c;
    code *cs1;
    code *cs2;
    code *cpop;
    regm_t desregs;
    Symbol *s;

    assert(config.flags2 & CFG2seh);    // BUG: figure out how to implement for other EX's

    s = rtlsym[RTLSYM_MONITOR_EPILOG];
    //desregs = ~s->Sregsaved & ALLREGS;
    desregs = 0;
    gensaverestore(retregs & desregs,&cs1,&cs2);

    c = getregs(desregs);
    c = gencs(c,0xE8,0,FLfunc,s);               // CALL __d_monitor_epilog

    cs.Iop = 0x8F;
    cs.Irm = modregrm(0,0,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FLextern;
    cs.IEVsym1 = rtlsym[RTLSYM_EXCEPT_LIST];
    cs.IEVoffset1 = 0;
    cpop = gen(NULL,&cs);                       // POP FS:__except_list

    c = cat4(cs1,c,cs2,cpop);
    return c;
}

#endif

#endif // TX86

#endif
