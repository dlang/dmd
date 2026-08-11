/**
 * Compiler runtime function symbols
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1996-1998 by Symantec
 *              Copyright (C) 2000-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/rtlsym.d, backend/rtlsym.d)
 */

module dmd.backend.rtlsym;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.symbol;
import dmd.backend.ty;
import dmd.backend.type;


nothrow:

enum RTLSYM
{
    THROWC,
    THROWDWARF,
    MONITOR_HANDLER,
    MONITOR_PROLOG,
    MONITOR_EPILOG,
    DCOVER2,
    DASSERT,
    DASSERTP,
    DASSERT_MSG,
    DUNITTEST,
    DUNITTESTP,
    DUNITTEST_MSG,
    DARRAYP,
    DARRAY_SLICEP,
    DARRAY_INDEXP,
    DNULLP,
    DINVARIANT,
    MEMCMP,
    MEMCPY,
    MEMSET8,
    MEMSET16,
    MEMSET32,
    MEMSET64,
    MEMSET128,
    MEMSET128ii,
    MEMSET80,
    MEMSET160,
    MEMSETFLOAT,
    MEMSETDOUBLE,
    MEMSETSIMD,
    MEMSETN,

    CALLFINALIZER,
    CALLINTERFACEFINALIZER,
    ALLOCMEMORY,
    ARRAYAPPENDCD,
    ARRAYAPPENDWD,
    ARRAYCOPY,
    ARRAYASSIGN_R,
    ARRAYASSIGN_L,
    ARRAYEQ2,

    D_HANDLER,
    D_LOCAL_UNWIND2,
    LOCAL_UNWIND2,
    UNWIND_RESUME,
    PERSONALITY,
    BEGIN_CATCH,
    CXA_BEGIN_CATCH,
    CXA_END_CATCH,

    TLS_INDEX,
    TLS_ARRAY,
    AHSHIFT,

    HDIFFN,
    HDIFFF,
    INTONLY,

    EXCEPT_LIST,
    SETJMP3,
    LONGJMP,
    ALLOCA,
    PTRCHK,
    CHKSTK,
    TRACE_PRO_N,
    TRACE_PRO_F,
    TRACE_EPI_N,
    TRACE_EPI_F,


    TRACECALLFINALIZER,
    TRACECALLINTERFACEFINALIZER,
    TRACEARRAYAPPENDCD,
    TRACEARRAYAPPENDWD,
    TRACEALLOCMEMORY,

    C_ASSERT,
    C__ASSERT,
    C__ASSERT_FAIL,
    C__ASSERT_RTN,

    FMODF,
    FMOD,
    FMODL,

    SINF,
    SIN,
    COSF,
    COS,
    RINTF,
    RINT,
    RNDTOLF,
    RNDTOL,
    LDEXPF,
    LDEXP,
    LOG2F,
    LOG2,
    LOG1PF,
    LOG1P,

    CXA_ATEXIT,

    EHWASMMATCH
}

private __gshared Symbol*[RTLSYM.max + 1] rtlsym;

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
Symbol* getRtlsym(RTLSYM i) @trusted
{
     Symbol** ps = &rtlsym[i];
     if (*ps)
        return* ps;

    __gshared type* t;
    __gshared type* tv;

    if (!t)
    {
        t = type_fake(TYnfunc);
        t.Tmangle = Mangle.c;
        t.Tcount++;

        // Variadic function
        tv = type_fake(TYnfunc);
        tv.Tmangle = Mangle.c;
        tv.Tcount++;
    }

    auto FREGSAVED = cgstate.fregsaved; // varies depending on C ABI

    // Lazilly initialize only what we use
    switch (i)
    {
        case RTLSYM.THROWC:                 symbolz(ps,FL.func,(mES | mBP),"_d_throwc", SFLexit, t); break;
        case RTLSYM.THROWDWARF:             symbolz(ps,FL.func,(mES | mBP),"_d_throwdwarf", SFLexit, t); break;
        case RTLSYM.MONITOR_HANDLER:        symbolz(ps,FL.func,FREGSAVED,"_d_monitor_handler", 0, tsclib); break;
        case RTLSYM.MONITOR_PROLOG:         symbolz(ps,FL.func,FREGSAVED,"_d_monitor_prolog",0,t); break;
        case RTLSYM.MONITOR_EPILOG:         symbolz(ps,FL.func,FREGSAVED,"_d_monitor_epilog",0,t); break;
        case RTLSYM.DCOVER2:                symbolz(ps,FL.func,FREGSAVED,"_d_cover_register2", 0, t); break;
        case RTLSYM.DASSERT:                symbolz(ps,FL.func,FREGSAVED,"_d_assert", SFLexit, t); break;
        case RTLSYM.DASSERTP:               symbolz(ps,FL.func,FREGSAVED,"_d_assertp", SFLexit, t); break;
        case RTLSYM.DASSERT_MSG:            symbolz(ps,FL.func,FREGSAVED,"_d_assert_msg", SFLexit, t); break;
        case RTLSYM.DUNITTEST:              symbolz(ps,FL.func,FREGSAVED,"_d_unittest", 0, t); break;
        case RTLSYM.DUNITTESTP:             symbolz(ps,FL.func,FREGSAVED,"_d_unittestp", 0, t); break;
        case RTLSYM.DUNITTEST_MSG:          symbolz(ps,FL.func,FREGSAVED,"_d_unittest_msg", 0, t); break;
        case RTLSYM.DARRAYP:                symbolz(ps,FL.func,FREGSAVED,"_d_arrayboundsp", SFLexit, t); break;
        case RTLSYM.DARRAY_SLICEP:          symbolz(ps,FL.func,FREGSAVED,"_d_arraybounds_slicep", SFLexit, t); break;
        case RTLSYM.DARRAY_INDEXP:          symbolz(ps,FL.func,FREGSAVED,"_d_arraybounds_indexp", SFLexit, t); break;
        case RTLSYM.DNULLP:                 symbolz(ps,FL.func,FREGSAVED,"_d_nullpointerp", SFLexit, t); break;
        case RTLSYM.DINVARIANT:             symbolz(ps,FL.func,FREGSAVED,"_D2rt10invariant_12_d_invariantFC6ObjectZv", 0, tsdlib); break;
        case RTLSYM.MEMCMP:                 symbolz(ps,FL.func,FREGSAVED,"memcmp",    0, t); break;
        case RTLSYM.MEMCPY:                 symbolz(ps,FL.func,FREGSAVED,"memcpy",    0, t); break;
        case RTLSYM.MEMSET8:                symbolz(ps,FL.func,FREGSAVED,"memset",    0, t); break;
        case RTLSYM.MEMSET16:               symbolz(ps,FL.func,FREGSAVED,"_memset16", 0, t); break;
        case RTLSYM.MEMSET32:               symbolz(ps,FL.func,FREGSAVED,"_memset32", 0, t); break;
        case RTLSYM.MEMSET64:               symbolz(ps,FL.func,FREGSAVED,"_memset64", 0, t); break;
        case RTLSYM.MEMSET128:              symbolz(ps,FL.func,FREGSAVED,"_memset128",0, t); break;
        case RTLSYM.MEMSET128ii:            symbolz(ps,FL.func,FREGSAVED,"_memset128ii",0, t); break;
        case RTLSYM.MEMSET80:               symbolz(ps,FL.func,FREGSAVED,"_memset80", 0, t); break;
        case RTLSYM.MEMSET160:              symbolz(ps,FL.func,FREGSAVED,"_memset160",0, t); break;
        case RTLSYM.MEMSETFLOAT:            symbolz(ps,FL.func,FREGSAVED,"_memsetFloat", 0, t); break;
        case RTLSYM.MEMSETDOUBLE:           symbolz(ps,FL.func,FREGSAVED,"_memsetDouble", 0, t); break;
        case RTLSYM.MEMSETSIMD:             symbolz(ps,FL.func,FREGSAVED,"_memsetSIMD",0, t); break;
        case RTLSYM.MEMSETN:                symbolz(ps,FL.func,FREGSAVED,"_memsetn",  0, t); break;
        case RTLSYM.CALLFINALIZER:          symbolz(ps,FL.func,FREGSAVED,"_d_callfinalizer", 0, t); break;
        case RTLSYM.CALLINTERFACEFINALIZER: symbolz(ps,FL.func,FREGSAVED,"_d_callinterfacefinalizer", 0, t); break;
        case RTLSYM.ALLOCMEMORY:            symbolz(ps,FL.func,FREGSAVED,"_d_allocmemory", 0, t); break;
        case RTLSYM.ARRAYAPPENDCD:          symbolz(ps,FL.func,FREGSAVED,"_d_arrayappendcd", 0, t); break;
        case RTLSYM.ARRAYAPPENDWD:          symbolz(ps,FL.func,FREGSAVED,"_d_arrayappendwd", 0, t); break;
        case RTLSYM.ARRAYCOPY:              symbolz(ps,FL.func,FREGSAVED,"_d_arraycopy", 0, t); break;
        case RTLSYM.ARRAYASSIGN_R:          symbolz(ps,FL.func,FREGSAVED,"_d_arrayassign_r", 0, t); break;
        case RTLSYM.ARRAYASSIGN_L:          symbolz(ps,FL.func,FREGSAVED,"_d_arrayassign_l", 0, t); break;

        case RTLSYM.D_HANDLER:              symbolz(ps,FL.func,FREGSAVED,"_d_framehandler", 0, tsclib); break;
        case RTLSYM.D_LOCAL_UNWIND2:        symbolz(ps,FL.func,FREGSAVED,"_d_local_unwind2", 0, tsclib); break;
        case RTLSYM.LOCAL_UNWIND2:          symbolz(ps,FL.func,FREGSAVED,"_local_unwind2", 0, tsclib); break;
        case RTLSYM.UNWIND_RESUME:          symbolz(ps,FL.func,FREGSAVED,"_Unwind_Resume", SFLexit, t); break;
        case RTLSYM.PERSONALITY:            symbolz(ps,FL.func,FREGSAVED,"__dmd_personality_v0", 0, t); break;
        case RTLSYM.BEGIN_CATCH:            symbolz(ps,FL.func,FREGSAVED,"__dmd_begin_catch", 0, t); break;
        case RTLSYM.CXA_BEGIN_CATCH:        symbolz(ps,FL.func,FREGSAVED,"__cxa_begin_catch", 0, t); break;
        case RTLSYM.CXA_END_CATCH:          symbolz(ps,FL.func,FREGSAVED,"__cxa_end_catch", 0, t); break;

        case RTLSYM.TLS_INDEX:              symbolz(ps,FL.extern_,0,"_tls_index",0,tstypes[TYint]); break;
        case RTLSYM.TLS_ARRAY:              symbolz(ps,FL.extern_,0,"_tls_array",0,tspvoid); break;
        case RTLSYM.AHSHIFT:                symbolz(ps,FL.func,0,"_AHSHIFT",0,tstrace); break;

        case RTLSYM.HDIFFN:                 symbolz(ps,FL.func,mBX|mCX|mSI|mDI|mBP|mES,"_aNahdiff", 0, tsclib); break;
        case RTLSYM.HDIFFF:                 symbolz(ps,FL.func,mBX|mCX|mSI|mDI|mBP|mES,"_aFahdiff", 0, tsclib); break;
        case RTLSYM.INTONLY:                symbolz(ps,FL.func,mSI|mDI,"_intonly", 0, tsclib); break;

        case RTLSYM.EXCEPT_LIST:            symbolz(ps,FL.extern_,0,"_except_list",0,tstypes[TYint]); break;
        case RTLSYM.SETJMP3:                symbolz(ps,FL.func,FREGSAVED,"_setjmp3", 0, tsclib); break;
        case RTLSYM.LONGJMP:                symbolz(ps,FL.func,FREGSAVED,"_seh_longjmp_unwind@4", 0, tsclib); break;
        case RTLSYM.ALLOCA:                 symbolz(ps,FL.func,FREGSAVED,"__alloca", 0, tsclib); break;
        case RTLSYM.PTRCHK:                 symbolz(ps,FL.func,FREGSAVED,"_ptrchk", 0, tsclib); break;
        case RTLSYM.CHKSTK:                 symbolz(ps,FL.func,FREGSAVED,"_chkstk", 0, tsclib); break;
        case RTLSYM.TRACE_PRO_N:            symbolz(ps,FL.func,ALLREGS|mBP|mES,"_trace_pro_n",0,tstrace); break;
        case RTLSYM.TRACE_PRO_F:            symbolz(ps,FL.func,ALLREGS|mBP|mES,"_trace_pro_f",0,tstrace); break;
        case RTLSYM.TRACE_EPI_N:            symbolz(ps,FL.func,ALLREGS|mBP|mES,"_trace_epi_n",0,tstrace); break;
        case RTLSYM.TRACE_EPI_F:            symbolz(ps,FL.func,ALLREGS|mBP|mES,"_trace_epi_f",0,tstrace); break;


        case RTLSYM.TRACECALLFINALIZER:     symbolz(ps,FL.func,FREGSAVED,"_d_callfinalizerTrace", 0, t); break;
        case RTLSYM.TRACECALLINTERFACEFINALIZER: symbolz(ps,FL.func,FREGSAVED,"_d_callinterfacefinalizerTrace", 0, t); break;
        case RTLSYM.TRACEARRAYAPPENDCD:     symbolz(ps,FL.func,FREGSAVED,"_d_arrayappendcdTrace", 0, t); break;
        case RTLSYM.TRACEARRAYAPPENDWD:     symbolz(ps,FL.func,FREGSAVED,"_d_arrayappendwdTrace", 0, t); break;
        case RTLSYM.TRACEALLOCMEMORY:       symbolz(ps,FL.func,FREGSAVED,"_d_allocmemoryTrace", 0, t); break;
        case RTLSYM.C_ASSERT:               symbolz(ps,FL.func,FREGSAVED,"_assert", SFLexit, t); break;
        case RTLSYM.C__ASSERT:              symbolz(ps,FL.func,FREGSAVED,"__assert", SFLexit, t); break;
        case RTLSYM.C__ASSERT_FAIL:         symbolz(ps,FL.func,FREGSAVED,"__assert_fail", SFLexit, t); break;
        case RTLSYM.C__ASSERT_RTN:          symbolz(ps,FL.func,FREGSAVED,"__assert_rtn", SFLexit, t); break;

        // x86 has instrtuctions for math, other targets (arm, wasm) emit these function calls from libc
        case RTLSYM.FMODF:                  symbolz(ps,FL.func,FREGSAVED,"fmodf", 0, t); break;
        case RTLSYM.FMOD:                   symbolz(ps,FL.func,FREGSAVED,"fmod",  0, t); break;
        case RTLSYM.FMODL:                  symbolz(ps,FL.func,FREGSAVED,config.objfmt == OBJ_WASM ? "fmod" : "fmodl", 0, t); break;
        case RTLSYM.SINF:                   symbolz(ps,FL.func,FREGSAVED,"sinf",  0, t); break;
        case RTLSYM.SIN:                    symbolz(ps,FL.func,FREGSAVED,"sin",   0, t); break;
        case RTLSYM.COSF:                   symbolz(ps,FL.func,FREGSAVED,"cosf",  0, t); break;
        case RTLSYM.COS:                    symbolz(ps,FL.func,FREGSAVED,"cos",   0, t); break;
        case RTLSYM.RINTF:                  symbolz(ps,FL.func,FREGSAVED,"rintf", 0, t); break;
        case RTLSYM.RINT:                   symbolz(ps,FL.func,FREGSAVED,"rint",  0, t); break;
        case RTLSYM.RNDTOLF:                symbolz(ps,FL.func,FREGSAVED,"llrintf", 0, t); break;
        case RTLSYM.RNDTOL:                 symbolz(ps,FL.func,FREGSAVED,"llrint",  0, t); break;
        case RTLSYM.LDEXPF:                 symbolz(ps,FL.func,FREGSAVED,"ldexpf", 0, t); break;
        case RTLSYM.LDEXP:                  symbolz(ps,FL.func,FREGSAVED,"ldexp",  0, t); break;
        case RTLSYM.LOG2F:                  symbolz(ps,FL.func,FREGSAVED,"log2f",  0, t); break;
        case RTLSYM.LOG2:                   symbolz(ps,FL.func,FREGSAVED,"log2",   0, t); break;
        case RTLSYM.LOG1PF:                 symbolz(ps,FL.func,FREGSAVED,"log1pf", 0, t); break;
        case RTLSYM.LOG1P:                  symbolz(ps,FL.func,FREGSAVED,"log1p",  0, t); break;

        case RTLSYM.CXA_ATEXIT:             symbolz(ps,FL.func,FREGSAVED,"__cxa_atexit", 0, t); break;
        case RTLSYM.EHWASMMATCH:            symbolz(ps,FL.func,FREGSAVED,"_d_eh_wasm_match", 0, t); break;
        default:
            assert(0);
    }

    if (config.objfmt == OBJ_WASM)
        if (type* wt = wasmRtlsymType(i))
            (*ps).Stype = wt;

    return* ps;
}

/******************************************
 * Build the real backend signature for rtlsym.
 *
 * Specifically needed for WASM, where calls are validated so pushing args
 * to calls with a fake type results in an error.
 * x86/Windows-only symbols are skipped, and 32-bit is assumed
 * (needs to be refactored for wasm64 support)
 */
private type* wasmRtlsymType(RTLSYM i)
{
    type* tvoid = tstypes[TYvoid];
    type* tint  = tstypes[TYint];
    type* tuint = tstypes[TYuint];
    type* tsize = tstypes[TYuint];   // size_t on wasm32
    type* tdchar = tstypes[TYdchar];
    type* tshort = tstypes[TYshort];
    type* tfloat = tstypes[TYfloat];
    type* tdouble = tstypes[TYdouble];

    static type* ptrTo(type* tn) => type_pointer(tn);
    type* voidPtr()  => ptrTo(tvoid);
    type* charPtr()  => ptrTo(tstypes[TYchar]);
    type* str()      => type_dyn_array(tstypes[TYchar]); // immutable(char)[]
    type* voidArr()  => type_dyn_array(tvoid);           // void[]

    type* fn(scope type*[] params, type* ret) => type_function(TYnfunc, params, false, ret);

    final switch (i)
    {
        case RTLSYM.THROWC:                 return fn([voidPtr()], tvoid);
        case RTLSYM.THROWDWARF:             return fn([voidPtr()], tvoid);
        case RTLSYM.DINVARIANT:             return fn([voidPtr()], tvoid);
        case RTLSYM.CALLFINALIZER:          return fn([voidPtr()], tvoid);
        case RTLSYM.CALLINTERFACEFINALIZER: return fn([voidPtr()], tvoid);

        case RTLSYM.DASSERT:                return fn([str(), tuint], tvoid);
        case RTLSYM.DUNITTEST:              return fn([str(), tuint], tvoid);
        case RTLSYM.DASSERTP:               return fn([charPtr(), tuint], tvoid);
        case RTLSYM.DUNITTESTP:             return fn([charPtr(), tuint], tvoid);
        case RTLSYM.DARRAYP:                return fn([charPtr(), tuint], tvoid);
        case RTLSYM.DNULLP:                 return fn([charPtr(), tuint], tvoid);
        case RTLSYM.DASSERT_MSG:            return fn([str(), str(), tuint], tvoid);
        case RTLSYM.DUNITTEST_MSG:          return fn([str(), str(), tuint], tvoid);
        case RTLSYM.DARRAY_INDEXP:          return fn([charPtr(), tuint, tsize, tsize], tvoid);
        case RTLSYM.DARRAY_SLICEP:          return fn([charPtr(), tuint, tsize, tsize, tsize], tvoid);

        case RTLSYM.MEMCMP:                 return fn([voidPtr(), voidPtr(), tsize], tint);
        case RTLSYM.MEMCPY:                 return fn([voidPtr(), voidPtr(), tsize], voidPtr());
        case RTLSYM.MEMSET8:                return fn([voidPtr(), tint, tsize], voidPtr());
        case RTLSYM.MEMSET16:               return fn([ptrTo(tshort), tshort, tsize], ptrTo(tshort));
        case RTLSYM.MEMSET32:               return fn([ptrTo(tint), tint, tsize], ptrTo(tint));
        case RTLSYM.MEMSET64:               return fn([ptrTo(tstypes[TYllong]), tstypes[TYllong], tsize], ptrTo(tstypes[TYllong]));
        case RTLSYM.MEMSETFLOAT:            return fn([ptrTo(tstypes[TYfloat]), tstypes[TYfloat], tsize], ptrTo(tstypes[TYfloat]));
        case RTLSYM.MEMSETDOUBLE:           return fn([ptrTo(tstypes[TYdouble]), tstypes[TYdouble], tsize], ptrTo(tstypes[TYdouble]));
        case RTLSYM.MEMSET80:               return fn([ptrTo(tstypes[TYdouble]), tstypes[TYdouble], tsize], ptrTo(tstypes[TYdouble])); // D `real` is f64 on wasm32
        case RTLSYM.MEMSET128:              return fn([voidPtr(), voidPtr(), tsize], voidPtr());
        case RTLSYM.MEMSET128ii:            return fn([voidPtr(), voidArr(), tsize], voidPtr());
        case RTLSYM.MEMSETN:                return fn([voidPtr(), voidPtr(), tint, tsize], voidPtr());
        case RTLSYM.ALLOCMEMORY:            return fn([tsize], voidPtr());

        case RTLSYM.DCOVER2:                return fn([str(), type_dyn_array(tsize), type_dyn_array(tuint), tstypes[TYuchar]], tvoid);

        case RTLSYM.ARRAYAPPENDCD:          return fn([voidPtr(), tdchar], voidArr());
        case RTLSYM.ARRAYAPPENDWD:          return fn([voidPtr(), tdchar], voidArr());
        case RTLSYM.ARRAYCOPY:              return fn([tsize, voidArr(), voidArr()], voidArr());

        case RTLSYM.TRACECALLFINALIZER:          return fn([str(), tint, str(), voidPtr()], tvoid);
        case RTLSYM.TRACECALLINTERFACEFINALIZER: return fn([str(), tint, str(), voidPtr()], tvoid);
        case RTLSYM.TRACEARRAYAPPENDCD:          return fn([str(), tint, str(), voidPtr(), tdchar], voidArr());
        case RTLSYM.TRACEARRAYAPPENDWD:          return fn([str(), tint, str(), voidPtr(), tdchar], voidArr());
        case RTLSYM.TRACEALLOCMEMORY:            return fn([str(), tint, str(), tsize], voidPtr());

        case RTLSYM.C_ASSERT:               return fn([charPtr(), charPtr(), tint], tvoid);
        case RTLSYM.C__ASSERT:              return fn([charPtr(), charPtr(), tint], tvoid);
        case RTLSYM.C__ASSERT_FAIL:         return fn([charPtr(), charPtr(), tuint, charPtr()], tvoid);
        case RTLSYM.C__ASSERT_RTN:          return fn([charPtr(), charPtr(), tint, charPtr()], tvoid);

        case RTLSYM.FMODF:                  return fn([tfloat, tfloat], tfloat);
        case RTLSYM.FMOD:                   return fn([tdouble, tdouble], tdouble);
        case RTLSYM.FMODL:                  return fn([tdouble, tdouble], tdouble);

        case RTLSYM.SINF:                   return fn([tfloat], tfloat);
        case RTLSYM.COSF:                   return fn([tfloat], tfloat);
        case RTLSYM.SIN:                    return fn([tdouble], tdouble);
        case RTLSYM.COS:                    return fn([tdouble], tdouble);
        case RTLSYM.RINTF:                  return fn([tfloat], tfloat);
        case RTLSYM.RINT:                   return fn([tdouble], tdouble);
        case RTLSYM.RNDTOLF:                return fn([tfloat], tstypes[TYllong]);
        case RTLSYM.RNDTOL:                 return fn([tdouble], tstypes[TYllong]);
        case RTLSYM.LDEXPF:                 return fn([tfloat, tint], tfloat);
        case RTLSYM.LDEXP:                  return fn([tdouble, tint], tdouble);
        case RTLSYM.LOG2F:                  return fn([tfloat], tfloat);
        case RTLSYM.LOG2:                   return fn([tdouble], tdouble);
        case RTLSYM.LOG1PF:                 return fn([tfloat], tfloat);
        case RTLSYM.LOG1P:                  return fn([tdouble], tdouble);

        case RTLSYM.CXA_ATEXIT:             return fn([voidPtr(), voidPtr(), voidPtr()], tint);
        case RTLSYM.EHWASMMATCH:            return fn([voidPtr(), voidPtr()], tstypes[TYbool]);

        case RTLSYM.MONITOR_HANDLER:        return null;
        case RTLSYM.MONITOR_PROLOG:         return null;
        case RTLSYM.MONITOR_EPILOG:         return null;
        case RTLSYM.D_HANDLER:              return null;
        case RTLSYM.D_LOCAL_UNWIND2:        return null;
        case RTLSYM.LOCAL_UNWIND2:          return null;
        case RTLSYM.UNWIND_RESUME:          return null;
        case RTLSYM.PERSONALITY:            return null;
        case RTLSYM.BEGIN_CATCH:            return null;
        case RTLSYM.CXA_BEGIN_CATCH:        return null;
        case RTLSYM.CXA_END_CATCH:          return null;
        case RTLSYM.TLS_INDEX:              return null;
        case RTLSYM.TLS_ARRAY:              return null;
        case RTLSYM.AHSHIFT:                return null;
        case RTLSYM.HDIFFN:                 return null;
        case RTLSYM.HDIFFF:                 return null;
        case RTLSYM.INTONLY:                return null;
        case RTLSYM.EXCEPT_LIST:            return null;
        case RTLSYM.SETJMP3:                return null;
        case RTLSYM.LONGJMP:                return null;
        case RTLSYM.ALLOCA:                 return null;
        case RTLSYM.PTRCHK:                 return null;
        case RTLSYM.CHKSTK:                 return null;
        case RTLSYM.TRACE_PRO_N:            return null;
        case RTLSYM.TRACE_PRO_F:            return null;
        case RTLSYM.TRACE_EPI_N:            return null;
        case RTLSYM.TRACE_EPI_F:            return null;
        case RTLSYM.MEMSET160:              return null;
        case RTLSYM.MEMSETSIMD:             return null;
        case RTLSYM.ARRAYASSIGN_R:          return null;
        case RTLSYM.ARRAYASSIGN_L:          return null;
        case RTLSYM.ARRAYEQ2:               return null;
    }
}


/******************************************
 * Create and initialize Symbol for runtime function.
 * Params:
 *    ps = where to store initialized Symbol pointer
 *    f = FL.xxx
 *    regsaved = registers not altered by function
 *    name = name of function
 *    flags = value for Sflags
 *    t = type of function
 */
private void symbolz(Symbol** ps, FL fl, regm_t regsaved, const(char)* name, SYMFLGS flags, type* t)
{
    Symbol* s = symbol_calloc(name[0 .. strlen(name)]);
    s.Stype = t;
    s.Ssymnum = SYMIDX.max;
    s.Sclass = SC.extern_;
    s.Sfl = fl;
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
