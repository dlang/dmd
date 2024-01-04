/**
 * Compiler runtime function symbols
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1996-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/drtlsym.d, backend/drtlsym.d)
 */

module dmd.backend.drtlsym;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.global;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;


nothrow:

private __gshared Symbol*[RTLSYM.max + 1] rtlsym;

// This varies depending on C ABI
alias FREGSAVED = fregsaved;

/******************************************
 * Get Symbol corresponding to Dwarf "personality" function.
 * Returns:
 *      Personality function
 */
Symbol* getRtlsymPersonality() { return getRtlsym(RTLSYM.PERSONALITY); }


/******************************************
 * Get Symbol corresponding to i.
 * Params:
 *      i = RTLSYM.xxxx
 * Returns:
 *      runtime library Symbol
 */
Symbol *getRtlsym(RTLSYM i) @trusted
{
     Symbol** ps = &rtlsym[i];
     if (*ps)
        return *ps;

    __gshared type* t;
    __gshared type* tv;

    if (!t)
    {
        t = type_fake(TYnfunc);
        t.Tmangle = mTYman_c;
        t.Tcount++;

        // Variadic function
        tv = type_fake(TYnfunc);
        tv.Tmangle = mTYman_c;
        tv.Tcount++;
    }

    // Lazilly initialize only what we use
    switch (i)
    {
        case RTLSYM.THROWC:                 symbolz(ps,FLfunc,(mES | mBP),"_d_throwc", SFLexit, t); break;
        case RTLSYM.THROWDWARF:             symbolz(ps,FLfunc,(mES | mBP),"_d_throwdwarf", SFLexit, t); break;
        case RTLSYM.MONITOR_HANDLER:        symbolz(ps,FLfunc,FREGSAVED,"_d_monitor_handler", 0, tsclib); break;
        case RTLSYM.MONITOR_PROLOG:         symbolz(ps,FLfunc,FREGSAVED,"_d_monitor_prolog",0,t); break;
        case RTLSYM.MONITOR_EPILOG:         symbolz(ps,FLfunc,FREGSAVED,"_d_monitor_epilog",0,t); break;
        case RTLSYM.DCOVER2:                symbolz(ps,FLfunc,FREGSAVED,"_d_cover_register2", 0, t); break;
        case RTLSYM.DASSERT:                symbolz(ps,FLfunc,FREGSAVED,"_d_assert", SFLexit, t); break;
        case RTLSYM.DASSERTP:               symbolz(ps,FLfunc,FREGSAVED,"_d_assertp", SFLexit, t); break;
        case RTLSYM.DASSERT_MSG:            symbolz(ps,FLfunc,FREGSAVED,"_d_assert_msg", SFLexit, t); break;
        case RTLSYM.DUNITTEST:              symbolz(ps,FLfunc,FREGSAVED,"_d_unittest", 0, t); break;
        case RTLSYM.DUNITTESTP:             symbolz(ps,FLfunc,FREGSAVED,"_d_unittestp", 0, t); break;
        case RTLSYM.DUNITTEST_MSG:          symbolz(ps,FLfunc,FREGSAVED,"_d_unittest_msg", 0, t); break;
        case RTLSYM.DARRAYP:                symbolz(ps,FLfunc,FREGSAVED,"_d_arrayboundsp", SFLexit, t); break;
        case RTLSYM.DARRAY_SLICEP:          symbolz(ps,FLfunc,FREGSAVED,"_d_arraybounds_slicep", SFLexit, t); break;
        case RTLSYM.DARRAY_INDEXP:          symbolz(ps,FLfunc,FREGSAVED,"_d_arraybounds_indexp", SFLexit, t); break;
        case RTLSYM.DINVARIANT:             symbolz(ps,FLfunc,FREGSAVED,"_D9invariant12_d_invariantFC6ObjectZv", 0, tsdlib); break;
        case RTLSYM.MEMCPY:                 symbolz(ps,FLfunc,FREGSAVED,"memcpy",    0, t); break;
        case RTLSYM.MEMSET8:                symbolz(ps,FLfunc,FREGSAVED,"memset",    0, t); break;
        case RTLSYM.MEMSET16:               symbolz(ps,FLfunc,FREGSAVED,"_memset16", 0, t); break;
        case RTLSYM.MEMSET32:               symbolz(ps,FLfunc,FREGSAVED,"_memset32", 0, t); break;
        case RTLSYM.MEMSET64:               symbolz(ps,FLfunc,FREGSAVED,"_memset64", 0, t); break;
        case RTLSYM.MEMSET128:              symbolz(ps,FLfunc,FREGSAVED,"_memset128",0, t); break;
        case RTLSYM.MEMSET128ii:            symbolz(ps,FLfunc,FREGSAVED,"_memset128ii",0, t); break;
        case RTLSYM.MEMSET80:               symbolz(ps,FLfunc,FREGSAVED,"_memset80", 0, t); break;
        case RTLSYM.MEMSET160:              symbolz(ps,FLfunc,FREGSAVED,"_memset160",0, t); break;
        case RTLSYM.MEMSETFLOAT:            symbolz(ps,FLfunc,FREGSAVED,"_memsetFloat", 0, t); break;
        case RTLSYM.MEMSETDOUBLE:           symbolz(ps,FLfunc,FREGSAVED,"_memsetDouble", 0, t); break;
        case RTLSYM.MEMSETSIMD:             symbolz(ps,FLfunc,FREGSAVED,"_memsetSIMD",0, t); break;
        case RTLSYM.MEMSETN:                symbolz(ps,FLfunc,FREGSAVED,"_memsetn",  0, t); break;
        case RTLSYM.NEWCLASS:               symbolz(ps,FLfunc,FREGSAVED,"_d_newclass", 0, t); break;
        case RTLSYM.NEWTHROW:               symbolz(ps,FLfunc,FREGSAVED,"_d_newThrowable", 0, t); break;
        case RTLSYM.NEWARRAYT:              symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayT", 0, t); break;
        case RTLSYM.NEWARRAYIT:             symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayiT", 0, t); break;
        case RTLSYM.NEWITEMT:               symbolz(ps,FLfunc,FREGSAVED,"_d_newitemT", 0, t); break;
        case RTLSYM.NEWITEMIT:              symbolz(ps,FLfunc,FREGSAVED,"_d_newitemiT", 0, t); break;
        case RTLSYM.NEWARRAYMTX:            symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymTX", 0, t); break;
        case RTLSYM.NEWARRAYMITX:           symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymiTX", 0, t); break;
        case RTLSYM.ARRAYLITERALTX:         symbolz(ps,FLfunc,FREGSAVED,"_d_arrayliteralTX", 0, t); break;
        case RTLSYM.ASSOCARRAYLITERALTX:    symbolz(ps,FLfunc,FREGSAVED,"_d_assocarrayliteralTX", 0, t); break;
        case RTLSYM.CALLFINALIZER:          symbolz(ps,FLfunc,FREGSAVED,"_d_callfinalizer", 0, t); break;
        case RTLSYM.CALLINTERFACEFINALIZER: symbolz(ps,FLfunc,FREGSAVED,"_d_callinterfacefinalizer", 0, t); break;
        case RTLSYM.ALLOCMEMORY:            symbolz(ps,FLfunc,FREGSAVED,"_d_allocmemory", 0, t); break;
        case RTLSYM.DYNAMIC_CAST:           symbolz(ps,FLfunc,FREGSAVED,"_d_dynamic_cast", 0, t); break;
        case RTLSYM.INTERFACE_CAST:         symbolz(ps,FLfunc,FREGSAVED,"_d_interface_cast", 0, t); break;
        case RTLSYM.ARRAYCATT:              symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatT", 0, t); break;
        case RTLSYM.ARRAYCATNTX:            symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatnTX", 0, t); break;
        case RTLSYM.ARRAYAPPENDT:           symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendT", 0, t); break;
        case RTLSYM.ARRAYAPPENDCTX:         symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcTX", 0, t); break;
        case RTLSYM.ARRAYAPPENDCD:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcd", 0, t); break;
        case RTLSYM.ARRAYAPPENDWD:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendwd", 0, t); break;
        case RTLSYM.ARRAYSETLENGTHT:        symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthT", 0, t); break;
        case RTLSYM.ARRAYSETLENGTHIT:       symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthiT", 0, t); break;
        case RTLSYM.ARRAYCOPY:              symbolz(ps,FLfunc,FREGSAVED,"_d_arraycopy", 0, t); break;
        case RTLSYM.ARRAYASSIGN:            symbolz(ps,FLfunc,FREGSAVED,"_d_arrayassign", 0, t); break;
        case RTLSYM.ARRAYASSIGN_R:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayassign_r", 0, t); break;
        case RTLSYM.ARRAYASSIGN_L:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayassign_l", 0, t); break;
        case RTLSYM.ARRAYSETASSIGN:         symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetassign", 0, t); break;
        case RTLSYM.ARRAYEQ2:               symbolz(ps,FLfunc,FREGSAVED,"_adEq2", 0, t); break;

        /* Associative Arrays https://github.com/dlang/dmd/blob/master/druntime/src/rt/aaA.d */
        case RTLSYM.AANEW:                  symbolz(ps,FLfunc,FREGSAVED,"_aaNew",        0, t); break;
        case RTLSYM.AAEQUAL:                symbolz(ps,FLfunc,FREGSAVED,"_aaEqual",      0, t); break;
        case RTLSYM.AAINX:                  symbolz(ps,FLfunc,FREGSAVED,"_aaInX",        0, t); break;
        case RTLSYM.AADELX:                 symbolz(ps,FLfunc,FREGSAVED,"_aaDelX",       0, t); break;
        case RTLSYM.AAGETY:                 symbolz(ps,FLfunc,FREGSAVED,"_aaGetY",       0, t); break;
        case RTLSYM.AAGETRVALUEX:           symbolz(ps,FLfunc,FREGSAVED,"_aaGetRvalueX", 0, t); break;

        case RTLSYM.EXCEPT_HANDLER3:        symbolz(ps,FLfunc,fregsaved,"_except_handler3", 0, tsclib); break;
        case RTLSYM.CPP_HANDLER:            symbolz(ps,FLfunc,FREGSAVED,"_cpp_framehandler", 0, tsclib); break;
        case RTLSYM.D_HANDLER:              symbolz(ps,FLfunc,FREGSAVED,"_d_framehandler", 0, tsclib); break;
        case RTLSYM.D_LOCAL_UNWIND2:        symbolz(ps,FLfunc,FREGSAVED,"_d_local_unwind2", 0, tsclib); break;
        case RTLSYM.LOCAL_UNWIND2:          symbolz(ps,FLfunc,FREGSAVED,"_local_unwind2", 0, tsclib); break;
        case RTLSYM.UNWIND_RESUME:          symbolz(ps,FLfunc,FREGSAVED,"_Unwind_Resume", SFLexit, t); break;
        case RTLSYM.PERSONALITY:            symbolz(ps,FLfunc,FREGSAVED,"__dmd_personality_v0", 0, t); break;
        case RTLSYM.BEGIN_CATCH:            symbolz(ps,FLfunc,FREGSAVED,"__dmd_begin_catch", 0, t); break;
        case RTLSYM.CXA_BEGIN_CATCH:        symbolz(ps,FLfunc,FREGSAVED,"__cxa_begin_catch", 0, t); break;
        case RTLSYM.CXA_END_CATCH:          symbolz(ps,FLfunc,FREGSAVED,"__cxa_end_catch", 0, t); break;

        case RTLSYM.TLS_INDEX:              symbolz(ps,FLextern,0,"_tls_index",0,tstypes[TYint]); break;
        case RTLSYM.TLS_ARRAY:              symbolz(ps,FLextern,0,"_tls_array",0,tspvoid); break;
        case RTLSYM.AHSHIFT:                symbolz(ps,FLfunc,0,"_AHSHIFT",0,tstrace); break;

        case RTLSYM.HDIFFN:                 symbolz(ps,FLfunc,mBX|mCX|mSI|mDI|mBP|mES,"_aNahdiff", 0, tsclib); break;
        case RTLSYM.HDIFFF:                 symbolz(ps,FLfunc,mBX|mCX|mSI|mDI|mBP|mES,"_aFahdiff", 0, tsclib); break;
        case RTLSYM.INTONLY:                symbolz(ps,FLfunc,mSI|mDI,"_intonly", 0, tsclib); break;

        case RTLSYM.EXCEPT_LIST:            symbolz(ps,FLextern,0,"_except_list",0,tstypes[TYint]); break;
        case RTLSYM.SETJMP3:                symbolz(ps,FLfunc,FREGSAVED,"_setjmp3", 0, tsclib); break;
        case RTLSYM.LONGJMP:                symbolz(ps,FLfunc,FREGSAVED,"_seh_longjmp_unwind@4", 0, tsclib); break;
        case RTLSYM.ALLOCA:                 symbolz(ps,FLfunc,fregsaved,"__alloca", 0, tsclib); break;
        case RTLSYM.CPP_LONGJMP:            symbolz(ps,FLfunc,FREGSAVED,"_cpp_longjmp_unwind@4", 0, tsclib); break;
        case RTLSYM.PTRCHK:                 symbolz(ps,FLfunc,fregsaved,"_ptrchk", 0, tsclib); break;
        case RTLSYM.CHKSTK:                 symbolz(ps,FLfunc,fregsaved,"_chkstk", 0, tsclib); break;
        case RTLSYM.TRACE_PRO_N:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_pro_n",0,tstrace); break;
        case RTLSYM.TRACE_PRO_F:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_pro_f",0,tstrace); break;
        case RTLSYM.TRACE_EPI_N:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_epi_n",0,tstrace); break;
        case RTLSYM.TRACE_EPI_F:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_epi_f",0,tstrace); break;

        case RTLSYM.TRACENEWCLASS:          symbolz(ps,FLfunc,FREGSAVED,"_d_newclassTrace", 0, t); break;
        case RTLSYM.TRACENEWARRAYT:         symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayTTrace", 0, t); break;
        case RTLSYM.TRACENEWARRAYIT:        symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayiTTrace", 0, t); break;
        case RTLSYM.TRACENEWARRAYMTX:       symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymTXTrace", 0, t); break;
        case RTLSYM.TRACENEWARRAYMITX:      symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymiTXTrace", 0, t); break;
        case RTLSYM.TRACENEWITEMT:          symbolz(ps,FLfunc,FREGSAVED,"_d_newitemTTrace", 0, t); break;
        case RTLSYM.TRACENEWITEMIT:         symbolz(ps,FLfunc,FREGSAVED,"_d_newitemiTTrace", 0, t); break;
        case RTLSYM.TRACECALLFINALIZER:     symbolz(ps,FLfunc,FREGSAVED,"_d_callfinalizerTrace", 0, t); break;
        case RTLSYM.TRACECALLINTERFACEFINALIZER: symbolz(ps,FLfunc,FREGSAVED,"_d_callinterfacefinalizerTrace", 0, t); break;
        case RTLSYM.TRACEARRAYLITERALTX:    symbolz(ps,FLfunc,FREGSAVED,"_d_arrayliteralTXTrace", 0, t); break;
        case RTLSYM.TRACEASSOCARRAYLITERALTX: symbolz(ps,FLfunc,FREGSAVED,"_d_assocarrayliteralTXTrace", 0, t); break;
        case RTLSYM.TRACEARRAYCATT:         symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatTTrace", 0, t); break;
        case RTLSYM.TRACEARRAYCATNTX:       symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatnTXTrace", 0, t); break;
        case RTLSYM.TRACEARRAYAPPENDT:      symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendTTrace", 0, t); break;
        case RTLSYM.TRACEARRAYAPPENDCTX:    symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcTXTrace", 0, t); break;
        case RTLSYM.TRACEARRAYAPPENDCD:     symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcdTrace", 0, t); break;
        case RTLSYM.TRACEARRAYAPPENDWD:     symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendwdTrace", 0, t); break;
        case RTLSYM.TRACEARRAYSETLENGTHT:   symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthTTrace", 0, t); break;
        case RTLSYM.TRACEARRAYSETLENGTHIT:  symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthiTTrace", 0, t); break;
        case RTLSYM.TRACEALLOCMEMORY:       symbolz(ps,FLfunc,FREGSAVED,"_d_allocmemoryTrace", 0, t); break;
        case RTLSYM.C_ASSERT:               symbolz(ps,FLfunc,FREGSAVED,"_assert", SFLexit, t); break;
        case RTLSYM.C__ASSERT:              symbolz(ps,FLfunc,FREGSAVED,"__assert", SFLexit, t); break;
        case RTLSYM.C__ASSERT_FAIL:         symbolz(ps,FLfunc,FREGSAVED,"__assert_fail", SFLexit, t); break;
        case RTLSYM.C__ASSERT_RTN:          symbolz(ps,FLfunc,FREGSAVED,"__assert_rtn", SFLexit, t); break;

        case RTLSYM.CXA_ATEXIT:          symbolz(ps,FLfunc,FREGSAVED,"__cxa_atexit", 0, t); break;
        default:
            assert(0);
    }
    return *ps;
}


/******************************************
 * Create and initialize Symbol for runtime function.
 * Params:
 *    ps = where to store initialized Symbol pointer
 *    f = FLxxx
 *    regsaved = registers not altered by function
 *    name = name of function
 *    flags = value for Sflags
 *    t = type of function
 */
private void symbolz(Symbol** ps, int fl, regm_t regsaved, const(char)* name, SYMFLGS flags, type *t)
{
    Symbol *s = symbol_calloc(name[0 .. strlen(name)]);
    s.Stype = t;
    s.Ssymnum = SYMIDX.max;
    s.Sclass = SC.extern_;
    s.Sfl = cast(char)fl;
    s.Sregsaved = regsaved;
    s.Sflags = flags;
    *ps = s;
}

/******************************************
 * Initialize rtl symbols.
 */

void rtlsym_init()
{
}

/*******************************
 * Reset the symbols for the case when we are generating multiple
 * .OBJ files from one compile.
 */
void rtlsym_reset()
{
    clib_inited = 0;            // reset CLIB symbols, too
    for (size_t i = 0; i <= RTLSYM.max; i++)
    {
        if (rtlsym[i])
        {
            rtlsym[i].Sxtrnnum = 0;
            rtlsym[i].Stypidx = 0;
        }
    }
}

/*******************************
 */

void rtlsym_term()
{
}
