/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1996-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/drtlsym.d, backend/drtlsym.d)
 */

module dmd.backend.drtlsym;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;
version (HTOD)
    version = COMPILE;

version (COMPILE)
{

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

extern (C++):

nothrow:

version (HTOD)
    __gshared uint ALLREGS;

private __gshared Symbol*[RTLSYM_MAX] rtlsym;

version (MARS)
    // This varies depending on C ABI
    alias FREGSAVED = fregsaved;
else
    enum FREGSAVED = (mBP | mBX | mSI | mDI);


/******************************************
 * Get Symbol corresponding to Dwarf "personality" function.
 * Returns:
 *      Personality function
 */
Symbol* getRtlsymPersonality() { return getRtlsym(RTLSYM_PERSONALITY); }


/******************************************
 * Get Symbol corresponding to i.
 * Params:
 *      i = RTLSYM_xxxx
 * Returns:
 *      runtime library Symbol
 */
Symbol *getRtlsym(int i)
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

    // Only used by dmd1 for RTLSYM_THROW
    type *tw = null;

    // Lazilly initialize only what we use
    switch (i)
    {
        case RTLSYM_THROW:                  symbolz(ps,FLfunc,(mES | mBP),"_d_throw@4", SFLexit, tw); break;
        case RTLSYM_THROWC:                 symbolz(ps,FLfunc,(mES | mBP),"_d_throwc", SFLexit, t); break;
        case RTLSYM_THROWDWARF:             symbolz(ps,FLfunc,(mES | mBP),"_d_throwdwarf", SFLexit, t); break;
        case RTLSYM_MONITOR_HANDLER:        symbolz(ps,FLfunc,FREGSAVED,"_d_monitor_handler", 0, tsclib); break;
        case RTLSYM_MONITOR_PROLOG:         symbolz(ps,FLfunc,FREGSAVED,"_d_monitor_prolog",0,t); break;
        case RTLSYM_MONITOR_EPILOG:         symbolz(ps,FLfunc,FREGSAVED,"_d_monitor_epilog",0,t); break;
        case RTLSYM_DCOVER:                 symbolz(ps,FLfunc,FREGSAVED,"_d_cover_register", 0, t); break;
        case RTLSYM_DCOVER2:                symbolz(ps,FLfunc,FREGSAVED,"_d_cover_register2", 0, t); break;
        case RTLSYM_DASSERT:                symbolz(ps,FLfunc,FREGSAVED,"_d_assert", SFLexit, t); break;
        case RTLSYM_DASSERTP:               symbolz(ps,FLfunc,FREGSAVED,"_d_assertp", SFLexit, t); break;
        case RTLSYM_DASSERT_MSG:            symbolz(ps,FLfunc,FREGSAVED,"_d_assert_msg", SFLexit, t); break;
        case RTLSYM_DUNITTEST:              symbolz(ps,FLfunc,FREGSAVED,"_d_unittest", 0, t); break;
        case RTLSYM_DUNITTESTP:             symbolz(ps,FLfunc,FREGSAVED,"_d_unittestp", 0, t); break;
        case RTLSYM_DUNITTEST_MSG:          symbolz(ps,FLfunc,FREGSAVED,"_d_unittest_msg", 0, t); break;
        case RTLSYM_DARRAY:                 symbolz(ps,FLfunc,FREGSAVED,"_d_arraybounds", SFLexit, t); break;
        case RTLSYM_DARRAYP:                symbolz(ps,FLfunc,FREGSAVED,"_d_arrayboundsp", SFLexit, t); break;
        case RTLSYM_DINVARIANT:             symbolz(ps,FLfunc,FREGSAVED,"_D9invariant12_d_invariantFC6ObjectZv", 0, tsdlib); break;
        case RTLSYM_MEMCPY:                 symbolz(ps,FLfunc,FREGSAVED,"memcpy",    0, t); break;
        case RTLSYM_MEMSET8:                symbolz(ps,FLfunc,FREGSAVED,"memset",    0, t); break;
        case RTLSYM_MEMSET16:               symbolz(ps,FLfunc,FREGSAVED,"_memset16", 0, t); break;
        case RTLSYM_MEMSET32:               symbolz(ps,FLfunc,FREGSAVED,"_memset32", 0, t); break;
        case RTLSYM_MEMSET64:               symbolz(ps,FLfunc,FREGSAVED,"_memset64", 0, t); break;
        case RTLSYM_MEMSET128:              symbolz(ps,FLfunc,FREGSAVED,"_memset128",0, t); break;
        case RTLSYM_MEMSET128ii:            symbolz(ps,FLfunc,FREGSAVED,"_memset128ii",0, t); break;
        case RTLSYM_MEMSET80:               symbolz(ps,FLfunc,FREGSAVED,"_memset80", 0, t); break;
        case RTLSYM_MEMSET160:              symbolz(ps,FLfunc,FREGSAVED,"_memset160",0, t); break;
        case RTLSYM_MEMSETFLOAT:            symbolz(ps,FLfunc,FREGSAVED,"_memsetFloat", 0, t); break;
        case RTLSYM_MEMSETDOUBLE:           symbolz(ps,FLfunc,FREGSAVED,"_memsetDouble", 0, t); break;
        case RTLSYM_MEMSETSIMD:             symbolz(ps,FLfunc,FREGSAVED,"_memsetSIMD",0, t); break;
        case RTLSYM_MEMSETN:                symbolz(ps,FLfunc,FREGSAVED,"_memsetn",  0, t); break;
        case RTLSYM_MODULO:                 symbolz(ps,FLfunc,FREGSAVED,"_modulo",   0, t); break;
        case RTLSYM_MONITORENTER:           symbolz(ps,FLfunc,FREGSAVED,"_d_monitorenter",0, t); break;
        case RTLSYM_MONITOREXIT:            symbolz(ps,FLfunc,FREGSAVED,"_d_monitorexit",0, t); break;
        case RTLSYM_CRITICALENTER:          symbolz(ps,FLfunc,FREGSAVED,"_d_criticalenter",0, t); break;
        case RTLSYM_CRITICALEXIT:           symbolz(ps,FLfunc,FREGSAVED,"_d_criticalexit",0, t); break;
        case RTLSYM_DSWITCHERR:             symbolz(ps,FLfunc,FREGSAVED,"_d_switch_error", SFLexit, t); break;
        case RTLSYM_DHIDDENFUNC:            symbolz(ps,FLfunc,FREGSAVED,"_d_hidden_func", 0, t); break;
        case RTLSYM_NEWCLASS:               symbolz(ps,FLfunc,FREGSAVED,"_d_newclass", 0, t); break;
        case RTLSYM_NEWTHROW:               symbolz(ps,FLfunc,FREGSAVED,"_d_newThrowable", 0, t); break;
        case RTLSYM_NEWARRAYT:              symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayT", 0, t); break;
        case RTLSYM_NEWARRAYIT:             symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayiT", 0, t); break;
        case RTLSYM_NEWITEMT:               symbolz(ps,FLfunc,FREGSAVED,"_d_newitemT", 0, t); break;
        case RTLSYM_NEWITEMIT:              symbolz(ps,FLfunc,FREGSAVED,"_d_newitemiT", 0, t); break;
        case RTLSYM_NEWARRAYMTX:            symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymTX", 0, t); break;
        case RTLSYM_NEWARRAYMITX:           symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymiTX", 0, t); break;
        case RTLSYM_ARRAYLITERALTX:         symbolz(ps,FLfunc,FREGSAVED,"_d_arrayliteralTX", 0, t); break;
        case RTLSYM_ASSOCARRAYLITERALTX:    symbolz(ps,FLfunc,FREGSAVED,"_d_assocarrayliteralTX", 0, t); break;
        case RTLSYM_CALLFINALIZER:          symbolz(ps,FLfunc,FREGSAVED,"_d_callfinalizer", 0, t); break;
        case RTLSYM_CALLINTERFACEFINALIZER: symbolz(ps,FLfunc,FREGSAVED,"_d_callinterfacefinalizer", 0, t); break;
        case RTLSYM_DELCLASS:               symbolz(ps,FLfunc,FREGSAVED,"_d_delclass", 0, t); break;
        case RTLSYM_DELINTERFACE:           symbolz(ps,FLfunc,FREGSAVED,"_d_delinterface", 0, t); break;
        case RTLSYM_DELSTRUCT:              symbolz(ps,FLfunc,FREGSAVED,"_d_delstruct", 0, t); break;
        case RTLSYM_ALLOCMEMORY:            symbolz(ps,FLfunc,FREGSAVED,"_d_allocmemory", 0, t); break;
        case RTLSYM_DELARRAYT:              symbolz(ps,FLfunc,FREGSAVED,"_d_delarray_t", 0, t); break;
        case RTLSYM_DELMEMORY:              symbolz(ps,FLfunc,FREGSAVED,"_d_delmemory", 0, t); break;
        case RTLSYM_INTERFACE:              symbolz(ps,FLfunc,FREGSAVED,"_d_interface_vtbl", 0, t); break;
        case RTLSYM_DYNAMIC_CAST:           symbolz(ps,FLfunc,FREGSAVED,"_d_dynamic_cast", 0, t); break;
        case RTLSYM_INTERFACE_CAST:         symbolz(ps,FLfunc,FREGSAVED,"_d_interface_cast", 0, t); break;
        case RTLSYM_FATEXIT:                symbolz(ps,FLfunc,FREGSAVED,"_fatexit", 0, t); break;
        case RTLSYM_ARRAYCATT:              symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatT", 0, t); break;
        case RTLSYM_ARRAYCATNTX:            symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatnTX", 0, t); break;
        case RTLSYM_ARRAYAPPENDT:           symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendT", 0, t); break;
        case RTLSYM_ARRAYAPPENDCTX:         symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcTX", 0, t); break;
        case RTLSYM_ARRAYAPPENDCD:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcd", 0, t); break;
        case RTLSYM_ARRAYAPPENDWD:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendwd", 0, t); break;
        case RTLSYM_ARRAYSETLENGTHT:        symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthT", 0, t); break;
        case RTLSYM_ARRAYSETLENGTHIT:       symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthiT", 0, t); break;
        case RTLSYM_ARRAYCOPY:              symbolz(ps,FLfunc,FREGSAVED,"_d_arraycopy", 0, t); break;
        case RTLSYM_ARRAYASSIGN:            symbolz(ps,FLfunc,FREGSAVED,"_d_arrayassign", 0, t); break;
        case RTLSYM_ARRAYASSIGN_R:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayassign_r", 0, t); break;
        case RTLSYM_ARRAYASSIGN_L:          symbolz(ps,FLfunc,FREGSAVED,"_d_arrayassign_l", 0, t); break;
        case RTLSYM_ARRAYCTOR:              symbolz(ps,FLfunc,FREGSAVED,"_d_arrayctor", 0, t); break;
        case RTLSYM_ARRAYSETASSIGN:         symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetassign", 0, t); break;
        case RTLSYM_ARRAYSETCTOR:           symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetctor", 0, t); break;
        case RTLSYM_ARRAYEQ2:               symbolz(ps,FLfunc,FREGSAVED,"_adEq2", 0, t); break;
        case RTLSYM_ARRAYCMPCHAR:           symbolz(ps,FLfunc,FREGSAVED,"_adCmpChar", 0, t); break;

        case RTLSYM_EXCEPT_HANDLER2:        symbolz(ps,FLfunc,fregsaved,"_except_handler2", 0, tsclib); break;
        case RTLSYM_EXCEPT_HANDLER3:        symbolz(ps,FLfunc,fregsaved,"_except_handler3", 0, tsclib); break;
        case RTLSYM_CPP_HANDLER:            symbolz(ps,FLfunc,FREGSAVED,"_cpp_framehandler", 0, tsclib); break;
        case RTLSYM_D_HANDLER:              symbolz(ps,FLfunc,FREGSAVED,"_d_framehandler", 0, tsclib); break;
        case RTLSYM_D_LOCAL_UNWIND2:        symbolz(ps,FLfunc,FREGSAVED,"_d_local_unwind2", 0, tsclib); break;
        case RTLSYM_LOCAL_UNWIND2:          symbolz(ps,FLfunc,FREGSAVED,"_local_unwind2", 0, tsclib); break;
        case RTLSYM_UNWIND_RESUME:          symbolz(ps,FLfunc,FREGSAVED,"_Unwind_Resume", SFLexit, t); break;
        case RTLSYM_PERSONALITY:            symbolz(ps,FLfunc,FREGSAVED,"__dmd_personality_v0", 0, t); break;
        case RTLSYM_BEGIN_CATCH:            symbolz(ps,FLfunc,FREGSAVED,"__dmd_begin_catch", 0, t); break;
        case RTLSYM_CXA_BEGIN_CATCH:        symbolz(ps,FLfunc,FREGSAVED,"__cxa_begin_catch", 0, t); break;
        case RTLSYM_CXA_END_CATCH:          symbolz(ps,FLfunc,FREGSAVED,"__cxa_end_catch", 0, t); break;

        case RTLSYM_TLS_INDEX:              symbolz(ps,FLextern,0,"_tls_index",0,tstypes[TYint]); break;
        case RTLSYM_TLS_ARRAY:              symbolz(ps,FLextern,0,"_tls_array",0,tspvoid); break;
        case RTLSYM_AHSHIFT:                symbolz(ps,FLfunc,0,"_AHSHIFT",0,tstrace); break;

        case RTLSYM_HDIFFN:                 symbolz(ps,FLfunc,mBX|mCX|mSI|mDI|mBP|mES,"_aNahdiff", 0, tsclib); break;
        case RTLSYM_HDIFFF:                 symbolz(ps,FLfunc,mBX|mCX|mSI|mDI|mBP|mES,"_aFahdiff", 0, tsclib); break;
        case RTLSYM_INTONLY:                symbolz(ps,FLfunc,mSI|mDI,"_intonly", 0, tsclib); break;

        case RTLSYM_EXCEPT_LIST:            symbolz(ps,FLextern,0,"_except_list",0,tstypes[TYint]); break;
        case RTLSYM_SETJMP3:                symbolz(ps,FLfunc,FREGSAVED,"_setjmp3", 0, tsclib); break;
        case RTLSYM_LONGJMP:                symbolz(ps,FLfunc,FREGSAVED,"_seh_longjmp_unwind@4", 0, tsclib); break;
        case RTLSYM_ALLOCA:                 symbolz(ps,FLfunc,fregsaved,"__alloca", 0, tsclib); break;
        case RTLSYM_CPP_LONGJMP:            symbolz(ps,FLfunc,FREGSAVED,"_cpp_longjmp_unwind@4", 0, tsclib); break;
        case RTLSYM_PTRCHK:                 symbolz(ps,FLfunc,fregsaved,"_ptrchk", 0, tsclib); break;
        case RTLSYM_CHKSTK:                 symbolz(ps,FLfunc,fregsaved,"_chkstk", 0, tsclib); break;
        case RTLSYM_TRACE_PRO_N:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_pro_n",0,tstrace); break;
        case RTLSYM_TRACE_PRO_F:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_pro_f",0,tstrace); break;
        case RTLSYM_TRACE_EPI_N:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_epi_n",0,tstrace); break;
        case RTLSYM_TRACE_EPI_F:            symbolz(ps,FLfunc,ALLREGS|mBP|mES,"_trace_epi_f",0,tstrace); break;
        case RTLSYM_TRACE_CPRO:             symbolz(ps,FLfunc,FREGSAVED,"_c_trace_pro",0,t); break;
        case RTLSYM_TRACE_CEPI:             symbolz(ps,FLfunc,FREGSAVED,"_c_trace_epi",0,t); break;

        case RTLSYM_TRACENEWCLASS:          symbolz(ps,FLfunc,FREGSAVED,"_d_newclassTrace", 0, t); break;
        case RTLSYM_TRACENEWARRAYT:         symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayTTrace", 0, t); break;
        case RTLSYM_TRACENEWARRAYIT:        symbolz(ps,FLfunc,FREGSAVED,"_d_newarrayiTTrace", 0, t); break;
        case RTLSYM_TRACENEWARRAYMTX:       symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymTXTrace", 0, t); break;
        case RTLSYM_TRACENEWARRAYMITX:      symbolz(ps,FLfunc,FREGSAVED,"_d_newarraymiTXTrace", 0, t); break;
        case RTLSYM_TRACENEWITEMT:          symbolz(ps,FLfunc,FREGSAVED,"_d_newitemTTrace", 0, t); break;
        case RTLSYM_TRACENEWITEMIT:         symbolz(ps,FLfunc,FREGSAVED,"_d_newitemiTTrace", 0, t); break;
        case RTLSYM_TRACECALLFINALIZER:     symbolz(ps,FLfunc,FREGSAVED,"_d_callfinalizerTrace", 0, t); break;
        case RTLSYM_TRACECALLINTERFACEFINALIZER: symbolz(ps,FLfunc,FREGSAVED,"_d_callinterfacefinalizerTrace", 0, t); break;
        case RTLSYM_TRACEDELCLASS:          symbolz(ps,FLfunc,FREGSAVED,"_d_delclassTrace", 0, t); break;
        case RTLSYM_TRACEDELINTERFACE:      symbolz(ps,FLfunc,FREGSAVED,"_d_delinterfaceTrace", 0, t); break;
        case RTLSYM_TRACEDELSTRUCT:         symbolz(ps,FLfunc,FREGSAVED,"_d_delstructTrace", 0, t); break;
        case RTLSYM_TRACEDELARRAYT:         symbolz(ps,FLfunc,FREGSAVED,"_d_delarray_tTrace", 0, t); break;
        case RTLSYM_TRACEDELMEMORY:         symbolz(ps,FLfunc,FREGSAVED,"_d_delmemoryTrace", 0, t); break;
        case RTLSYM_TRACEARRAYLITERALTX:    symbolz(ps,FLfunc,FREGSAVED,"_d_arrayliteralTXTrace", 0, t); break;
        case RTLSYM_TRACEASSOCARRAYLITERALTX: symbolz(ps,FLfunc,FREGSAVED,"_d_assocarrayliteralTXTrace", 0, t); break;
        case RTLSYM_TRACEARRAYCATT:         symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatTTrace", 0, t); break;
        case RTLSYM_TRACEARRAYCATNTX:       symbolz(ps,FLfunc,FREGSAVED,"_d_arraycatnTXTrace", 0, t); break;
        case RTLSYM_TRACEARRAYAPPENDT:      symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendTTrace", 0, t); break;
        case RTLSYM_TRACEARRAYAPPENDCTX:    symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcTXTrace", 0, t); break;
        case RTLSYM_TRACEARRAYAPPENDCD:     symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendcdTrace", 0, t); break;
        case RTLSYM_TRACEARRAYAPPENDWD:     symbolz(ps,FLfunc,FREGSAVED,"_d_arrayappendwdTrace", 0, t); break;
        case RTLSYM_TRACEARRAYSETLENGTHT:   symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthTTrace", 0, t); break;
        case RTLSYM_TRACEARRAYSETLENGTHIT:  symbolz(ps,FLfunc,FREGSAVED,"_d_arraysetlengthiTTrace", 0, t); break;
        case RTLSYM_TRACEALLOCMEMORY:       symbolz(ps,FLfunc,FREGSAVED,"_d_allocmemoryTrace", 0, t); break;
        case RTLSYM_C_ASSERT:               symbolz(ps,FLfunc,FREGSAVED,"_assert", SFLexit, t); break;
        case RTLSYM_C__ASSERT:              symbolz(ps,FLfunc,FREGSAVED,"__assert", SFLexit, t); break;
        case RTLSYM_C__ASSERT_FAIL:         symbolz(ps,FLfunc,FREGSAVED,"__assert_fail", SFLexit, t); break;
        case RTLSYM_C__ASSERT_RTN:          symbolz(ps,FLfunc,FREGSAVED,"__assert_rtn", SFLexit, t); break;

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
    Symbol *s = symbol_calloc(name);
    s.Stype = t;
    s.Ssymnum = SYMIDX.max;
    s.Sclass = SCextern;
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
version (MARS)
{
void rtlsym_reset()
{
    clib_inited = 0;            // reset CLIB symbols, too
    for (size_t i = 0; i < RTLSYM_MAX; i++)
    {
        if (rtlsym[i])
        {
            rtlsym[i].Sxtrnnum = 0;
            rtlsym[i].Stypidx = 0;
        }
    }
}

}

/*******************************
 */

void rtlsym_term()
{
}

}
