/**
 * Compiler runtime function symbols
 *
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/_rtlsym.d
 * Documentation: https://dlang.org/phobos/dmd_backend_rtlsym.html
 */

module dmd.backend.rtlsym;

import dmd.backend.cc : Symbol;

enum RTLSYM
{
    THROW,
    THROWC,
    THROWDWARF,
    MONITOR_HANDLER,
    MONITOR_PROLOG,
    MONITOR_EPILOG,
    DCOVER,
    DCOVER2,
    DASSERT,
    DASSERTP,
    DASSERT_MSG,
    DUNITTEST,
    DUNITTESTP,
    DUNITTEST_MSG,
    DARRAY,
    DARRAYP,
    DARRAY_SLICEP,
    DARRAY_INDEXP,
    DINVARIANT,
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
    MODULO,
    MONITORENTER,
    MONITOREXIT,
    CRITICALENTER,
    CRITICALEXIT,
    SWITCH_STRING,       // unused
    SWITCH_USTRING,      // unused
    SWITCH_DSTRING,      // unused
    DSWITCHERR,
    DHIDDENFUNC,
    NEWCLASS,
    NEWTHROW,
    NEWARRAYT,
    NEWARRAYIT,
    NEWITEMT,
    NEWITEMIT,
    NEWARRAYMTX,
    NEWARRAYMITX,
    ARRAYLITERALTX,
    ASSOCARRAYLITERALTX,
    CALLFINALIZER,
    CALLINTERFACEFINALIZER,
    DELCLASS,
    DELINTERFACE,
    DELSTRUCT,
    ALLOCMEMORY,
    DELARRAYT,
    DELMEMORY,
    INTERFACE,
    DYNAMIC_CAST,
    INTERFACE_CAST,
    FATEXIT,
    ARRAYCATT,
    ARRAYCATNTX,
    ARRAYAPPENDT,
    ARRAYAPPENDCTX,
    ARRAYAPPENDCD,
    ARRAYAPPENDWD,
    ARRAYSETLENGTHT,
    ARRAYSETLENGTHIT,
    ARRAYCOPY,
    ARRAYASSIGN,
    ARRAYASSIGN_R,
    ARRAYASSIGN_L,
    ARRAYCTOR,
    ARRAYSETASSIGN,
    ARRAYSETCTOR,
    ARRAYCAST,           // unused
    ARRAYEQ,             // unused
    ARRAYEQ2,
    ARRAYCMP,            // unused
    ARRAYCMP2,           // unused
    ARRAYCMPCHAR,        // unused
    OBJ_EQ,              // unused
    OBJ_CMP,             // unused

    EXCEPT_HANDLER2,
    EXCEPT_HANDLER3,
    CPP_HANDLER,
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
    CPP_LONGJMP,
    PTRCHK,
    CHKSTK,
    TRACE_PRO_N,
    TRACE_PRO_F,
    TRACE_EPI_N,
    TRACE_EPI_F,
    TRACE_CPRO,
    TRACE_CEPI,

    TRACENEWCLASS,
    TRACENEWARRAYT,
    TRACENEWARRAYIT,
    TRACENEWARRAYMTX,
    TRACENEWARRAYMITX,
    TRACENEWITEMT,
    TRACENEWITEMIT,
    TRACECALLFINALIZER,
    TRACECALLINTERFACEFINALIZER,
    TRACEDELCLASS,
    TRACEDELINTERFACE,
    TRACEDELSTRUCT,
    TRACEDELARRAYT,
    TRACEDELMEMORY,
    TRACEARRAYLITERALTX,
    TRACEASSOCARRAYLITERALTX,
    TRACEARRAYCATT,
    TRACEARRAYCATNTX,
    TRACEARRAYAPPENDT,
    TRACEARRAYAPPENDCTX,
    TRACEARRAYAPPENDCD,
    TRACEARRAYAPPENDWD,
    TRACEARRAYSETLENGTHT,
    TRACEARRAYSETLENGTHIT,
    TRACEALLOCMEMORY,

    C_ASSERT,
    C__ASSERT,
    C__ASSERT_FAIL,
    C__ASSERT_RTN
}

extern (C++):

nothrow:
@safe:

Symbol *getRtlsym(RTLSYM i);
Symbol *getRtlsymPersonality();
