/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/nteh.d, backend/nteh.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/nteh.d
 */

// Support for NT exception handling

module dmd.backend.nteh;

version (SPP)
{
}
else
{

import core.stdc.stdio;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

version (SCPP)
{
    import scopeh;
}
else version (HTOD)
{
    import scopeh;
}

static if (NTEXCEPTIONS)
{

extern (C++):

nothrow:
@safe:

int REGSIZE();
Symbol* except_gensym();
void except_fillInEHTable(Symbol *s);

private __gshared
{
    Symbol *s_table;
    Symbol *s_context;
    const(char)* s_name_context_tag = "__nt_context";
    const(char)* s_name_context = "__context";
    const(char)* s_name_ecode = "__ecode";

    const(char)* text_nt =
    "struct __nt_context {" ~
        "int esp; int info; int prev; int handler; int stable; int sindex; int ebp;" ~
     "};\n";
}

// member stable is not used for MARS or C++

int nteh_EBPoffset_sindex()     { return -4; }
int nteh_EBPoffset_prev()       { return -nteh_contextsym_size() + 8; }
int nteh_EBPoffset_info()       { return -nteh_contextsym_size() + 4; }
int nteh_EBPoffset_esp()        { return -nteh_contextsym_size() + 0; }

int nteh_offset_sindex()        { version (MARS) { return 16; } else { return 20; } }
int nteh_offset_sindex_seh()    { return 20; }
int nteh_offset_info()          { return 4; }

/***********************************
 */

@trusted
ubyte *nteh_context_string()
{
    if (config.exe == EX_WIN32)
        return cast(ubyte *)text_nt;
    else
        return null;
}

/*******************************
 * Get symbol for scope table for current function.
 * Returns:
 *      symbol of table
 */

@trusted
private Symbol *nteh_scopetable()
{
    Symbol *s;
    type *t;

    if (!s_table)
    {
        t = type_alloc(TYint);
        s = symbol_generate(SCstatic,t);
        s.Sseg = UNKNOWN;
        symbol_keep(s);
        s_table = s;
    }
    return s_table;
}

/*************************************
 */

@trusted
void nteh_filltables()
{
version (MARS)
{
    Symbol *s = s_table;
    symbol_debug(s);
    except_fillInEHTable(s);
}
}

/****************************
 * Generate and output scope table.
 * Not called for NTEH C++ exceptions
 */

@trusted
void nteh_gentables(Symbol *sfunc)
{
    Symbol *s = s_table;
    symbol_debug(s);
version (MARS)
{
    //except_fillInEHTable(s);
}
else
{
    /* NTEH table for C.
     * The table consists of triples:
     *  parent index
     *  filter address
     *  handler address
     */
    uint fsize = 4;             // target size of function pointer
    auto dtb = DtBuilder(0);
    int sz = 0;                     // size so far

    foreach (b; BlockRange(startblock))
    {
        if (b.BC == BC_try)
        {
            block *bhandler;

            dtb.dword(b.Blast_index);  // parent index

            // If try-finally
            if (b.numSucc() == 2)
            {
                dtb.dword(0);           // filter address
                bhandler = b.nthSucc(1);
                assert(bhandler.BC == BC_finally);
                // To successor of BC_finally block
                bhandler = bhandler.nthSucc(0);
            }
            else // try-except
            {
                bhandler = b.nthSucc(1);
                assert(bhandler.BC == BC_filter);
                dtb.coff(bhandler.Boffset);    // filter address
                bhandler = b.nthSucc(2);
                assert(bhandler.BC == BC_except);
            }
            dtb.coff(bhandler.Boffset);        // handler address
            sz += 4 + fsize * 2;
        }
    }
    assert(sz != 0);
    s.Sdt = dtb.finish();
}

    outdata(s);                 // output the scope table
version (MARS)
{
    nteh_framehandler(sfunc, s);
}
    s_table = null;
}

/**************************
 * Declare frame variables.
 */

@trusted
void nteh_declarvars(Blockx *bx)
{
    Symbol *s;

    //printf("nteh_declarvars()\n");
version (MARS)
{
    if (!(bx.funcsym.Sfunc.Fflags3 & Fnteh)) // if haven't already done it
    {   bx.funcsym.Sfunc.Fflags3 |= Fnteh;
        s = symbol_name(s_name_context,SCbprel,tstypes[TYint]);
        s.Soffset = -5 * 4;            // -6 * 4 for C __try, __except, __finally
        s.Sflags |= SFLfree | SFLnodebug;
        type_setty(&s.Stype,mTYvolatile | TYint);
        symbol_add(s);
        bx.context = s;
    }
}
else
{
    if (!(funcsym_p.Sfunc.Fflags3 & Fnteh))   // if haven't already done it
    {   funcsym_p.Sfunc.Fflags3 |= Fnteh;
        if (!s_context)
            s_context = scope_search(s_name_context_tag, CPP ? SCTglobal : SCTglobaltag);
        symbol_debug(s_context);

        s = symbol_name(s_name_context,SCbprel,s_context.Stype);
        s.Soffset = -6 * 4;            // -5 * 4 for C++
        s.Sflags |= SFLfree;
        symbol_add(s);
        type_setty(&s.Stype,mTYvolatile | TYstruct);

        s = symbol_name(s_name_ecode,SCauto,type_alloc(mTYvolatile | TYint));
        s.Sflags |= SFLfree;
        symbol_add(s);
    }
}
}

/**************************************
 * Generate elem that sets the context index into the scope table.
 */

version (MARS)
{
elem *nteh_setScopeTableIndex(Blockx *blx, int scope_index)
{
    elem *e;
    Symbol *s;

    s = blx.context;
    symbol_debug(s);
    e = el_var(s);
    e.EV.Voffset = nteh_offset_sindex();
    return el_bin(OPeq, TYint, e, el_long(TYint, scope_index));
}
}


/**********************************
 * Return pointer to context symbol.
 */

@trusted
Symbol *nteh_contextsym()
{
    for (SYMIDX si = 0; 1; si++)
    {   assert(si < globsym.length);
        Symbol* sp = globsym[si];
        symbol_debug(sp);
        if (strcmp(sp.Sident.ptr,s_name_context) == 0)
            return sp;
    }
}

/**********************************
 * Return size of context symbol on stack.
 */
@trusted
uint nteh_contextsym_size()
{
    int sz;

    if (usednteh & NTEH_try)
    {
version (MARS)
{
        sz = 5 * 4;
}
else version (SCPP)
{
        sz = 6 * 4;
}
else version (HTOD)
{
        sz = 6 * 4;
}
else
        static assert(0);
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

@trusted
Symbol *nteh_ecodesym()
{
    SYMIDX si;
    Symbol *sp;

    for (si = 0; 1; si++)
    {   assert(si < globsym.length);
        sp = globsym[si];
        symbol_debug(sp);
        if (strcmp(sp.Sident.ptr, s_name_ecode) == 0)
            return sp;
    }
}

/*********************************
 * Mark EH variables as used so that they don't get optimized away.
 */

void nteh_usevars()
{
version (SCPP)
{
    // Turn off SFLdead and SFLunambig in Sflags
    nteh_contextsym().Sflags &= ~(SFLdead | SFLunambig);
    nteh_contextsym().Sflags |= SFLread;
    nteh_ecodesym().Sflags   &= ~(SFLdead | SFLunambig);
    nteh_ecodesym().Sflags   |= SFLread;
}
else
{
    // Turn off SFLdead and SFLunambig in Sflags
    nteh_contextsym().Sflags &= ~SFLdead;
    nteh_contextsym().Sflags |= SFLread;
}
}

/*********************************
 * Generate NT exception handling function prolog.
 */

@trusted
void nteh_prolog(ref CodeBuilder cdb)
{
    code cs;

    if (usednteh & NTEHpassthru)
    {
        /* An sindex value of -2 is a magic value that tells the
         * stack unwinder to skip this frame.
         */
        assert(config.exe & EX_posix);
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

    version (MARS)
    {
        // PUSH &framehandler
        cs.IFL2 = FLframehandler;
        nteh_scopetable();
    }
    else
    {
    if (usednteh & NTEHcpp)
    {
        // PUSH &framehandler
        cs.IFL2 = FLframehandler;
    }
    else
    {
        // Do stable
        cs.Iflags |= CFoff;
        cs.IFL2 = FLextern;
        cs.IEV2.Vsym = nteh_scopetable();
        cs.IEV2.Voffset = 0;
        cdb.gen(&cs);                       // PUSH &scope_table

        cs.IFL2 = FLextern;
        cs.IEV2.Vsym = getRtlsym(RTLSYM_EXCEPT_HANDLER3);
        makeitextern(getRtlsym(RTLSYM_EXCEPT_HANDLER3));
    }
    }

    CodeBuilder cdb2;
    cdb2.ctor();
    cdb2.gen(&cs);                          // PUSH &__except_handler3

    if (config.exe == EX_WIN32)
    {
        makeitextern(getRtlsym(RTLSYM_EXCEPT_LIST));
    static if (0)
    {
        cs.Iop = 0xFF;
        cs.Irm = modregrm(0,6,BPRM);
        cs.Iflags = CFfs;
        cs.Irex = 0;
        cs.IFL1 = FLextern;
        cs.IEV1.Vsym = getRtlsym(RTLSYM_EXCEPT_LIST);
        cs.IEV1.Voffset = 0;
        cdb2.gen(&cs);                             // PUSH FS:__except_list
    }
    else
    {
        useregs(mDX);
        cs.Iop = 0x8B;
        cs.Irm = modregrm(0,DX,BPRM);
        cs.Iflags = CFfs;
        cs.Irex = 0;
        cs.IFL1 = FLextern;
        cs.IEV1.Vsym = getRtlsym(RTLSYM_EXCEPT_LIST);
        cs.IEV1.Voffset = 0;
        cdb.gen(&cs);                            // MOV EDX,FS:__except_list

        cdb2.gen1(0x50 + DX);                      // PUSH EDX
    }
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

@trusted
void nteh_epilog(ref CodeBuilder cdb)
{
    if (config.exe != EX_WIN32)
        return;

    /* Generate:
        mov     ECX,__context[EBP].prev
        mov     FS:__except_list,ECX
     */
    code cs;
    reg_t reg;

version (MARS)
    reg = CX;
else
    reg = (tybasic(funcsym_p.Stype.Tnext.Tty) == TYvoid) ? AX : CX;

    useregs(1 << reg);

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
    cs.IEV1.Vsym = getRtlsym(RTLSYM_EXCEPT_LIST);
    cs.IEV1.Voffset = 0;
    cdb.gen(&cs);
}

/**************************
 * Set/Reset ESP from context.
 */

@trusted
void nteh_setsp(ref CodeBuilder cdb, opcode_t op)
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

@trusted
void nteh_filter(ref CodeBuilder cdb, block *b)
{
    code cs;

    assert(b.BC == BC_filter);
    if (b.Bflags & BFLehcode)          // if referenced __ecode
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
        cs.IEV1.Vsym = nteh_ecodesym();
        cs.IEV1.Voffset = 0;
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
        cdb.ctor();
        cdb.gencs(0xB8+AX,0,FLextern,scopetable);  // MOV EAX,&scope_table

version (MARS)
        cdb.gencs(0xE9,0,FLfunc,getRtlsym(RTLSYM_D_HANDLER));      // JMP _d_framehandler
else
        cdb.gencs(0xE9,0,FLfunc,getRtlsym(RTLSYM_CPP_HANDLER));    // JMP __cpp_framehandler

        code *c = cdb.finish();
        pinholeopt(c,null);
        codout(sfunc.Sseg,c);
        code_free(c);
    }
}

/*********************************
 * Generate code to set scope index.
 */

code *nteh_patchindex(code* c, int sindex)
{
    c.IEV2.Vsize_t = sindex;
    return c;
}

@trusted
void nteh_gensindex(ref CodeBuilder cdb, int sindex)
{
    if (!(config.ehmethod == EHmethod.EH_WIN32 || config.ehmethod == EHmethod.EH_SEH) || funcsym_p.Sfunc.Fflags3 & Feh_none)
        return;
    // Generate:
    //  MOV     -4[EBP],sindex

    cdb.genc(0xC7,modregrm(1,0,BP),FLconst,cast(targ_uns)nteh_EBPoffset_sindex(),FLconst,sindex); // 7 bytes long
    cdb.last().Iflags |= CFvolatile;

    //assert(GENSINDEXSIZE == calccodsize(c));
}

/*********************************
 * Generate code for setjmp().
 */

@trusted
void cdsetjmp(ref CodeBuilder cdb, elem *e,regm_t *pretregs)
{
    code cs;
    regm_t retregs;
    uint stackpushsave;
    uint flag;

    stackpushsave = stackpush;
version (SCPP)
{
    if (CPP && (funcsym_p.Sfunc.Fflags3 & Fcppeh || usednteh & NTEHcpp))
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
        Symbol *s;

        s = except_gensym();
        if (!s)
            goto L1;

        cdb.gencs(0x68,0,FLextern,s);                 // PUSH &scope_table
        stackpush += 4;
        cdb.genadjesp(4);

        cdb.genc1(0xFF,modregrm(1,6,BP),FLconst,cast(targ_uns)-4);
                                                // PUSH trylevel
        stackpush += 4;
        cdb.genadjesp(4);

        cs.Iop = 0x68;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IFL2 = FLextern;
        cs.IEV2.Vsym = getRtlsym(RTLSYM_CPP_LONGJMP);
        cs.IEV2.Voffset = 0;
        cdb.gen(&cs);                         // PUSH &_cpp_longjmp_unwind
        stackpush += 4;
        cdb.genadjesp(4);

        flag = 3;
        goto L2;
    }
}
    if (funcsym_p.Sfunc.Fflags3 & Fnteh)
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
        cs.IEV1.Vsym = nteh_contextsym();
        cs.IEV1.Voffset = sindex_off;
        cdb.gen(&cs);                 // PUSH scope_index
        stackpush += 4;
        cdb.genadjesp(4);

        cs.Iop = 0x68;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IFL2 = FLextern;
        cs.IEV2.Vsym = getRtlsym(RTLSYM_LONGJMP);
        cs.IEV2.Voffset = 0;
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
L2:
    cs.Iop = 0x68;
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL2 = FLconst;
    cs.IEV2.Vint = flag;
    cdb.gen(&cs);                     // PUSH flag
    stackpush += 4;
    cdb.genadjesp(4);

    pushParams(cdb,e.EV.E1,REGSIZE, TYnfunc);

    getregs(cdb,~getRtlsym(RTLSYM_SETJMP3).Sregsaved & (ALLREGS | mES));
    cdb.gencs(0xE8,0,FLfunc,getRtlsym(RTLSYM_SETJMP3));      // CALL __setjmp3

    cod3_stackadj(cdb, -(stackpush - stackpushsave));
    cdb.genadjesp(-(stackpush - stackpushsave));

    stackpush = stackpushsave;
    retregs = regmask(e.Ety, TYnfunc);
    fixresult(cdb,e,retregs,pretregs);
}

/****************************************
 * Call _local_unwind(), which means call the __finally blocks until
 * stop_index is reached.
 * Params:
 *      cdb = append generated code to
 *      saveregs = registers to save across the generated code
 *      stop_index = index to stop at
 */

@trusted
void nteh_unwind(ref CodeBuilder cdb,regm_t saveregs,uint stop_index)
{
    // Shouldn't this always be CX?
version (SCPP)
    const reg_t reg = AX;
else
    const reg_t reg = CX;

version (MARS)
    // https://github.com/dlang/druntime/blob/master/src/rt/deh_win32.d#L924
    const int local_unwind = RTLSYM_D_LOCAL_UNWIND2;    // __d_local_unwind2()
else
    // dm/src/win32/ehsup.c
    const int local_unwind = RTLSYM_LOCAL_UNWIND2;      // __local_unwind2()

    const regm_t desregs = (~getRtlsym(local_unwind).Sregsaved & (ALLREGS)) | (1 << reg);
    CodeBuilder cdbs;
    cdbs.ctor();
    CodeBuilder cdbr;
    cdbr.ctor();
    gensaverestore(saveregs & desregs,cdbs,cdbr);

    CodeBuilder cdbx;
    cdbx.ctor();
    getregs(cdbx,desregs);

    code cs;
    cs.Iop = LEA;
    cs.Irm = modregrm(2,reg,BPRM);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FLconst;
    // EBP offset of __context.prev
    cs.IEV1.Vint = nteh_EBPoffset_prev();
    cdbx.gen(&cs);                             // LEA  ECX,contextsym

    int nargs = 0;
version (SCPP)
{
    const int take_addr = 1;
    cdbx.genc2(0x68,0,take_addr);                  // PUSH take_addr
    ++nargs;
}

    cdbx.genc2(0x68,0,stop_index);                 // PUSH stop_index
    cdbx.gen1(0x50 + reg);                         // PUSH ECX            ; DEstablisherFrame
    nargs += 2;
version (MARS)
{
    cdbx.gencs(0x68,0,FLextern,nteh_scopetable());      // PUSH &scope_table    ; DHandlerTable
    ++nargs;
}

    cdbx.gencs(0xE8,0,FLfunc,getRtlsym(local_unwind));  // CALL _local_unwind()
    cod3_stackadj(cdbx, -nargs * 4);

    cdb.append(cdbs);
    cdb.append(cdbx);
    cdb.append(cdbr);
}

/*************************************************
 * Set monitor, hook monitor exception handler.
 */

version (MARS)
{
@trusted
void nteh_monitor_prolog(ref CodeBuilder cdb, Symbol *shandle)
{
    /*
     *  PUSH    handle
     *  PUSH    offset _d_monitor_handler
     *  PUSH    FS:__except_list
     *  MOV     FS:__except_list,ESP
     *  CALL    _d_monitor_prolog
     */
    CodeBuilder cdbx;
    cdbx.ctor();

    assert(config.exe == EX_WIN32);    // BUG: figure out how to implement for other EX's

    if (shandle.Sclass == SCfastpar)
    {   assert(shandle.Spreg != DX);
        assert(shandle.Spreg2 == NOREG);
        cdbx.gen1(0x50 + shandle.Spreg);   // PUSH shandle
    }
    else
    {
        // PUSH shandle
        useregs(mCX);
        cdbx.genc1(0x8B,modregrm(2,CX,4),FLconst,4 * (1 + needframe) + shandle.Soffset + localsize);
        cdbx.last().Isib = modregrm(0,4,SP);
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
    cs.IEV1.Vsym = getRtlsym(RTLSYM_EXCEPT_LIST);
    cs.IEV1.Voffset = 0;
    cdb.gen(&cs);                   // MOV EDX,FS:__except_list

    cdbx.gen1(0x50 + DX);                  // PUSH EDX

    Symbol *s = getRtlsym(RTLSYM_MONITOR_PROLOG);
    regm_t desregs = ~s.Sregsaved & ALLREGS;
    getregs(cdbx,desregs);
    cdbx.gencs(0xE8,0,FLfunc,s);       // CALL _d_monitor_prolog

    cs.Iop = 0x89;
    NEWREG(cs.Irm,SP);
    cdbx.gen(&cs);                         // MOV FS:__except_list,ESP

    cdb.append(cdbx);
}

}

/*************************************************
 * Release monitor, unhook monitor exception handler.
 * Input:
 *      retregs         registers to not destroy
 */

version (MARS)
{

@trusted
void nteh_monitor_epilog(ref CodeBuilder cdb,regm_t retregs)
{
    /*
     *  CALL    _d_monitor_epilog
     *  POP     FS:__except_list
     */

    assert(config.exe == EX_WIN32);    // BUG: figure out how to implement for other EX's

    Symbol *s = getRtlsym(RTLSYM_MONITOR_EPILOG);
    //desregs = ~s.Sregsaved & ALLREGS;
    regm_t desregs = 0;
    CodeBuilder cdbs;
    cdbs.ctor();
    CodeBuilder cdbr;
    cdbr.ctor();
    gensaverestore(retregs& desregs,cdbs,cdbr);
    cdb.append(cdbs);

    getregs(cdb,desregs);
    cdb.gencs(0xE8,0,FLfunc,s);               // CALL __d_monitor_epilog

    cdb.append(cdbr);

    code cs;
    cs.Iop = 0x8F;
    cs.Irm = modregrm(0,0,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FLextern;
    cs.IEV1.Vsym = getRtlsym(RTLSYM_EXCEPT_LIST);
    cs.IEV1.Voffset = 0;
    cdb.gen(&cs);                       // POP FS:__except_list
}

}

}
}
