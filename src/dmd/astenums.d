/**
 * Defines enums common to dmd and dmd as parse library.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/astenums.d, _astenums.d)
 * Documentation:  https://dlang.org/phobos/dmd_astenums.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/astenums.d
 */

module dmd.astenums;

enum Sizeok : ubyte
{
    none,               /// size of aggregate is not yet able to compute
    fwd,                /// size of aggregate is ready to compute
    inProcess,          /// in the midst of computing the size
    done,               /// size of aggregate is set correctly
}

enum Baseok : ubyte
{
    none,               /// base classes not computed yet
    start,              /// in process of resolving base classes
    done,               /// all base classes are resolved
    semanticdone,       /// all base classes semantic done
}

enum MODFlags : int
{
    const_       = 1,    // type is const
    immutable_   = 4,    // type is immutable
    shared_      = 2,    // type is shared
    wild         = 8,    // type is wild
    wildconst    = (MODFlags.wild | MODFlags.const_), // type is wild const
    mutable      = 0x10, // type is mutable (only used in wildcard matching)
}

alias MOD = ubyte;

enum STC : ulong
{
    undefined_          = 0L,
    static_             = (1L << 0),
    extern_             = (1L << 1),
    const_              = (1L << 2),
    final_              = (1L << 3),
    abstract_           = (1L << 4),
    parameter           = (1L << 5),
    field               = (1L << 6),
    override_           = (1L << 7),
    auto_               = (1L << 8),
    synchronized_       = (1L << 9),
    deprecated_         = (1L << 10),
    in_                 = (1L << 11),   // in parameter
    out_                = (1L << 12),   // out parameter
    lazy_               = (1L << 13),   // lazy parameter
    foreach_            = (1L << 14),   // variable for foreach loop
                          //(1L << 15)
    variadic            = (1L << 16),   // the 'variadic' parameter in: T foo(T a, U b, V variadic...)
    ctorinit            = (1L << 17),   // can only be set inside constructor
    templateparameter   = (1L << 18),   // template parameter
    scope_              = (1L << 19),
    immutable_          = (1L << 20),
    ref_                = (1L << 21),
    init                = (1L << 22),   // has explicit initializer
    manifest            = (1L << 23),   // manifest constant
    nodtor              = (1L << 24),   // don't run destructor
    nothrow_            = (1L << 25),   // never throws exceptions
    pure_               = (1L << 26),   // pure function
    tls                 = (1L << 27),   // thread local
    alias_              = (1L << 28),   // alias parameter
    shared_             = (1L << 29),   // accessible from multiple threads
    gshared             = (1L << 30),   // accessible from multiple threads, but not typed as "shared"
    wild                = (1L << 31),   // for "wild" type constructor
    property            = (1L << 32),
    safe                = (1L << 33),
    trusted             = (1L << 34),
    system              = (1L << 35),
    ctfe                = (1L << 36),   // can be used in CTFE, even if it is static
    disable             = (1L << 37),   // for functions that are not callable
    result              = (1L << 38),   // for result variables passed to out contracts
    nodefaultctor       = (1L << 39),   // must be set inside constructor
    temp                = (1L << 40),   // temporary variable
    rvalue              = (1L << 41),   // force rvalue for variables
    nogc                = (1L << 42),   // @nogc
    volatile_           = (1L << 43),   // destined for volatile in the back end
    return_             = (1L << 44),   // 'return ref' or 'return scope' for function parameters
    autoref             = (1L << 45),   // Mark for the already deduced 'auto ref' parameter
    inference           = (1L << 46),   // do attribute inference
    exptemp             = (1L << 47),   // temporary variable that has lifetime restricted to an expression
    maybescope          = (1L << 48),   // parameter might be 'scope'
    scopeinferred       = (1L << 49),   // 'scope' has been inferred and should not be part of mangling
    future              = (1L << 50),   // introducing new base class function
    local               = (1L << 51),   // do not forward (see dmd.dsymbol.ForwardingScopeDsymbol).
    returninferred      = (1L << 52),   // 'return' has been inferred and should not be part of mangling
    live                = (1L << 53),   // function @live attribute
    register            = (1L << 54),   // `register` storage class

    safeGroup = STC.safe | STC.trusted | STC.system,
    IOR  = STC.in_ | STC.ref_ | STC.out_,
    TYPECTOR = (STC.const_ | STC.immutable_ | STC.shared_ | STC.wild),
    FUNCATTR = (STC.ref_ | STC.nothrow_ | STC.nogc | STC.pure_ | STC.property | STC.live |
                safeGroup),
}

/* This is different from the one in declaration.d, make that fix a separate PR */
static if (0)
extern (C++) __gshared const(StorageClass) STCStorageClass =
    (STC.auto_ | STC.scope_ | STC.static_ | STC.extern_ | STC.const_ | STC.final_ |
     STC.abstract_ | STC.synchronized_ | STC.deprecated_ | STC.override_ | STC.lazy_ |
     STC.alias_ | STC.out_ | STC.in_ | STC.manifest | STC.immutable_ | STC.shared_ |
     STC.wild | STC.nothrow_ | STC.nogc | STC.pure_ | STC.ref_ | STC.return_ | STC.tls |
     STC.gshared | STC.property | STC.live |
     STC.safeGroup | STC.disable);

enum TY : ubyte
{
    Tarray,     // slice array, aka T[]
    Tsarray,    // static array, aka T[dimension]
    Taarray,    // associative array, aka T[type]
    Tpointer,
    Treference,
    Tfunction,
    Tident,
    Tclass,
    Tstruct,
    Tenum,

    Tdelegate,
    Tnone,
    Tvoid,
    Tint8,
    Tuns8,
    Tint16,
    Tuns16,
    Tint32,
    Tuns32,
    Tint64,

    Tuns64,
    Tfloat32,
    Tfloat64,
    Tfloat80,
    Timaginary32,
    Timaginary64,
    Timaginary80,
    Tcomplex32,
    Tcomplex64,
    Tcomplex80,

    Tbool,
    Tchar,
    Twchar,
    Tdchar,
    Terror,
    Tinstance,
    Ttypeof,
    Ttuple,
    Tslice,
    Treturn,

    Tnull,
    Tvector,
    Tint128,
    Tuns128,
    Ttraits,
    Tmixin,
    Tnoreturn,
    Ttag,
    TMAX
}

alias Tarray = TY.Tarray;
alias Tsarray = TY.Tsarray;
alias Taarray = TY.Taarray;
alias Tpointer = TY.Tpointer;
alias Treference = TY.Treference;
alias Tfunction = TY.Tfunction;
alias Tident = TY.Tident;
alias Tclass = TY.Tclass;
alias Tstruct = TY.Tstruct;
alias Tenum = TY.Tenum;
alias Tdelegate = TY.Tdelegate;
alias Tnone = TY.Tnone;
alias Tvoid = TY.Tvoid;
alias Tint8 = TY.Tint8;
alias Tuns8 = TY.Tuns8;
alias Tint16 = TY.Tint16;
alias Tuns16 = TY.Tuns16;
alias Tint32 = TY.Tint32;
alias Tuns32 = TY.Tuns32;
alias Tint64 = TY.Tint64;
alias Tuns64 = TY.Tuns64;
alias Tfloat32 = TY.Tfloat32;
alias Tfloat64 = TY.Tfloat64;
alias Tfloat80 = TY.Tfloat80;
alias Timaginary32 = TY.Timaginary32;
alias Timaginary64 = TY.Timaginary64;
alias Timaginary80 = TY.Timaginary80;
alias Tcomplex32 = TY.Tcomplex32;
alias Tcomplex64 = TY.Tcomplex64;
alias Tcomplex80 = TY.Tcomplex80;
alias Tbool = TY.Tbool;
alias Tchar = TY.Tchar;
alias Twchar = TY.Twchar;
alias Tdchar = TY.Tdchar;
alias Terror = TY.Terror;
alias Tinstance = TY.Tinstance;
alias Ttypeof = TY.Ttypeof;
alias Ttuple = TY.Ttuple;
alias Tslice = TY.Tslice;
alias Treturn = TY.Treturn;
alias Tnull = TY.Tnull;
alias Tvector = TY.Tvector;
alias Tint128 = TY.Tint128;
alias Tuns128 = TY.Tuns128;
alias Ttraits = TY.Ttraits;
alias Tmixin = TY.Tmixin;
alias Tnoreturn = TY.Tnoreturn;
alias Ttag = TY.Ttag;
alias TMAX = TY.TMAX;

enum TFlags
{
    integral     = 1,
    floating     = 2,
    unsigned     = 4,
    real_        = 8,
    imaginary    = 0x10,
    complex      = 0x20,
}

enum PKG : int
{
    unknown,      /// not yet determined whether it's a package.d or not
    module_,      /// already determined that's an actual package.d
    package_,     /// already determined that's an actual package
}

enum StructPOD : int
{
    no,    /// struct is not POD
    yes,   /// struct is POD
    fwd,   /// POD not yet computed
}

enum TRUST : ubyte
{
    default_   = 0,
    system     = 1,    // @system (same as TRUST.default)
    trusted    = 2,    // @trusted
    safe       = 3,    // @safe
}

enum PURE : ubyte
{
    impure      = 0,    // not pure at all
    fwdref      = 1,    // it's pure, but not known which level yet
    weak        = 2,    // no mutable globals are read or written
    const_      = 3,    // parameters are values or const
    strong      = 4,    // parameters are values or immutable
}

// Whether alias this dependency is recursive or not
enum AliasThisRec : int
{
    no           = 0,    // no alias this recursion
    yes          = 1,    // alias this has recursive dependency
    fwdref       = 2,    // not yet known
    typeMask     = 3,    // mask to read no/yes/fwdref
    tracing      = 0x4,  // mark in progress of implicitConvTo/deduceWild
    tracingDT    = 0x8,  // mark in progress of deduceType
}

/***************
 * Variadic argument lists
 * https://dlang.org/spec/function.html#variadic
 */
enum VarArg : ubyte
{
    none     = 0,  /// fixed number of arguments
    variadic = 1,  /// (T t, ...)  can be C-style (core.stdc.stdarg) or D-style (core.vararg)
    typesafe = 2,  /// (T t ...) typesafe https://dlang.org/spec/function.html#typesafe_variadic_functions
                   ///   or https://dlang.org/spec/function.html#typesafe_variadic_functions
}

/*************************
 * Identify Statement types with this enum rather than
 * virtual functions
 */
enum STMT : ubyte
{
    Error,
    Peel,
    Exp, DtorExp,
    Compile,
    Compound, CompoundDeclaration, CompoundAsm,
    UnrolledLoop,
    Scope,
    Forwarding,
    While,
    Do,
    For,
    Foreach,
    ForeachRange,
    If,
    Conditional,
    StaticForeach,
    Pragma,
    StaticAssert,
    Switch,
    Case,
    CaseRange,
    Default,
    GotoDefault,
    GotoCase,
    SwitchError,
    Return,
    Break,
    Continue,
    Synchronized,
    With,
    TryCatch,
    TryFinally,
    ScopeGuard,
    Throw,
    Debug,
    Goto,
    Label,
    Asm, InlineAsm, GccAsm,
    Import,
}

/**********************
 * Discriminant for which kind of initializer
 */
enum InitKind : ubyte
{
    void_,
    error,
    struct_,
    array,
    exp,
    C_,
}

