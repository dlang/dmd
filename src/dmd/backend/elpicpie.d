/**
 * Generate elems for fixed, PIC, and PIE code generation.
 *
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/elpicpie.d, backend/elpicpie.d)
 */

module dmd.backend.elpicpie;

version (SCPP)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (HTOD)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (MARS)
{
    version = COMPILE;
}

version (COMPILE)
{

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.ty;
import dmd.backend.type;

version (SCPP_HTOD)
{
    import msgs2;
}

extern (C++):

nothrow:
@safe:

/**************************
 * Make an elem out of a symbol.
 */

version (MARS)
{
@trusted
elem * el_var(Symbol *s)
{
    elem *e;
    //printf("el_var(s = '%s')\n", s.Sident);
    //printf("%x\n", s.Stype.Tty);
    if (config.exe & EX_posix)
    {
        if (config.flags3 & CFG3pie &&
            s.Stype.Tty & mTYthread)
            return el_pievar(s);            // Position Independent Executable

        if (config.flags3 & CFG3pic &&
            !tyfunc(s.ty()))
            return el_picvar(s);            // Position Independent Code
    }

    if (config.exe & (EX_OSX | EX_OSX64))
    {
    }
    else if (config.exe & EX_posix)
    {
        if (config.flags3 & CFG3pic && tyfunc(s.ty()))
        {
            switch (s.Sclass)
            {
                case SCcomdat:
                case SCcomdef:
                case SCglobal:
                case SCextern:
                    el_alloc_localgot();
                    break;

                default:
                    break;
            }
        }
    }
    symbol_debug(s);
    type_debug(s.Stype);
    e = el_calloc();
    e.Eoper = OPvar;
    e.EV.Vsym = s;
    type_debug(s.Stype);
    e.Ety = s.ty();
    if (s.Stype.Tty & mTYthread)
    {
        //printf("thread local %s\n", s.Sident);
if (config.exe & (EX_OSX | EX_OSX64))
{
}
else if (config.exe & EX_posix)
{
        /* For 32 bit:
         * Generate for var locals:
         *      MOV reg,GS:[00000000]   // add GS: override in back end
         *      ADD reg, offset s@TLS_LE
         *      e => *(&s + *(GS:0))
         * For var globals:
         *      MOV reg,GS:[00000000]
         *      ADD reg, s@TLS_IE
         *      e => *(s + *(GS:0))
         * note different fixup
         *****************************************
         * For 64 bit:
         * Generate for var locals:
         *      MOV reg,FS:s@TPOFF32
         * For var globals:
         *      MOV RAX,s@GOTTPOFF[RIP]
         *      MOV reg,FS:[RAX]
         *
         * For address of locals:
         *      MOV RAX,FS:[00]
         *      LEA reg,s@TPOFF32[RAX]
         *      e => &s + *(FS:0)
         * For address of globals:
         *      MOV reg,FS:[00]
         *      MOV RAX,s@GOTTPOFF[RIP]
         *      ADD reg,RAX
         *      e => s + *(FS:0)
         * This leaves us with a problem, as the 'var' version cannot simply have
         * its address taken, as what is the address of FS:s ? The (not so efficient)
         * solution is to just use the second address form, and * it.
         * Turns out that is identical to the 32 bit version, except GS => FS and the
         * fixups are different.
         * In the future, we should figure out a way to optimize to the 'var' version.
         */
        if (I64)
            Obj.refGOTsym();
        elem *e1 = el_calloc();
        e1.EV.Vsym = s;
        if (s.Sclass == SCstatic || s.Sclass == SClocstat)
        {
            e1.Eoper = OPrelconst;
            e1.Ety = TYnptr;
        }
        else
        {
            e1.Eoper = OPvar;
            e1.Ety = TYnptr;
        }

        elem* e2 = el_una(OPind, TYsize, el_long(TYfgPtr, 0)); // I64: FS:[0000], I32: GS:[0000]

        e.Eoper = OPind;
        e.EV.E1 = el_bin(OPadd,e1.Ety,e2,e1);
        e.EV.E2 = null;
}
else if (config.exe & EX_windos)
{
        /*
            Win32:
                mov     EAX,FS:__tls_array
                mov     ECX,__tls_index
                mov     EAX,[ECX*4][EAX]
                inc     dword ptr _t[EAX]

                e => *(&s + *(FS:_tls_array + _tls_index * 4))

                If this is an executable app, not a dll, _tls_index
                can be assumed to be 0.

            Win64:

                mov     EAX,&s
                mov     RDX,GS:__tls_array
                mov     ECX,_tls_index[RIP]
                mov     RCX,[RCX*8][RDX]
                mov     EAX,[RCX][RAX]

                e => *(&s + *(GS:[80] + _tls_index * 8))

                If this is an executable app, not a dll, _tls_index
                can be assumed to be 0.
         */
        elem* e1,e2,ea;

        e1 = el_calloc();
        e1.Eoper = OPrelconst;
        e1.EV.Vsym = s;
        e1.Ety = TYnptr;

        if (config.wflags & WFexe)
        {
            // e => *(&s + *(FS:_tls_array))
            e2 = el_var(getRtlsym(RTLSYM_TLS_ARRAY));
        }
        else
        {
            e2 = el_bin(OPmul,TYint,el_var(getRtlsym(RTLSYM_TLS_INDEX)),el_long(TYint,REGSIZE));
            ea = el_var(getRtlsym(RTLSYM_TLS_ARRAY));
            e2 = el_bin(OPadd,ea.Ety,ea,e2);
        }
        e2 = el_una(OPind,TYsize_t,e2);

        e.Eoper = OPind;
        e.EV.E1 = el_bin(OPadd,e1.Ety,e1,e2);
        e.EV.E2 = null;
}
    }
    return e;
}
}

version (SCPP_HTOD)
{
elem * el_var(Symbol *s)
{
    elem *e;

    //printf("el_var(s = '%s')\n", s.Sident);
    if (config.exe & EX_posix)
    {
        if (config.flags3 & CFG3pic && !tyfunc(s.ty()))
            return el_picvar(s);
    }
    symbol_debug(s);
    type_debug(s.Stype);
    e = el_calloc();
    e.Eoper = OPvar;
    e.EV.Vsym = s;

    version (SCPP_HTOD)
        enum scpp = true;
    else
        enum scpp = false;

    if (scpp && PARSER)
    {
        type *t = s.Stype;
        type_debug(t);
        e.ET = t;
        t.Tcount++;
if (config.exe & EX_windos)
{
        switch (t.Tty & (mTYimport | mTYthread))
        {
            case mTYimport:
                Obj._import(e);
                break;

            case mTYthread:
        /*
                mov     EAX,FS:__tls_array
                mov     ECX,__tls_index
                mov     EAX,[ECX*4][EAX]
                inc     dword ptr _t[EAX]

                e => *(&s + *(FS:_tls_array + _tls_index * 4))
         */
        version (MARS)
                assert(0);
        else
        {
            {
                elem* e1,e2,ea;
                e1 = el_calloc();
                e1.Eoper = OPrelconst;
                e1.EV.Vsym = s;
                e1.ET = newpointer(s.Stype);
                e1.ET.Tcount++;

                e2 = el_bint(OPmul,tstypes[TYint],el_var(getRtlsym(RTLSYM_TLS_INDEX)),el_longt(tstypes[TYint],4));
                ea = el_var(getRtlsym(RTLSYM_TLS_ARRAY));
                e2 = el_bint(OPadd,ea.ET,ea,e2);
                e2 = el_unat(OPind,tstypes[TYint],e2);

                e.Eoper = OPind;
                e.EV.E1 = el_bint(OPadd,e1.ET,e1,e2);
                e.EV.E2 = null;
            }
        }
                break;

            case mTYthread | mTYimport:
                version (SCPP_HTOD) { } else assert(0);
                tx86err(EM_thread_and_dllimport,s.Sident.ptr);     // can't be both thread and import
                break;

            default:
                break;
        }
}
    }
    else
        e.Ety = s.ty();
    return e;
}
}

/**************************
 * Make a pointer to a `Symbol`.
 * Params: s = symbol
 * Returns: `elem` with address of `s`
 */

@trusted
elem * el_ptr(Symbol *s)
{
    //printf("el_ptr(s = '%s')\n", s.Sident.ptr);
    //printf("el_ptr\n");
    symbol_debug(s);
    type_debug(s.Stype);

    const typtr = s.symbol_pointerType();

    if (config.exe & (EX_OSX | EX_OSX64))
    {
        if (config.flags3 & CFG3pic && tyfunc(s.ty()) && I32)
        {
            /* Cannot access address of code from code.
             * Instead, create a data variable, put the address of the
             * code in that data variable, and return the elem for
             * that data variable.
             */
            Symbol *sd = symboldata(Offset(DATA), typtr);
            sd.Sseg = DATA;
            Obj.data_start(sd, _tysize[TYnptr], DATA);
            Offset(DATA) += Obj.reftoident(DATA, Offset(DATA), s, 0, CFoff);
            elem* e = el_picvar(sd);
            e.Ety = typtr;
            return e;
        }
    }

    if (config.exe & EX_posix)
    {
        if (config.flags3 & CFG3pie &&
            s.Stype.Tty & mTYthread)
        {
            elem* e = el_pieptr(s);            // Position Independent Executable
            e.Ety = typtr;
            return e;
        }

        if (config.flags3 & CFG3pie &&
            tyfunc(s.ty()) &&
            (s.Sclass == SCglobal || s.Sclass == SCcomdat || s.Sclass == SCcomdef || s.Sclass == SCextern))
        {
            elem* e = el_calloc();
            e.Eoper = OPvar;
            e.EV.Vsym = s;
            if (I64)
                e.Ety = typtr;
            else if (I32)
            {
                e.Ety = TYnptr;
                e.Eoper = OPrelconst;
                e = el_bin(OPadd, TYnptr, e, el_var(el_alloc_localgot()));
                e = el_una(OPind, typtr, e);
            }
            else
                assert(0);
            return e;
        }
    }

    elem *e;

    if (config.exe & EX_posix)
    {
        if (config.flags3 & CFG3pic &&
            tyfunc(s.ty()))
        {
            e = el_picvar(s);
        }
        else
            e = el_var(s);
    }
    else
        e = el_var(s);

    version (SCPP_HTOD)
    {
        if (PARSER)
        {   type_debug(e.ET);
            e = el_unat(OPaddr,type_ptr(e,e.ET),e);
            return e;
        }
    }

    if (e.Eoper == OPvar)
    {
        e.Ety = typtr;
        e.Eoper = OPrelconst;
    }
    else
    {
        e = el_una(OPaddr, typtr, e);
        e = doptelem(e, GOALvalue | GOALflags);
    }
    return e;
}


/***************************************
 * Allocate localgot symbol.
 */

@trusted
private Symbol *el_alloc_localgot()
{
    if (config.exe & EX_windos)
        return null;

    /* Since localgot is a local variable to each function,
     * localgot must be set back to null
     * at the start of code gen for each function.
     */
    if (I32 && !localgot)
    {
        //printf("el_alloc_localgot()\n");
        char[15] name = void;
        __gshared int tmpnum;
        sprintf(name.ptr, "_LOCALGOT%d".ptr, tmpnum++);
        type *t = type_fake(TYnptr);
        /* Make it volatile because we need it for calling functions, but that isn't
         * noticed by the data flow analysis. Hence, it may get deleted if we don't
         * make it volatile.
         */
        type_setcv(&t, mTYvolatile);
        localgot = symbol_name(name.ptr, SCauto, t);
        symbol_add(localgot);
        localgot.Sfl = FLauto;
        localgot.Sflags = SFLfree | SFLunambig | GTregcand;
    }
    return localgot;
}


/**************************
 * Make an elem out of a symbol, PIC style.
 */

@trusted
private elem *el_picvar(Symbol *s)
{
    if (config.exe & (EX_OSX | EX_OSX64))
        return el_picvar_OSX(s);
    else if (config.exe & EX_posix)
        return el_picvar_posix(s);
    assert(0);
}

@trusted
private elem *el_picvar_OSX(Symbol *s)
{
    elem *e;
    int x;

    //printf("el_picvar(s = '%s')", s.Sident); printf("  Sclass = "); WRclass((enum SC) s.Sclass); printf("\n");
    //symbol_print(s);
    symbol_debug(s);
    type_debug(s.Stype);
    e = el_calloc();
    e.Eoper = OPvar;
    e.EV.Vsym = s;
    e.Ety = s.ty();

    switch (s.Sclass)
    {
        case SCstatic:
        case SClocstat:
            x = 0;
            goto case_got;

        case SCcomdat:
        case SCcomdef:
            if (0 && I64)
            {
                x = 0;
                goto case_got;
            }
            goto case SCglobal;

        case SCglobal:
        case SCextern:
            static if (0)
            {
                if (s.Stype.Tty & mTYthread)
                    x = 0;
                else
                    x = 1;
            }
            else
                x = 1;

        case_got:
        {
            const op = e.Eoper;
            tym_t tym = e.Ety;
            e.Eoper = OPrelconst;
            e.Ety = TYnptr;
            if (I32)
                e = el_bin(OPadd, TYnptr, e, el_var(el_alloc_localgot()));
static if (1)
{
            if (I32 && s.Stype.Tty & mTYthread)
            {
                if (!tls_get_addr_sym)
                {
                    /* void *___tls_get_addr(void *ptr);
                     * Parameter ptr is passed in RDI, matching TYnfunc calling convention.
                     */
                    tls_get_addr_sym = symbol_name("___tls_get_addr",SCglobal,type_fake(TYnfunc));
                    symbol_keep(tls_get_addr_sym);
                }
                if (x == 1)
                    e = el_una(OPind, TYnptr, e);
                e = el_bin(OPcallns, TYnptr, el_var(tls_get_addr_sym), e);
                if (op == OPvar)
                    e = el_una(OPind, TYnptr, e);
            }
}
            if (I64 || !(s.Stype.Tty & mTYthread))
            {
                switch (op * 2 + x)
                {
                    case OPvar * 2 + 1:
                        e = el_una(OPind, TYnptr, e);
                        e = el_una(OPind, TYnptr, e);
                        break;

                    case OPvar * 2 + 0:
                    case OPrelconst * 2 + 1:
                        e = el_una(OPind, TYnptr, e);
                        break;

                    case OPrelconst * 2 + 0:
                        break;

                    default:
                        assert(0);
                }
            }
static if (1)
{
            /**
             * A thread local variable is outputted like the following D struct:
             *
             * struct TLVDescriptor(T)
             * {
             *     extern(C) T* function (TLVDescriptor*) thunk;
             *     size_t key;
             *     size_t offset;
             * }
             *
             * To access the value of the variable, the variable is accessed
             * like a plain global (__gshared) variable of the type
             * TLVDescriptor. The thunk is called and a pointer to the variable
             * itself is passed as the argument. The return value of the thunk
             * is a pointer to the value of the thread local variable.
             *
             * module foo;
             *
             * int bar;
             * pragma(mangle, "_D3foo3bari") extern __gshared TLVDescriptor!(int) barTLV;
             *
             * int a = *barTLV.thunk(&barTLV);
             */
            if (I64 && s.Stype.Tty & mTYthread)
            {
                e = el_una(OPaddr, TYnptr, e);
                e = el_bin(OPadd, TYnptr, e, el_long(TYullong, 0));
                e = el_una(OPind, TYnptr, e);
                e = el_una(OPind, TYnfunc, e);

                elem *e2 = el_calloc();
                e2.Eoper = OPvar;
                e2.EV.Vsym = s;
                e2.Ety = s.ty();
                e2.Eoper = OPrelconst;
                e2.Ety = TYnptr;

                e2 = el_una(OPind, TYnptr, e2);
                e2 = el_una(OPind, TYnptr, e2);
                e2 = el_una(OPaddr, TYnptr, e2);
                e2 = doptelem(e2, GOALvalue | GOALflags);
                e2 = el_bin(OPadd, TYnptr, e2, el_long(TYullong, 0));
                e2 = el_bin(OPcall, TYnptr, e, e2);
                e2 = el_una(OPind, TYint, e2);
                e = e2;
            }
}
            e.Ety = tym;
            break;
        }
        default:
            break;
    }
    return e;
}

@trusted
private elem *el_picvar_posix(Symbol *s)
{
    elem *e;
    int x;

    //printf("el_picvar(s = '%s')\n", s.Sident.ptr);
    symbol_debug(s);
    type_debug(s.Stype);
    e = el_calloc();
    e.Eoper = OPvar;
    e.EV.Vsym = s;
    e.Ety = s.ty();

    /* For 32 bit PIC:
     *      CALL __i686.get_pc_thunk.bx@PC32
     *      ADD  EBX,offset _GLOBAL_OFFSET_TABLE_@GOTPC[2]
     * Generate for var locals:
     *      MOV  reg,s@GOTOFF[014h][EBX]
     * For var globals:
     *      MOV  EAX,s@GOT32[EBX]
     *      MOV  reg,[EAX]
     * For TLS var locals and globals:
     *      LEA  EAX,s@TLS_GD[1*EBX+0] // must use SIB addressing
     *      CALL ___tls_get_addr@PLT32
     *      MOV  reg,[EAX]
     *****************************************
     * Generate for var locals:
     *      MOV reg,s@PC32[RIP]
     * For var globals:
     *      MOV RAX,s@GOTPCREL[RIP]
     *      MOV reg,[RAX]
     * For TLS var locals and globals:
     *      0x66
     *      LEA DI,s@TLSGD[RIP]
     *      0x66
     *      0x66
     *      0x48 (REX | REX_W)
     *      CALL __tls_get_addr@PLT32
     *      MOV reg,[RAX]
     */

    if (I64)
    {
        switch (s.Sclass)
        {
            case SCstatic:
            case SClocstat:
                x = 0;
                goto case_got64;

            case SCglobal:
                if (config.flags3 & CFG3pie)
                    x = 0;
                else
                    x = 1;
                goto case_got64;

            case SCcomdat:
            case SCcomdef:
            case SCextern:
                x = 1;
                goto case_got64;

            case_got64:
            {
                Obj.refGOTsym();
                const op = e.Eoper;
                tym_t tym = e.Ety;
                e.Ety = TYnptr;

                if (s.Stype.Tty & mTYthread)
                {
                    /* Add "volatile" to prevent e from being common subexpressioned.
                     * This is so we can preserve the magic sequence of instructions
                     * that the gnu linker patches:
                     *   lea EDI,x@tlsgd[RIP], call __tls_get_addr@plt
                     *      =>
                     *   mov EAX,gs[0], sub EAX,x@tpoff
                     */
                    e.Eoper = OPrelconst;
                    e.Ety |= mTYvolatile;
                    if (!tls_get_addr_sym)
                    {
                        /* void *__tls_get_addr(void *ptr);
                         * Parameter ptr is passed in RDI, matching TYnfunc calling convention.
                         */
                        tls_get_addr_sym = symbol_name("__tls_get_addr",SCglobal,type_fake(TYnfunc));
                        symbol_keep(tls_get_addr_sym);
                    }
                    e = el_bin(OPcall, TYnptr, el_var(tls_get_addr_sym), e);
                }

                switch (op * 2 + x)
                {
                    case OPvar * 2 + 1:
                        e = el_una(OPind, TYnptr, e);
                        break;

                    case OPvar * 2 + 0:
                    case OPrelconst * 2 + 1:
                        break;

                    case OPrelconst * 2 + 0:
                        e = el_una(OPaddr, TYnptr, e);
                        break;

                    default:
                        assert(0);
                }
                e.Ety = tym;
            }
                break;

            default:
                break;
        }
    }
    else
    {
        switch (s.Sclass)
        {
            /* local (and thread) symbols get only one level of indirection;
             * all globally known symbols get two.
             */
            case SCstatic:
            case SClocstat:
                x = 0;
                goto case_got;

            case SCglobal:
                if (config.flags3 & CFG3pie)
                    x = 0;
                else if (s.Stype.Tty & mTYthread)
                    x = 0;
                else
                    x = 1;
                goto case_got;

            case SCcomdat:
            case SCcomdef:
            case SCextern:
                if (s.Stype.Tty & mTYthread)
                    x = 0;
                else
                    x = 1;
            case_got:
            {
                const op = e.Eoper;
                tym_t tym = e.Ety;
                e.Eoper = OPrelconst;
                e.Ety = TYnptr;

                if (s.Stype.Tty & mTYthread)
                {
                    /* Add "volatile" to prevent e from being common subexpressioned.
                     * This is so we can preserve the magic sequence of instructions
                     * that the gnu linker patches:
                     *   lea EAX,x@tlsgd[1*EBX+0], call __tls_get_addr@plt
                     *      =>
                     *   mov EAX,gs[0], sub EAX,x@tpoff
                     * elf32-i386.c
                     */
                    e.Ety |= mTYvolatile;
                    if (!tls_get_addr_sym)
                    {
                        /* void *___tls_get_addr(void *ptr);
                         * Parameter ptr is passed in EAX, matching TYjfunc calling convention.
                         */
                        tls_get_addr_sym = symbol_name("___tls_get_addr",SCglobal,type_fake(TYjfunc));
                        symbol_keep(tls_get_addr_sym);
                    }
                    e = el_bin(OPcall, TYnptr, el_var(tls_get_addr_sym), e);
                }
                else
                {
                    e = el_bin(OPadd, TYnptr, e, el_var(el_alloc_localgot()));
                }

                switch (op * 2 + x)
                {
                    case OPvar * 2 + 1:
                        e = el_una(OPind, TYnptr, e);
                        e = el_una(OPind, TYnptr, e);
                        break;

                    case OPvar * 2 + 0:
                    case OPrelconst * 2 + 1:
                        e = el_una(OPind, TYnptr, e);
                        break;

                    case OPrelconst * 2 + 0:
                        break;

                    default:
                        assert(0);
                }
                e.Ety = tym;
                break;
            }
            default:
                break;
        }
    }
    return e;
}

/**********************************************
 * Create an elem for TLS variable `s`.
 * Use PIE protocol.
 * Params: s = variable's symbol
 * Returns: elem created
 */
@trusted
private elem *el_pievar(Symbol *s)
{
    if (config.exe & (EX_OSX | EX_OSX64))
        assert(0);

    int x;

    //printf("el_pievar(s = '%s')\n", s.Sident.ptr);
    symbol_debug(s);
    type_debug(s.Stype);
    auto e = el_calloc();
    e.Eoper = OPvar;
    e.EV.Vsym = s;
    e.Ety = s.ty();

    if (I64)
    {
        switch (s.Sclass)
        {
            case SCstatic:
            case SClocstat:
            case SCglobal:
                break;

            case SCcomdat:
            case SCcomdef:
            case SCextern:
            {
                /* Generate:
                 *   mov RAX,extern_tls@GOTTPOFF[RIP]
                 *   mov EAX,FS:[RAX]
                 */
                Obj.refGOTsym();
                tym_t tym = e.Ety;
                e.Ety = TYfgPtr;

                e = el_una(OPind, tym, e);
                break;
            }
            default:
                break;
        }
    }
    else
    {
        switch (s.Sclass)
        {
            case SCstatic:
            case SClocstat:
            case SCglobal:
                break;

            case SCcomdat:
            case SCcomdef:
            case SCextern:
            {
                /* Generate:
                 *   mov EAX,extern_tls@TLS_GOTIE[ECX]
                 *   mov EAX,GS:[EAX]
                 */
                tym_t tym = e.Ety;
                e.Eoper = OPrelconst;
                e.Ety = TYnptr;

                e = el_bin(OPadd, TYnptr, e, el_var(el_alloc_localgot()));
                e = el_una(OPind, TYfgPtr, e);
                e = el_una(OPind, tym, e);
                break;
            }
            default:
                break;
        }
    }
    return e;
}

/**********************************************
 * Create an address for TLS variable `s`.
 * Use PIE protocol.
 * Params: s = variable's symbol
 * Returns: elem created
 */
@trusted
private elem *el_pieptr(Symbol *s)
{
    if (config.exe & (EX_OSX | EX_OSX64))
        assert(0);

    int x;

    //printf("el_pieptr(s = '%s')\n", s.Sident.ptr);
    symbol_debug(s);
    type_debug(s.Stype);
    auto e = el_calloc();
    e.Eoper = OPrelconst;
    e.EV.Vsym = s;
    e.Ety = TYnptr;

    elem* e0 = el_una(OPind, TYsize, el_long(TYfgPtr, 0)); // I64: FS:[0000], I32: GS:[0000]

    if (I64)
    {
        Obj.refGOTsym();    // even though not used, generate reference to _GLOBAL_OFFSET_TABLE_
        switch (s.Sclass)
        {
            case SCstatic:
            case SClocstat:
            case SCglobal:
            {
                /* Generate:
                 *   mov RAX,FS:[0000]
                 *   add EAX,offset FLAG:global_tls@TPOFF32
                 */
                e = el_bin(OPadd, TYnptr, e0, e);
                break;
            }

            case SCcomdat:
            case SCcomdef:
            case SCextern:
            {
                /* Generate:
                 *   mov RAX,extern_tls@GOTTPOFF[RIP]
                 *   mov RDX,FS:[0000]
                 *   add RAX,EDX
                 */
                e.Eoper = OPvar;
                e = el_bin(OPadd, TYnptr, e0, e);
                break;
            }
            default:
                break;
        }
    }
    else
    {
        switch (s.Sclass)
        {
            case SCstatic:
            case SClocstat:
            {
                /* Generate:
                 *   mov LEA,global_tls@TLS_LE[ECX]
                 *   mov EDX,GS:[0000]
                 *   add EAX,EDX
                 */
                e = el_bin(OPadd, TYnptr, e, el_var(el_alloc_localgot()));
                e = el_bin(OPadd, TYnptr, e, e0);
                break;
            }

            case SCglobal:
            {
                /* Generate:
                 *   mov EAX,global_tls@TLS_LE[ECX]
                 *   mov EDX,GS:[0000]
                 *   add EAX,EDX
                 */
                e = el_bin(OPadd, TYnptr, e, el_var(el_alloc_localgot()));
                e = el_una(OPind, TYnptr, e);
                e = el_bin(OPadd, TYnptr, e, e0);
                break;
            }

            case SCcomdat:
            case SCcomdef:
            case SCextern:
            {
                /* Generate:
                 *   mov EAX,extern_tls@TLS_GOTIE[ECX]
                 *   mov EDX,GS:[0000]
                 *   add EAX,EDX
                 */
                e = el_bin(OPadd, TYnptr, e, el_var(el_alloc_localgot()));
                e = el_una(OPind, TYnptr, e);
                e = el_bin(OPadd, TYnptr, e, e0);
                break;
            }
            default:
                break;
        }
    }
    return e;
}


}
