/**
 * Support for NT exception handling
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/x86/nteh.d, backend/nteh.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/x86/nteh.d
 * Documentation:  https://dlang.org/phobos/dmd_backend_x86_nteh.html
 */

module dmd.backend.x86.nteh;

import core.stdc.stdio;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

static if (NTEXCEPTIONS)
{


nothrow:
@safe:

import dmd.backend.eh : except_fillInEHTable;

private __gshared
{
    Symbol* s_table;
    //Symbol* s_context;
}

private
{
    //immutable string s_name_context_tag = "__nt_context";
    immutable string s_name_context = "__context";
}

// member stable is not used for MARS or C++

int nteh_EBPoffset_sindex()     { return -4; }
int nteh_EBPoffset_prev()       { return -nteh_contextsym_size() + 8; }
int nteh_EBPoffset_info()       { return -nteh_contextsym_size() + 4; }
int nteh_EBPoffset_esp()        { return -nteh_contextsym_size() + 0; }

int nteh_offset_sindex()        { return 16; }
int nteh_offset_sindex_seh()    { return 20; }
int nteh_offset_info()          { return 4; }

/***********************************
 */

@trusted
ubyte* nteh_context_string()
{
    if (config.exe == EX_WIN32)
    {
        immutable string text_nt =
            "struct __nt_context {" ~
                "int esp; int info; int prev; int handler; int stable; int sindex; int ebp;" ~
             "};\n";

        return cast(ubyte*)text_nt.ptr;
    }
    else
        return null;
}

/*******************************
 * Get symbol for scope table for current function.
 * Returns:
 *      symbol of table
 */

@trusted
private Symbol* nteh_scopetable()
{
    Symbol* s;
    type* t;

    if (!s_table)
    {
        t = type_alloc(TYint);
        s = symbol_generate(SC.static_,t);
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
    Symbol* s = s_table;
    symbol_debug(s);
    except_fillInEHTable(s);
}

/****************************
 * Generate and output scope table.
 * Not called for NTEH C++ exceptions
 */

@trusted
void nteh_gentables(Symbol* sfunc)
{
    Symbol* s = s_table;
    symbol_debug(s);
    //except_fillInEHTable(s);

    outdata(s);                 // output the scope table
    nteh_framehandler(sfunc, s);
    s_table = null;
}

/**************************
 * Declare frame variables.
 */

@trusted
void nteh_declarvars(BlockState* bx)
{
    //printf("nteh_declarvars()\n");
    if (!(bx.funcsym.Sfunc.Fflags3 & Fnteh)) // if haven't already done it
    {   bx.funcsym.Sfunc.Fflags3 |= Fnteh;
        Symbol* s = symbol_name(s_name_context,SC.bprel,tstypes[TYint]);
        s.Soffset = -5 * 4;            // -6 * 4 for C __try, __except, __finally
        s.Sflags |= SFLfree | SFLnodebug;
        type_setty(&s.Stype,mTYvolatile | TYint);
        symbol_add(s);
        bx.context = s;
    }
}

/**************************************
 * Generate elem that sets the context index into the scope table.
 */
elem* nteh_setScopeTableIndex(BlockState* blx, int scope_index)
{
    Symbol* s = blx.context;
    symbol_debug(s);
    elem* e = el_var(s);
    e.Voffset = nteh_offset_sindex();
    return el_bin(OPeq, TYint, e, el_long(TYint, scope_index));
}


/**********************************
 * Returns: pointer to context symbol.
 */

@trusted
Symbol* nteh_contextsym()
{
    foreach (Symbol* sp; globsym)
    {
        symbol_debug(sp);
        if (strcmp(sp.Sident.ptr,s_name_context.ptr) == 0)
            return sp;
    }
    assert(0);
}

/**********************************
 * Returns: size of context symbol on stack.
 */
@trusted
uint nteh_contextsym_size()
{
    int sz;

    if (cgstate.usednteh & NTEH_try)
    {
        sz = 5 * 4;
    }
    else if (cgstate.usednteh & NTEHcpp)
    {
        sz = 5 * 4;                     // C++ context record
    }
    else if (cgstate.usednteh & NTEHpassthru)
    {
        sz = 1 * 4;
    }
    else
        sz = 0;                         // no context record
    return sz;
}

/**********************************
 * Return: pointer to ecode symbol.
 */

@trusted
Symbol* nteh_ecodesym()
{
    foreach (Symbol* sp; globsym)
    {
        if (strcmp(sp.Sident.ptr, "__ecode") == 0)
            return sp;
    }
    assert(0);
}

/*********************************
 * Mark EH variables as used so that they don't get optimized away.
 */

void nteh_usevars()
{
    // Turn off SFLdead and SFLunambig in Sflags
    nteh_contextsym().Sflags &= ~SFLdead;
    nteh_contextsym().Sflags |= SFLread;
}

/*********************************
 * Generate NT exception handling function prolog.
 */

@trusted
void nteh_prolog(ref CodeBuilder cdb)
{
    code cs;

    if (cgstate.usednteh & NTEHpassthru)
    {
        /* An sindex value of -2 is a magic value that tells the
         * stack unwinder to skip this frame.
         */
        assert(config.exe & EX_posix);
        cs.Iop = 0x68;
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL2 = FL.const_;
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
    cs.IFL2 = FL.const_;
    cs.IEV2.Vint = -1;
    cdb.gen(&cs);                 // PUSH -1

    // PUSH &framehandler
    cs.IFL2 = FL.framehandler;
    nteh_scopetable();


    CodeBuilder cdb2;
    cdb2.ctor();
    cdb2.gen(&cs);                          // PUSH &__except_handler3

    if (config.exe == EX_WIN32)
    {
        makeitextern(getRtlsym(RTLSYM.EXCEPT_LIST));
    static if (0)
    {
        cs.Iop = 0xFF;
        cs.Irm = modregrm(0,6,BPRM);
        cs.Iflags = CFfs;
        cs.Irex = 0;
        cs.IFL1 = FL.extern_;
        cs.IEV1.Vsym = getRtlsym(RTLSYM.EXCEPT_LIST);
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
        cs.IFL1 = FL.extern_;
        cs.IEV1.Vsym = getRtlsym(RTLSYM.EXCEPT_LIST);
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
    reg_t reg = CX;
    useregs(1UL << reg);

    code cs;
    cs.Iop = 0x8B;
    cs.Irm = modregrm(2,reg,BPRM);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FL.const_;
    // EBP offset of __context.prev
    cs.IEV1.Vint = nteh_EBPoffset_prev();
    cdb.gen(&cs);

    cs.Iop = 0x89;
    cs.Irm = modregrm(0,reg,BPRM);
    cs.Iflags |= CFfs;
    cs.IFL1 = FL.extern_;
    cs.IEV1.Vsym = getRtlsym(RTLSYM.EXCEPT_LIST);
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
    cs.IFL1 = FL.const_;
    // EBP offset of __context.esp
    cs.IEV1.Vint = nteh_EBPoffset_esp();
    cdb.gen(&cs);               // MOV ESP,__context[EBP].esp
}

/****************************
 * Put out prolog for BC._filter block.
 */

@trusted
void nteh_filter(ref CodeBuilder cdb, block* b)
{
    assert(b.bc == BC._filter);
    if (b.Bflags & BFL.ehcode)          // if referenced __ecode
    {
        /* Generate:
                mov     EAX,__context[EBP].info
                mov     EAX,[EAX]
                mov     EAX,[EAX]
                mov     __ecode[EBP],EAX
         */

        getregs(cdb,mAX);

        code cs;
        cs.Iop = 0x8B;
        cs.Irm = modregrm(2,AX,BPRM);
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL1 = FL.const_;
        // EBP offset of __context.info
        cs.IEV1.Vint = nteh_EBPoffset_info();
        cdb.gen(&cs);                 // MOV EAX,__context[EBP].info

        cs.Irm = modregrm(0,AX,0);
        cdb.gen(&cs);                     // MOV EAX,[EAX]
        cdb.gen(&cs);                     // MOV EAX,[EAX]

        cs.Iop = 0x89;
        cs.Irm = modregrm(2,AX,BPRM);
        cs.IFL1 = FL.auto_;
        cs.IEV1.Vsym = nteh_ecodesym();
        cs.IEV1.Voffset = 0;
        cdb.gen(&cs);                     // MOV __ecode[EBP],EAX
    }
}

/*******************************
 * Generate C++ or D frame handler.
 */

void nteh_framehandler(Symbol* sfunc, Symbol* scopetable)
{
    // Generate:
    //  MOV     EAX,&scope_table
    //  JMP     __cpp_framehandler

    if (scopetable)
    {
        symbol_debug(scopetable);
        CodeBuilder cdb;
        cdb.ctor();
        cdb.gencs(0xB8+AX,0,FL.extern_,scopetable);  // MOV EAX,&scope_table

        cdb.gencs(0xE9,0,FL.func,getRtlsym(RTLSYM.D_HANDLER));      // JMP _d_framehandler

        code* c = cdb.finish();
        pinholeopt(c,null);
        targ_size_t framehandleroffset;
        codout(sfunc.Sseg,c,null,framehandleroffset);
        code_free(c);
    }
}

/*********************************
 * Generate code to set scope index.
 */

code* nteh_patchindex(code* c, int sindex)
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

    cdb.genc(0xC7,modregrm(1,0,BP),FL.const_,cast(targ_uns)nteh_EBPoffset_sindex(),FL.const_,sindex); // 7 bytes long
    cdb.last().Iflags |= CFvolatile;

    //assert(GENSINDEXSIZE == calccodsize(c));
}

/*********************************
 * Generate code for setjmp().
 */

@trusted
void cdsetjmp(ref CGstate cg, ref CodeBuilder cdb, elem* e,ref regm_t pretregs)
{
    code cs;
    regm_t retregs;
    uint flag;

    const stackpushsave = cgstate.stackpush;
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

        int sindex_off = 20;                // offset of __context.sindex
        cs.Iop = 0xFF;
        cs.Irm = modregrm(2,6,BPRM);
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL1 = FL.bprel;
        cs.IEV1.Vsym = nteh_contextsym();
        cs.IEV1.Voffset = sindex_off;
        cdb.gen(&cs);                 // PUSH scope_index
        cgstate.stackpush += 4;
        cdb.genadjesp(4);

        cs.Iop = 0x68;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IFL2 = FL.extern_;
        cs.IEV2.Vsym = getRtlsym(RTLSYM.LONGJMP);
        cs.IEV2.Voffset = 0;
        cdb.gen(&cs);                 // PUSH &_seh_longjmp_unwind
        cgstate.stackpush += 4;
        cdb.genadjesp(4);

        flag = 2;
    }
    else
    {
        /*  If the frame calling setjmp has neither a try..except, nor a
            try..catch, then call setjmp3 as follows:
            _setjmp3(environment,0)
         */
        flag = 0;
    }
    cs.Iop = 0x68;
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL2 = FL.const_;
    cs.IEV2.Vint = flag;
    cdb.gen(&cs);                     // PUSH flag
    cgstate.stackpush += 4;
    cdb.genadjesp(4);

    pushParams(cdb,e.E1,REGSIZE, TYnfunc);

    getregs(cdb,~getRtlsym(RTLSYM.SETJMP3).Sregsaved & (ALLREGS | mES));
    cdb.gencs(0xE8,0,FL.func,getRtlsym(RTLSYM.SETJMP3));      // CALL __setjmp3

    cod3_stackadj(cdb, -(cgstate.stackpush - stackpushsave));
    cdb.genadjesp(-(cgstate.stackpush - stackpushsave));

    cgstate.stackpush = stackpushsave;
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
    const reg_t reg = CX;

    // https://github.com/dlang/dmd/blob/cdfadf8a18f474e6a1b8352af2541efe3e3467cc/druntime/src/rt/deh_win32.d#L934
    const local_unwind = RTLSYM.D_LOCAL_UNWIND2;    // __d_local_unwind2()

    const regm_t desregs = (~getRtlsym(local_unwind).Sregsaved & (ALLREGS)) | (1UL << reg);
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
    cs.IFL1 = FL.const_;
    // EBP offset of __context.prev
    cs.IEV1.Vint = nteh_EBPoffset_prev();
    cdbx.gen(&cs);                             // LEA  ECX,contextsym

    int nargs = 0;

    cdbx.genc2(0x68,0,stop_index);                 // PUSH stop_index
    cdbx.gen1(0x50 + reg);                         // PUSH ECX            ; DEstablisherFrame
    nargs += 2;
    cdbx.gencs(0x68,0,FL.extern_,nteh_scopetable());      // PUSH &scope_table    ; DHandlerTable
    ++nargs;

    cdbx.gencs(0xE8,0,FL.func,getRtlsym(local_unwind));  // CALL _local_unwind()
    cod3_stackadj(cdbx, -nargs * 4);

    cdb.append(cdbs);
    cdb.append(cdbx);
    cdb.append(cdbr);
}

/*************************************************
 * Set monitor, hook monitor exception handler.
 */

@trusted
void nteh_monitor_prolog(ref CodeBuilder cdb, Symbol* shandle)
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

    if (shandle.Sclass == SC.fastpar)
    {   assert(shandle.Spreg != DX);
        assert(shandle.Spreg2 == NOREG);
        cdbx.gen1(0x50 + shandle.Spreg);   // PUSH shandle
    }
    else
    {
        // PUSH shandle
        useregs(mCX);
        cdbx.genc1(0x8B,modregrm(2,CX,4),FL.const_,4 * (1 + cgstate.needframe) + shandle.Soffset + localsize);
        cdbx.last().Isib = modregrm(0,4,SP);
        cdbx.gen1(0x50 + CX);                      // PUSH ECX
    }

    Symbol* smh = getRtlsym(RTLSYM.MONITOR_HANDLER);
    cdbx.gencs(0x68,0,FL.extern_,smh);             // PUSH offset _d_monitor_handler
    makeitextern(smh);

    code cs;
    useregs(mDX);
    cs.Iop = 0x8B;
    cs.Irm = modregrm(0,DX,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FL.extern_;
    cs.IEV1.Vsym = getRtlsym(RTLSYM.EXCEPT_LIST);
    cs.IEV1.Voffset = 0;
    cdb.gen(&cs);                   // MOV EDX,FS:__except_list

    cdbx.gen1(0x50 + DX);                  // PUSH EDX

    Symbol* s = getRtlsym(RTLSYM.MONITOR_PROLOG);
    regm_t desregs = ~s.Sregsaved & ALLREGS;
    getregs(cdbx,desregs);
    cdbx.gencs(0xE8,0,FL.func,s);       // CALL _d_monitor_prolog

    cs.Iop = 0x89;
    NEWREG(cs.Irm,SP);
    cdbx.gen(&cs);                         // MOV FS:__except_list,ESP

    cdb.append(cdbx);
}

/*************************************************
 * Release monitor, unhook monitor exception handler.
 * Input:
 *      retregs         registers to not destroy
 */

@trusted
void nteh_monitor_epilog(ref CodeBuilder cdb,regm_t retregs)
{
    /*
     *  CALL    _d_monitor_epilog
     *  POP     FS:__except_list
     */

    assert(config.exe == EX_WIN32);    // BUG: figure out how to implement for other EX's

    Symbol* s = getRtlsym(RTLSYM.MONITOR_EPILOG);
    //desregs = ~s.Sregsaved & ALLREGS;
    regm_t desregs = 0;
    CodeBuilder cdbs;
    cdbs.ctor();
    CodeBuilder cdbr;
    cdbr.ctor();
    gensaverestore(retregs& desregs,cdbs,cdbr);
    cdb.append(cdbs);

    getregs(cdb,desregs);
    cdb.gencs(0xE8,0,FL.func,s);               // CALL __d_monitor_epilog

    cdb.append(cdbr);

    code cs;
    cs.Iop = 0x8F;
    cs.Irm = modregrm(0,0,BPRM);
    cs.Iflags = CFfs;
    cs.Irex = 0;
    cs.IFL1 = FL.extern_;
    cs.IEV1.Vsym = getRtlsym(RTLSYM.EXCEPT_LIST);
    cs.IEV1.Voffset = 0;
    cdb.gen(&cs);                       // POP FS:__except_list
}

}
