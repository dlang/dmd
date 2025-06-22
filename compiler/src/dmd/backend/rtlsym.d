/**
 * Compiler runtime function symbols
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/_rtlsym.d
 * Documentation: https://dlang.org/phobos/dmd_backend_rtlsym.html
 */

module dmd.backend.rtlsym;

import dmd.backend.cc : Symbol;

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
    NEWTHROW,

    ARRAYLITERALTX,
    ASSOCARRAYLITERALTX,
    CALLFINALIZER,
    CALLINTERFACEFINALIZER,
    ALLOCMEMORY,
    ARRAYCATT,
    ARRAYAPPENDCD,
    ARRAYAPPENDWD,
    ARRAYCOPY,
    ARRAYASSIGN_R,
    ARRAYASSIGN_L,
    ARRAYEQ2,
    AANEW,
    AAEQUAL,
    AAINX,
    AADELX,
    AAGETY,
    AAGETRVALUEX,

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


    TRACECALLFINALIZER,
    TRACECALLINTERFACEFINALIZER,
    TRACEARRAYLITERALTX,
    TRACEARRAYAPPENDCD,
    TRACEARRAYAPPENDWD,
    TRACEALLOCMEMORY,

    C_ASSERT,
    C__ASSERT,
    C__ASSERT_FAIL,
    C__ASSERT_RTN,

    CXA_ATEXIT
}

@safe:

public import dmd.backend.drtlsym : getRtlsym, getRtlsymPersonality;
