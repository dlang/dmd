/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/nteh.c
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
    if (config.exe == EX_WIN32)
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

void nteh_gentables(Symbol *sfunc)
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
    DtBuilder dtb;
    int sz = 0;                     // size so far

    for (block *b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BC_try)
        {
            block *bhandler;

            dtb.dword(b->Blast_index);  // parent index

            // If try-finally
            if (b->numSucc() == 2)
            {
                dtb.dword(0);           // filter address
                bhandler = b->nthSucc(1);
                assert(bhandler->BC == BC_finally);
                // To successor of BC_finally block
                bhandler = bhandler->nthSucc(0);
            }
            else // try-except
            {
                bhandler = b->nthSucc(1);
                assert(bhandler->BC == BC_filter);
                dtb.coff(bhandler->Boffset);    // filter address
                bhandler = b->nthSucc(2);
                assert(bhandler->BC == BC_except);
            }
            dtb.coff(bhandler->Boffset);        // handler address
            sz += 4 + fsize * 2;
        }
    }
    assert(sz != 0);
    s->Sdt = dtb.finish();
#endif

    outdata(s);                 // output the scope table
#if MARS
    nteh_framehandler(sfunc, s);
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
    }
    else if (usednteh & NTEHcpp)
    {
        sz = 5 * 4;                     // C++ context record
    }
    else if (usednteh & NTEHpassthru)
    {
        sz = 1 * 4;
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

void nteh_prolog(CodeBuilder& cdb)
{
    code cs;

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
        cdb.gen(&cs);                           // PUSH -2
        return;
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
    cdb.gen(&cs);                 // PUSH -1

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
        cdb.gen(&cs);                       // PUSH &scope_table

        cs.IFL2 = FLextern;
        cs.IEVsym2 = getRtlsym(RTLSYM_EXCEPT_HANDLER3);
        makeitextern(getRtlsym(RTLSYM_EXCEPT_HANDLER3));
    }
    CodeBuilder cdb2;
    cdb2.gen(&cs);                          // PUSH &__except_handler3

    if (config.exe == EX_WIN32)
    {
        makeitextern(getRtlsym(RTLSYM_EXCEPT_LIST));
    #if 0
        cs.Iop = 0xFF;
        cs.Irm = modregrm(0,6,BPRM);
        cs.Iflags = CFfs;
        cs.Irex = 0;
        cs.IFL1 = FLextern;
        cs.IEVsym1 = getRtlsym(RTLSYM_EXCEPT_LIST);
        cs.IEVoffset1 = 0;
        cdb2.gen(&cs);                             // PUSH FS:__except_list
    #else
        useregs(mDX);
        cs.Iop = 0x8B;
        cs.Irm = modregrm(0,DX,BPRM);
        cs.Iflags = CFfs;
        cs.Irex = 0;
        cs.IFL1 = FLextern;
        cs.IEVsym1 = getRtlsym(RTLSYM_EXCEPT_LIST);
        cs.IEVoffset1 = 0;
        cdb.gen(&cs);                            // MOV EDX,FS:__except_list

        cdb2.gen1(0x50 + DX);                      // PUSH EDX
    #endif
        cs.Iop = 0x89;
        NEWREG(cs.Irm,SP);
        cdb2.gen(&cs);                             // MOV FS:__except_list,ESP
    }

    cdb.append(cdb2);
    cod3_stackadj(cdb, 8);
}

/*********************************
 * Generate NT exception handling function epilog.
 */

void nteh_epilog(CodeBuilder& cdb)
{
    if (config.exe != EX_WIN32)
        return;

    /* Generate:
        mov     ECX,__context[EBP].prev
        mov     FS:__except_list,ECX
     */
    code cs;
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
    cdb.gen(&cs);

    cs.Iop = 0x89;
    cs.Irm = modregrm(0,reg,BPRM);
    cs.Iflags |= CFfs;
    cs.IFL1 = FLextern;
    cs.IEVsym1 = getRtlsym(RTLSYM_EXCEPT_LIST);
    cs.IEVoffset1 = 0;
    cdb.gen(&cs);
}

/**************************
 * Set/Reset ESP from context.
 */

void nteh_setsp(CodeBuilder& cdb, int op)
{
    code cs;
    cs.Iop = op;
    cs.Irm = modregrm(2,SP,BPRM);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FLconst;
    // EBP offset of __context.esp
    cs.IEV1.Vint = nteh_EBPoffset_esp();
    cdb.gen(&cs);               // MOV ESP,__context[EBP].esp
}

/****************************
 * Put out prolog for BC_filter block.
 */

void nteh_filter(CodeBuilder& cdb, block *b)
{
    code cs;

    assert(b->BC == BC_filter);
    if (b->Bflags & BFLehcode)          // if referenced __ecode
    {
        /* Generate:
                mov     EAX,__context[EBP].info
                mov     EAX,[EAX]
                mov     EAX,[EAX]
                mov     __ecode[EBP],EAX
         */

        getregs(cdb,mAX);

        cs.Iop = 0x8B;
        cs.Irm = modregrm(2,AX,BPRM);
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL1 = FLconst;
        // EBP offset of __context.info
        cs.IEV1.Vint = nteh_EBPoffset_info();
        cdb.gen(&cs);                 // MOV EAX,__context[EBP].info

        cs.Irm = modregrm(0,AX,0);
        cdb.gen(&cs);                     // MOV EAX,[EAX]
        cdb.gen(&cs);                     // MOV EAX,[EAX]

        cs.Iop = 0x89;
        cs.Irm = modregrm(2,AX,BPRM);
        cs.IFL1 = FLauto;
        cs.IEVsym1 = nteh_ecodesym();
        cs.IEVoffset1 = 0;
        cdb.gen(&cs);                     // MOV __ecode[EBP],EAX
    }
}

/*******************************
 * Generate C++ or D frame handler.
 */

void nteh_framehandler(Symbol *sfunc, Symbol *scopetable)
{
    // Generate:
    //  MOV     EAX,&scope_table
    //  JMP     __cpp_framehandler

    if (scopetable)
    {
        symbol_debug(scopetable);
        CodeBuilder cdb;
        cdb.gencs(0xB8+AX,0,FLextern,scopetable);  // MOV EAX,&scope_table
#if MARS
        cdb.gencs(0xE9,0,FLfunc,getRtlsym(RTLSYM_D_HANDLER));      // JMP _d_framehandler
#else
        cdb.gencs(0xE9,0,FLfunc,getRtlsym(RTLSYM_CPP_HANDLER));    // JMP __cpp_framehandler
#endif

        code *c = cdb.finish();
        pinholeopt(c,NULL);
        codout(sfunc->Sseg,c);
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

void nteh_gensindex(CodeBuilder& cdb, int sindex)
{
    if (config.exe != EX_WIN32)
        return;

    // Generate:
    //  MOV     -4[EBP],sindex

    cdb.genc(0xC7,modregrm(1,0,BP),FLconst,(targ_uns)nteh_EBPoffset_sindex(),FLconst,sindex);      // 7 bytes long
    cdb.last()->Iflags |= CFvolatile;
#ifdef DEBUG
    //assert(GENSINDEXSIZE == calccodsize(c));
#endif
}

/*********************************
 * Generate code for setjmp().
 */

void cdsetjmp(CodeBuilder& cdb, elem *e,regm_t *pretregs)
{   code cs;
    regm_t retregs;
    unsigned stackpushsave;
    unsigned flag;

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

        cdb.gencs(0x68,0,FLextern,s);                 // PUSH &scope_table
        stackpush += 4;
        cdb.genadjesp(4);

        cdb.genc1(0xFF,modregrm(1,6,BP),FLconst,(targ_uns)-4);
                                                // PUSH trylevel
        stackpush += 4;
        cdb.genadjesp(4);

        cs.Iop = 0x68;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IFL2 = FLextern;
        cs.IEVsym2 = getRtlsym(RTLSYM_CPP_LONGJMP);
        cs.IEVoffset2 = 0;
        cdb.gen(&cs);                         // PUSH &_cpp_longjmp_unwind
        stackpush += 4;
        cdb.genadjesp(4);

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
        cdb.gen(&cs);                 // PUSH scope_index
        stackpush += 4;
        cdb.genadjesp(4);

        cs.Iop = 0x68;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IFL2 = FLextern;
        cs.IEVsym2 = getRtlsym(RTLSYM_LONGJMP);
        cs.IEVoffset2 = 0;
        cdb.gen(&cs);                 // PUSH &_seh_longjmp_unwind
        stackpush += 4;
        cdb.genadjesp(4);

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
    cdb.gen(&cs);                     // PUSH flag
    stackpush += 4;
    cdb.genadjesp(4);

    pushParams(cdb,e->E1,REGSIZE);

    getregs(cdb,~getRtlsym(RTLSYM_SETJMP3)->Sregsaved & (ALLREGS | mES));
    cdb.gencs(0xE8,0,FLfunc,getRtlsym(RTLSYM_SETJMP3));      // CALL __setjmp3

    cod3_stackadj(cdb, -(stackpush - stackpushsave));
    cdb.genadjesp(-(stackpush - stackpushsave));

    stackpush = stackpushsave;
    retregs = regmask(e->Ety, TYnfunc);
    fixresult(cdb,e,retregs,pretregs);
}

/****************************************
 * Call _local_unwind(), which means call the __finally blocks until
 * index is reached.
 */

void nteh_unwind(CodeBuilder& cdb,regm_t retregs,unsigned index)
{
    code cs;
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
    desregs = (~getRtlsym(local_unwind)->Sregsaved & (ALLREGS)) | mask[reg];
    code *cs1;
    code *cs2;
    gensaverestore(retregs & desregs,&cs1,&cs2);

    CodeBuilder cdbx;
    getregs(cdbx,desregs);

    cs.Iop = 0x8D;
    cs.Irm = modregrm(2,reg,BPRM);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FLconst;
    // EBP offset of __context.prev
    cs.IEV1.Vint = nteh_EBPoffset_prev();
    cdbx.gen(&cs);                             // LEA  ECX,contextsym

    cdbx.genc2(0x68,0,index);                      // PUSH index
    cdbx.gen1(0x50 + reg);                         // PUSH ECX

#if MARS
    //cdbx.gencs(0xB8+AX,0,FLextern,nteh_scopetable());    // MOV EAX,&scope_table
    cdbx.gencs(0x68,0,FLextern,nteh_scopetable());         // PUSH &scope_table

    cdbx.gencs(0xE8,0,FLfunc,getRtlsym(local_unwind));        // CALL __d_local_unwind2()
    cod3_stackadj(cdbx, -12);
#else
    cdbx.gencs(0xE8,0,FLfunc,getRtlsym(local_unwind));        // CALL __local_unwind2()
    cod3_stackadj(cdbx, -8);
#endif

    cdb.append(cs1);
    cdb.append(cdbx);
    cdb.append(cs2);
}

/****************************************
 * Call _local_unwind(), which means call the __finally blocks until
 * index is reached.
 */

#if 0 // Replaced with inline calls to __finally blocks

code *linux_unwind(regm_t retregs,unsigned index)
{
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
    desregs = (~getRtlsym(local_unwind)->Sregsaved & (ALLREGS)) | mask[reg];
    code *cs1;
    code *cs2;
    gensaverestore(retregs & desregs,&cs1,&cs2);

    CodeBuilder cdb;
    getregs(cdb,desregs);
    cdb.genc2(0x68,0,index);                  // PUSH index

#if MARS
//    cdb.gencs(0x68,0,FLextern,nteh_scopetable());               // PUSH &scope_table

    cdb.gencs(0xE8,0,FLfunc,getRtlsym(local_unwind));        // CALL __d_local_unwind2()
    cod3_stackadj(cdb, -4);
#else
    cdb.gencs(0xE8,0,FLfunc,getRtlsym(local_unwind));        // CALL __local_unwind2()
    cod3_stackadj(cdb, -8);
#endif

    CodeBuilder cdb1(cs1);
    CodeBuilder cdb2(cs2);
    cdb1.append(cdb, cdb2);
    return cdb1.finish();
}

#endif

/*************************************************
 * Set monitor, hook monitor exception handler.
 */

#if MARS

void nteh_monitor_prolog(CodeBuilder& cdb, Symbol *shandle)
{
    /*
     *  PUSH    handle
     *  PUSH    offset _d_monitor_handler
     *  PUSH    FS:__except_list
     *  MOV     FS:__except_list,ESP
     *  CALL    _d_monitor_prolog
     */
    CodeBuilder cdbx;

    assert(config.exe == EX_WIN32);    // BUG: figure out how to implement for other EX's

    if (shandle->Sclass == SCfastpar)
    {   assert(shandle->Spreg != DX);
        assert(shandle->Spreg2 == NOREG);
        cdbx.gen1(0x50 + shandle->Spreg);   // PUSH shandle
    }
    else
    {
        // PUSH shandle
        useregs(mCX);
        cdbx.genc1(0x8B,modregrm(2,CX,4),FLconst,4 * (1 + needframe) + shandle->Soffset + localsize);
        cdbx.last()->Isib = modregrm(0,4,SP);
        cdbx.gen1(0x50 + CX);                      // PUSH ECX
    }

    Symbol *smh = getRtlsym(RTLSYM_MONITOR_HANDLER);
    cdbx.gencs(0x68,0,FLextern,smh);             // PUSH offset _d_monitor_handler
    makeitextern(smh);

    code cs;
    useregs(mDX);
    cs.Iop = 0x8B;
    cs.Irm = modregrm(0,DX,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FLextern;
    cs.IEVsym1 = getRtlsym(RTLSYM_EXCEPT_LIST);
    cs.IEVoffset1 = 0;
    cdb.gen(&cs);                   // MOV EDX,FS:__except_list

    cdbx.gen1(0x50 + DX);                  // PUSH EDX

    Symbol *s = getRtlsym(RTLSYM_MONITOR_PROLOG);
    regm_t desregs = ~s->Sregsaved & ALLREGS;
    getregs(cdbx,desregs);
    cdbx.gencs(0xE8,0,FLfunc,s);       // CALL _d_monitor_prolog

    cs.Iop = 0x89;
    NEWREG(cs.Irm,SP);
    cdbx.gen(&cs);                         // MOV FS:__except_list,ESP

    cdb.append(cdbx);
}

#endif

/*************************************************
 * Release monitor, unhook monitor exception handler.
 * Input:
 *      retregs         registers to not destroy
 */

#if MARS

void nteh_monitor_epilog(CodeBuilder& cdb,regm_t retregs)
{
    /*
     *  CALL    _d_monitor_epilog
     *  POP     FS:__except_list
     */

    assert(config.exe == EX_WIN32);    // BUG: figure out how to implement for other EX's

    Symbol *s = getRtlsym(RTLSYM_MONITOR_EPILOG);
    //desregs = ~s->Sregsaved & ALLREGS;
    regm_t desregs = 0;
    code *cs1;
    code *cs2;
    gensaverestore(retregs& desregs,&cs1,&cs2);
    cdb.append(cs1);

    getregs(cdb,desregs);
    cdb.gencs(0xE8,0,FLfunc,s);               // CALL __d_monitor_epilog

    cdb.append(cs2);

    code cs;
    cs.Iop = 0x8F;
    cs.Irm = modregrm(0,0,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FLextern;
    cs.IEVsym1 = getRtlsym(RTLSYM_EXCEPT_LIST);
    cs.IEVoffset1 = 0;
    cdb.gen(&cs);                       // POP FS:__except_list
}

#endif

#endif // TX86

#endif
