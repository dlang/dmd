// EXTRA_SOURCES: imports/test24511_c.c

import test24511_c;

static assert(__traits(getLinkage, CFunctionPointer) == "C");
static assert(__traits(getLinkage, StdCallFunctionPointer) == "Windows");
static assert(__traits(getLinkage, cFunction) == "C");
static assert(__traits(getLinkage, stdcallFunction) == "Windows");

static assert(__traits(getLinkage, takesCFunctionPointer) == "Windows");
static if (is(typeof(&takesCFunctionPointer) ParamsA == __parameters))
    static assert(__traits(getLinkage, ParamsA[0]) == "C");

static assert(__traits(getLinkage, takesStdCallFunctionPointer) == "C");
static if (is(typeof(&takesStdCallFunctionPointer) ParamsB == __parameters))
    static assert(__traits(getLinkage, ParamsB[0]) == "Windows");

static assert(__traits(getLinkage, StdCallFunctionPointerTakingCFunctionPointer) == "Windows");
static if (is(typeof(&StdCallFunctionPointerTakingCFunctionPointer) ParamsC == __parameters))
    static assert(__traits(getLinkage, ParamsC[0]) == "C");

static assert(__traits(getLinkage, CFunctionPointerTakingStdCallFunctionPointer) == "C");
static if (is(typeof(&CFunctionPointerTakingStdCallFunctionPointer) ParamsD == __parameters))
    static assert(__traits(getLinkage, ParamsD[0]) == "Windows");
