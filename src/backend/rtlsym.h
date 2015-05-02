// Copyright (C) 1994-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


/*
        ty
        ------------------------------------
        0       tsclib  TYnpfunc, C mangling
        t               TYnfunc, C mangling
        tsjlib          TYjfunc, C mangling
        tsdlib          TYjfunc, C mangling
 */

#if SCPP
#define SYMBOL_SCPP(e, fl, saved, n, flags, ty) SYMBOL_Z(e,fl,saved,n,flags,ty)
#else
#define SYMBOL_SCPP(e, fl, saved, n, flags, ty)
#endif

#if SCPP && TX86
#define SYMBOL_SCPP_TX86(e, fl, saved, n, flags, ty) SYMBOL_Z(e,fl,saved,n,flags,ty)
#else
#define SYMBOL_SCPP_TX86(e, fl, saved, n, flags, ty)
#endif

#if MARS
#define SYMBOL_MARS(e, fl, saved, n, flags, ty) SYMBOL_Z(e,fl,saved,n,flags,ty)
#else
#define SYMBOL_MARS(e, fl, saved, n, flags, ty)
#endif


#define RTLSYMS \
\
SYMBOL_MARS(THROW,           FLfunc,(mES | mBP),"_d_throw@4", SFLexit, tw) \
SYMBOL_MARS(THROWC,          FLfunc,(mES | mBP),"_d_throwc", SFLexit, t) \
SYMBOL_MARS(MONITOR_HANDLER, FLfunc,FREGSAVED,"_d_monitor_handler", 0, 0) \
SYMBOL_MARS(MONITOR_PROLOG,  FLfunc,FREGSAVED,"_d_monitor_prolog",0,t) \
SYMBOL_MARS(MONITOR_EPILOG,  FLfunc,FREGSAVED,"_d_monitor_epilog",0,t) \
SYMBOL_MARS(DCOVER,          FLfunc,FREGSAVED,"_d_cover_register", 0, t) \
SYMBOL_MARS(DCOVER2,         FLfunc,FREGSAVED,"_d_cover_register2", 0, t) \
SYMBOL_MARS(DASSERT,         FLfunc,FREGSAVED,"_d_assert", SFLexit, t) \
SYMBOL_MARS(DASSERTM,        FLfunc,FREGSAVED,"_d_assertm", SFLexit, t) \
SYMBOL_MARS(DASSERT_MSG,     FLfunc,FREGSAVED,"_d_assert_msg", SFLexit, t) \
SYMBOL_MARS(DUNITTEST,       FLfunc,FREGSAVED,"_d_unittest", 0, t) \
SYMBOL_MARS(DUNITTESTM,      FLfunc,FREGSAVED,"_d_unittestm", 0, t) \
SYMBOL_MARS(DUNITTEST_MSG,   FLfunc,FREGSAVED,"_d_unittest_msg", 0, t) \
SYMBOL_MARS(DARRAY,          FLfunc,FREGSAVED,"_d_arraybounds", SFLexit, t) \
SYMBOL_MARS(DARRAYM,         FLfunc,FREGSAVED,"_d_array_bounds", SFLexit, t) \
SYMBOL_MARS(DINVARIANT,      FLfunc,FREGSAVED,"D9invariant12_d_invariantFC6ObjectZv", 0, tsdlib) \
SYMBOL_MARS(_DINVARIANT,     FLfunc,FREGSAVED,"_D9invariant12_d_invariantFC6ObjectZv", 0, tsdlib) \
SYMBOL_MARS(MEMCPY,          FLfunc,FREGSAVED,"memcpy",    0, t) \
SYMBOL_MARS(MEMSET8,         FLfunc,FREGSAVED,"memset",    0, t) \
SYMBOL_MARS(MEMSET16,        FLfunc,FREGSAVED,"_memset16", 0, t) \
SYMBOL_MARS(MEMSET32,        FLfunc,FREGSAVED,"_memset32", 0, t) \
SYMBOL_MARS(MEMSET64,        FLfunc,FREGSAVED,"_memset64", 0, t) \
SYMBOL_MARS(MEMSET128,       FLfunc,FREGSAVED,"_memset128",0, t) \
SYMBOL_MARS(MEMSET128ii,     FLfunc,FREGSAVED,"_memset128ii",0, t) \
SYMBOL_MARS(MEMSET80,        FLfunc,FREGSAVED,"_memset80", 0, t) \
SYMBOL_MARS(MEMSET160,       FLfunc,FREGSAVED,"_memset160",0, t) \
SYMBOL_MARS(MEMSETFLOAT,     FLfunc,FREGSAVED,"_memsetFloat", 0, t) \
SYMBOL_MARS(MEMSETDOUBLE,    FLfunc,FREGSAVED,"_memsetDouble", 0, t) \
SYMBOL_MARS(MEMSETSIMD,      FLfunc,FREGSAVED,"_memsetSIMD",0, t) \
SYMBOL_MARS(MEMSETN,         FLfunc,FREGSAVED,"_memsetn",  0, t) \
SYMBOL_MARS(MODULO,          FLfunc,FREGSAVED,"_modulo",   0, t) \
SYMBOL_MARS(MONITORENTER,  FLfunc,FREGSAVED,"_d_monitorenter",0, t) \
SYMBOL_MARS(MONITOREXIT,   FLfunc,FREGSAVED,"_d_monitorexit",0, t) \
SYMBOL_MARS(CRITICALENTER, FLfunc,FREGSAVED,"_d_criticalenter",0, t) \
SYMBOL_MARS(CRITICALEXIT,  FLfunc,FREGSAVED,"_d_criticalexit",0, t) \
SYMBOL_MARS(SWITCH_STRING, FLfunc,FREGSAVED,"_d_switch_string", 0, t) \
SYMBOL_MARS(SWITCH_USTRING,FLfunc,FREGSAVED,"_d_switch_ustring", 0, t) \
SYMBOL_MARS(SWITCH_DSTRING,FLfunc,FREGSAVED,"_d_switch_dstring", 0, t) \
SYMBOL_MARS(DSWITCHERR,    FLfunc,FREGSAVED,"_d_switch_error", SFLexit, t) \
SYMBOL_MARS(DHIDDENFUNC,   FLfunc,FREGSAVED,"_d_hidden_func", 0, t) \
SYMBOL_MARS(NEWCLASS,      FLfunc,FREGSAVED,"_d_newclass", 0, t) \
SYMBOL_MARS(NEWARRAYT,     FLfunc,FREGSAVED,"_d_newarrayT", 0, t) \
SYMBOL_MARS(NEWARRAYIT,    FLfunc,FREGSAVED,"_d_newarrayiT", 0, t) \
SYMBOL_MARS(NEWITEMT,     FLfunc,FREGSAVED,"_d_newitemT", 0, t) \
SYMBOL_MARS(NEWITEMIT,    FLfunc,FREGSAVED,"_d_newitemiT", 0, t) \
SYMBOL_MARS(NEWARRAYMT,    FLfunc,FREGSAVED,"_d_newarraymT", 0, tv) \
SYMBOL_MARS(NEWARRAYMIT,   FLfunc,FREGSAVED,"_d_newarraymiT", 0, tv) \
SYMBOL_MARS(NEWARRAYMTX,   FLfunc,FREGSAVED,"_d_newarraymTX", 0, t) \
SYMBOL_MARS(NEWARRAYMITX,  FLfunc,FREGSAVED,"_d_newarraymiTX", 0, t) \
SYMBOL_MARS(ARRAYLITERALT, FLfunc,FREGSAVED,"_d_arrayliteralT", 0, tv) \
SYMBOL_MARS(ARRAYLITERALTX, FLfunc,FREGSAVED,"_d_arrayliteralTX", 0, t) \
SYMBOL_MARS(ASSOCARRAYLITERALT, FLfunc,FREGSAVED,"_d_assocarrayliteralT", 0, tv) \
SYMBOL_MARS(ASSOCARRAYLITERALTX, FLfunc,FREGSAVED,"_d_assocarrayliteralTX", 0, t) \
SYMBOL_MARS(CALLFINALIZER, FLfunc,FREGSAVED,"_d_callfinalizer", 0, t) \
SYMBOL_MARS(CALLINTERFACEFINALIZER, FLfunc,FREGSAVED,"_d_callinterfacefinalizer", 0, t) \
SYMBOL_MARS(DELCLASS,      FLfunc,FREGSAVED,"_d_delclass", 0, t) \
SYMBOL_MARS(DELINTERFACE,  FLfunc,FREGSAVED,"_d_delinterface", 0, t) \
SYMBOL_MARS(DELSTRUCT,     FLfunc,FREGSAVED,"_d_delstruct", 0, t) \
SYMBOL_MARS(ALLOCMEMORY,   FLfunc,FREGSAVED,"_d_allocmemory", 0, t) \
SYMBOL_MARS(DELARRAY,      FLfunc,FREGSAVED,"_d_delarray", 0, t) \
SYMBOL_MARS(DELARRAYT,     FLfunc,FREGSAVED,"_d_delarray_t", 0, t) \
SYMBOL_MARS(DELMEMORY,     FLfunc,FREGSAVED,"_d_delmemory", 0, t) \
SYMBOL_MARS(INTERFACE,     FLfunc,FREGSAVED,"_d_interface_vtbl", 0, t) \
SYMBOL_MARS(DYNAMIC_CAST,  FLfunc,FREGSAVED,"_d_dynamic_cast", 0, t) \
SYMBOL_MARS(INTERFACE_CAST,FLfunc,FREGSAVED,"_d_interface_cast", 0, t) \
SYMBOL_MARS(FATEXIT,       FLfunc,FREGSAVED,"_fatexit", 0, t) \
SYMBOL_MARS(ARRAYCATT,     FLfunc,FREGSAVED,"_d_arraycatT", 0, t) \
SYMBOL_MARS(ARRAYCATNT,    FLfunc,FREGSAVED,"_d_arraycatnT", 0, tv) \
SYMBOL_MARS(ARRAYCATNTX,   FLfunc,FREGSAVED,"_d_arraycatnTX", 0, t) \
SYMBOL_MARS(ARRAYAPPENDT,  FLfunc,FREGSAVED,"_d_arrayappendT", 0, t) \
SYMBOL_MARS(ARRAYAPPENDCT,  FLfunc,FREGSAVED,"_d_arrayappendcT", 0, tv) \
SYMBOL_MARS(ARRAYAPPENDCTX, FLfunc,FREGSAVED,"_d_arrayappendcTX", 0, t) \
SYMBOL_MARS(ARRAYAPPENDCD,  FLfunc,FREGSAVED,"_d_arrayappendcd", 0, t) \
SYMBOL_MARS(ARRAYAPPENDWD,  FLfunc,FREGSAVED,"_d_arrayappendwd", 0, t) \
SYMBOL_MARS(ARRAYSETLENGTHT,FLfunc,FREGSAVED,"_d_arraysetlengthT", 0, t) \
SYMBOL_MARS(ARRAYSETLENGTHIT,FLfunc,FREGSAVED,"_d_arraysetlengthiT", 0, t) \
SYMBOL_MARS(ARRAYCOPY,     FLfunc,FREGSAVED,"_d_arraycopy", 0, t) \
SYMBOL_MARS(ARRAYASSIGN,   FLfunc,FREGSAVED,"_d_arrayassign", 0, t) \
SYMBOL_MARS(ARRAYASSIGN_R, FLfunc,FREGSAVED,"_d_arrayassign_r", 0, t) \
SYMBOL_MARS(ARRAYASSIGN_L, FLfunc,FREGSAVED,"_d_arrayassign_l", 0, t) \
SYMBOL_MARS(ARRAYCTOR,     FLfunc,FREGSAVED,"_d_arrayctor", 0, t) \
SYMBOL_MARS(ARRAYSETASSIGN, FLfunc,FREGSAVED,"_d_arraysetassign", 0, t) \
SYMBOL_MARS(ARRAYSETCTOR,  FLfunc,FREGSAVED,"_d_arraysetctor", 0, t) \
SYMBOL_MARS(ARRAYCAST,     FLfunc,FREGSAVED,"_d_arraycast", 0, t) \
SYMBOL_MARS(ARRAYCAST_FROMBIT, FLfunc,FREGSAVED,"_d_arraycast_frombit", 0, t) \
SYMBOL_MARS(ARRAYEQ,       FLfunc,FREGSAVED,"_adEq", 0, t) \
SYMBOL_MARS(ARRAYEQ2,      FLfunc,FREGSAVED,"_adEq2", 0, t) \
SYMBOL_MARS(ARRAYEQBIT,    FLfunc,FREGSAVED,"_adEqBit", 0, t) \
SYMBOL_MARS(ARRAYCMP,      FLfunc,FREGSAVED,"_adCmp", 0, t) \
SYMBOL_MARS(ARRAYCMP2,     FLfunc,FREGSAVED,"_adCmp2", 0, t) \
SYMBOL_MARS(ARRAYCMPCHAR,  FLfunc,FREGSAVED,"_adCmpChar", 0, t) \
SYMBOL_MARS(ARRAYCMPBIT,   FLfunc,FREGSAVED,"_adCmpBit", 0, t) \
SYMBOL_MARS(OBJ_EQ,        FLfunc,FREGSAVED,"_d_obj_eq", 0, t) \
SYMBOL_MARS(OBJ_CMP,       FLfunc,FREGSAVED,"_d_obj_cmp", 0, t) \
\
SYMBOL_Z(EXCEPT_HANDLER2, FLfunc,fregsaved,"_except_handler2", 0, 0) \
SYMBOL_Z(EXCEPT_HANDLER3, FLfunc,fregsaved,"_except_handler3", 0, 0) \
SYMBOL_SCPP(CPP_HANDLER,  FLfunc,FREGSAVED,"_cpp_framehandler", 0, 0) \
SYMBOL_MARS(CPP_HANDLER,  FLfunc,FREGSAVED,"_d_framehandler", 0, 0) \
SYMBOL_MARS(D_LOCAL_UNWIND2, FLfunc,FREGSAVED,"_d_local_unwind2", 0, 0) \
SYMBOL_SCPP(LOCAL_UNWIND2, FLfunc,FREGSAVED,"_local_unwind2", 0, 0) \
\
SYMBOL_Z(TLS_INDEX, FLextern,0,"_tls_index",0,tsint) \
SYMBOL_Z(TLS_ARRAY, FLextern,0,"_tls_array",0,tspvoid) \
SYMBOL_SCPP(AHSHIFT,   FLfunc,0,"_AHSHIFT",0,tstrace) \
\
SYMBOL_SCPP_TX86(HDIFFN, FLfunc,mBX|mCX|mSI|mDI|mBP|mES,"_aNahdiff", 0, 0) \
SYMBOL_SCPP_TX86(HDIFFF, FLfunc,mBX|mCX|mSI|mDI|mBP|mES,"_aFahdiff", 0, 0) \
SYMBOL_SCPP_TX86(INTONLY,FLfunc,mSI|mDI,"_intonly", 0, 0) \
\
SYMBOL_Z(EXCEPT_LIST, FLextern,0,"_except_list",0,tsint) \
SYMBOL_Z(SETJMP3, FLfunc,FREGSAVED,"_setjmp3", 0, 0) \
SYMBOL_Z(LONGJMP, FLfunc,FREGSAVED,"_seh_longjmp_unwind@4", 0, 0) \
SYMBOL_Z(ALLOCA,  FLfunc,fregsaved,"__alloca", 0, 0) \
SYMBOL_Z(CPP_LONGJMP, FLfunc,FREGSAVED,"_cpp_longjmp_unwind@4", 0, 0) \
SYMBOL_Z(PTRCHK, FLfunc,fregsaved,"_ptrchk", 0, 0) \
SYMBOL_Z(CHKSTK, FLfunc,fregsaved,"_chkstk", 0, 0) \
SYMBOL_Z(TRACE_PRO_N, FLfunc,ALLREGS|mBP|mES,"_trace_pro_n",0,tstrace) \
SYMBOL_Z(TRACE_PRO_F, FLfunc,ALLREGS|mBP|mES,"_trace_pro_f",0,tstrace) \
SYMBOL_Z(TRACE_EPI_N, FLfunc,ALLREGS|mBP|mES,"_trace_epi_n",0,tstrace) \
SYMBOL_Z(TRACE_EPI_F, FLfunc,ALLREGS|mBP|mES,"_trace_epi_f",0,tstrace) \
SYMBOL_MARS(TRACE_CPRO, FLfunc,FREGSAVED,"_c_trace_pro",0,t) \
SYMBOL_MARS(TRACE_CEPI, FLfunc,FREGSAVED,"_c_trace_epi",0,t) \
\
SYMBOL_MARS(TRACENEWCLASS,        FLfunc,FREGSAVED,"_d_newclassTrace", 0, t) \
SYMBOL_MARS(TRACENEWARRAYT,       FLfunc,FREGSAVED,"_d_newarrayTTrace", 0, t) \
SYMBOL_MARS(TRACENEWARRAYIT,      FLfunc,FREGSAVED,"_d_newarrayiTTrace", 0, t) \
SYMBOL_MARS(TRACENEWARRAYMTX,     FLfunc,FREGSAVED,"_d_newarraymTXTrace", 0, t) \
SYMBOL_MARS(TRACENEWARRAYMITX,    FLfunc,FREGSAVED,"_d_newarraymiTXTrace", 0, t) \
SYMBOL_MARS(TRACENEWITEMT,        FLfunc,FREGSAVED,"_d_newitemTTrace", 0, t) \
SYMBOL_MARS(TRACENEWITEMIT,       FLfunc,FREGSAVED,"_d_newitemiTTrace", 0, t) \
SYMBOL_MARS(TRACECALLFINALIZER,   FLfunc,FREGSAVED,"_d_callfinalizerTrace", 0, t) \
SYMBOL_MARS(TRACECALLINTERFACEFINALIZER, FLfunc,FREGSAVED,"_d_callinterfacefinalizerTrace", 0, t) \
SYMBOL_MARS(TRACEDELCLASS,        FLfunc,FREGSAVED,"_d_delclassTrace", 0, t) \
SYMBOL_MARS(TRACEDELINTERFACE,    FLfunc,FREGSAVED,"_d_delinterfaceTrace", 0, t) \
SYMBOL_MARS(TRACEDELSTRUCT,       FLfunc,FREGSAVED,"_d_delstructTrace", 0, t) \
SYMBOL_MARS(TRACEDELARRAYT,       FLfunc,FREGSAVED,"_d_delarray_tTrace", 0, t) \
SYMBOL_MARS(TRACEDELMEMORY,       FLfunc,FREGSAVED,"_d_delmemoryTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYLITERALTX, FLfunc,FREGSAVED,"_d_arrayliteralTXTrace", 0, t) \
SYMBOL_MARS(TRACEASSOCARRAYLITERALTX, FLfunc,FREGSAVED,"_d_assocarrayliteralTXTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYCATT,       FLfunc,FREGSAVED,"_d_arraycatTTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYCATNTX,     FLfunc,FREGSAVED,"_d_arraycatnTXTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYAPPENDT,    FLfunc,FREGSAVED,"_d_arrayappendTTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYAPPENDCTX,  FLfunc,FREGSAVED,"_d_arrayappendcTXTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYAPPENDCD,   FLfunc,FREGSAVED,"_d_arrayappendcdTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYAPPENDWD,   FLfunc,FREGSAVED,"_d_arrayappendwdTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYSETLENGTHT, FLfunc,FREGSAVED,"_d_arraysetlengthTTrace", 0, t) \
SYMBOL_MARS(TRACEARRAYSETLENGTHIT,FLfunc,FREGSAVED,"_d_arraysetlengthiTTrace", 0, t) \
SYMBOL_MARS(TRACEALLOCMEMORY,     FLfunc,FREGSAVED,"_d_allocmemoryTrace", 0, t) \



