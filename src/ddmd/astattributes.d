module ddmd.astattributes;

import ddmd.globals;

mixin template MAttributes()
{
    enum PROTKIND : int
    {
        PROTundefined,
        PROTnone,
        PROTprivate,
        PROTpackage,
        PROTprotected,
        PROTpublic,
        PROTexport,
    }

    alias PROTprivate       = PROTKIND.PROTprivate;
    alias PROTpackage       = PROTKIND.PROTpackage;
    alias PROTprotected     = PROTKIND.PROTprotected;
    alias PROTpublic        = PROTKIND.PROTpublic;
    alias PROTexport        = PROTKIND.PROTexport;
    alias PROTundefined     = PROTKIND.PROTundefined;
    alias PROTnone          = PROTKIND.PROTnone;

    enum Sizeok : int
    {
        SIZEOKnone,             // size of aggregate is not yet able to compute
        SIZEOKfwd,              // size of aggregate is ready to compute
        SIZEOKdone,             // size of aggregate is set correctly
    }

    alias SIZEOKnone = Sizeok.SIZEOKnone;
    alias SIZEOKdone = Sizeok.SIZEOKdone;
    alias SIZEOKfwd = Sizeok.SIZEOKfwd;

    enum Baseok : int
    {
        BASEOKnone,             // base classes not computed yet
        BASEOKin,               // in process of resolving base classes
        BASEOKdone,             // all base classes are resolved
        BASEOKsemanticdone,     // all base classes semantic done
    }

    alias BASEOKnone = Baseok.BASEOKnone;
    alias BASEOKin = Baseok.BASEOKin;
    alias BASEOKdone = Baseok.BASEOKdone;
    alias BASEOKsemanticdone = Baseok.BASEOKsemanticdone;

    enum MODFlags : int
    {
        MODconst        = 1,    // type is const
        MODimmutable    = 4,    // type is immutable
        MODshared       = 2,    // type is shared
        MODwild         = 8,    // type is wild
        MODwildconst    = (MODwild | MODconst), // type is wild const
        MODmutable      = 0x10, // type is mutable (only used in wildcard matching)
    }

    public alias MODconst = MODFlags.MODconst;
    alias MODimmutable = MODFlags.MODimmutable;
    alias MODshared = MODFlags.MODshared;
    alias MODwild = MODFlags.MODwild;
    alias MODwildconst = MODFlags.MODwildconst;
    alias MODmutable = MODFlags.MODmutable;

    alias MOD = ubyte;

    enum STCundefined           = 0L;
    enum STCstatic              = (1L << 0);
    enum STCextern              = (1L << 1);
    enum STCconst               = (1L << 2);
    enum STCfinal               = (1L << 3);
    enum STCabstract            = (1L << 4);
    enum STCparameter           = (1L << 5);
    enum STCfield               = (1L << 6);
    enum STCoverride            = (1L << 7);
    enum STCauto                = (1L << 8);
    enum STCsynchronized        = (1L << 9);
    enum STCdeprecated          = (1L << 10);
    enum STCin                  = (1L << 11);   // in parameter
    enum STCout                 = (1L << 12);   // out parameter
    enum STClazy                = (1L << 13);   // lazy parameter
    enum STCforeach             = (1L << 14);   // variable for foreach loop
    //                            (1L << 15)
    enum STCvariadic            = (1L << 16);   // the 'variadic' parameter in: T foo(T a, U b, V variadic...)
    enum STCctorinit            = (1L << 17);   // can only be set inside constructor
    enum STCtemplateparameter   = (1L << 18);   // template parameter
    enum STCscope               = (1L << 19);
    enum STCimmutable           = (1L << 20);
    enum STCref                 = (1L << 21);
    enum STCinit                = (1L << 22);   // has explicit initializer
    enum STCmanifest            = (1L << 23);   // manifest constant
    enum STCnodtor              = (1L << 24);   // don't run destructor
    enum STCnothrow             = (1L << 25);   // never throws exceptions
    enum STCpure                = (1L << 26);   // pure function
    enum STCtls                 = (1L << 27);   // thread local
    enum STCalias               = (1L << 28);   // alias parameter
    enum STCshared              = (1L << 29);   // accessible from multiple threads
    enum STCgshared             = (1L << 30);   // accessible from multiple threads, but not typed as "shared"
    enum STCwild                = (1L << 31);   // for "wild" type constructor
    enum STCproperty            = (1L << 32);
    enum STCsafe                = (1L << 33);
    enum STCtrusted             = (1L << 34);
    enum STCsystem              = (1L << 35);
    enum STCctfe                = (1L << 36);   // can be used in CTFE, even if it is static
    enum STCdisable             = (1L << 37);   // for functions that are not callable
    enum STCresult              = (1L << 38);   // for result variables passed to out contracts
    enum STCnodefaultctor       = (1L << 39);   // must be set inside constructor
    enum STCtemp                = (1L << 40);   // temporary variable
    enum STCrvalue              = (1L << 41);   // force rvalue for variables
    enum STCnogc                = (1L << 42);   // @nogc
    enum STCvolatile            = (1L << 43);   // destined for volatile in the back end
    enum STCreturn              = (1L << 44);   // 'return ref' or 'return scope' for function parameters
    enum STCautoref             = (1L << 45);   // Mark for the already deduced 'auto ref' parameter
    enum STCinference           = (1L << 46);   // do attribute inference
    enum STCexptemp             = (1L << 47);   // temporary variable that has lifetime restricted to an expression
    enum STCmaybescope          = (1L << 48);   // parameter might be 'scope'

    enum STC_TYPECTOR = (STCconst | STCimmutable | STCshared | STCwild);

    enum STC_FUNCATTR = (STCref | STCnothrow | STCnogc | STCpure | STCproperty | STCsafe | STCtrusted | STCsystem);

    extern (C++) __gshared const(StorageClass) STCStorageClass =
            (STCauto | STCscope | STCstatic | STCextern | STCconst | STCfinal | STCabstract | STCsynchronized | STCdeprecated | STCoverride | STClazy | STCalias | STCout | STCin | STCmanifest | STCimmutable | STCshared | STCwild | STCnothrow | STCnogc | STCpure | STCref | STCtls | STCgshared | STCproperty | STCsafe | STCtrusted | STCsystem | STCdisable);


    enum ENUMTY : int
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
        TMAX
    }

    alias Tarray = ENUMTY.Tarray;
    alias Tsarray = ENUMTY.Tsarray;
    alias Taarray = ENUMTY.Taarray;
    alias Tpointer = ENUMTY.Tpointer;
    alias Treference = ENUMTY.Treference;
    alias Tfunction = ENUMTY.Tfunction;
    alias Tident = ENUMTY.Tident;
    alias Tclass = ENUMTY.Tclass;
    alias Tstruct = ENUMTY.Tstruct;
    alias Tenum = ENUMTY.Tenum;
    alias Tdelegate = ENUMTY.Tdelegate;
    alias Tnone = ENUMTY.Tnone;
    alias Tvoid = ENUMTY.Tvoid;
    alias Tint8 = ENUMTY.Tint8;
    alias Tuns8 = ENUMTY.Tuns8;
    alias Tint16 = ENUMTY.Tint16;
    alias Tuns16 = ENUMTY.Tuns16;
    alias Tint32 = ENUMTY.Tint32;
    alias Tuns32 = ENUMTY.Tuns32;
    alias Tint64 = ENUMTY.Tint64;
    alias Tuns64 = ENUMTY.Tuns64;
    alias Tfloat32 = ENUMTY.Tfloat32;
    alias Tfloat64 = ENUMTY.Tfloat64;
    alias Tfloat80 = ENUMTY.Tfloat80;
    alias Timaginary32 = ENUMTY.Timaginary32;
    alias Timaginary64 = ENUMTY.Timaginary64;
    alias Timaginary80 = ENUMTY.Timaginary80;
    alias Tcomplex32 = ENUMTY.Tcomplex32;
    alias Tcomplex64 = ENUMTY.Tcomplex64;
    alias Tcomplex80 = ENUMTY.Tcomplex80;
    alias Tbool = ENUMTY.Tbool;
    alias Tchar = ENUMTY.Tchar;
    alias Twchar = ENUMTY.Twchar;
    alias Tdchar = ENUMTY.Tdchar;
    alias Terror = ENUMTY.Terror;
    alias Tinstance = ENUMTY.Tinstance;
    alias Ttypeof = ENUMTY.Ttypeof;
    alias Ttuple = ENUMTY.Ttuple;
    alias Tslice = ENUMTY.Tslice;
    alias Treturn = ENUMTY.Treturn;
    alias Tnull = ENUMTY.Tnull;
    alias Tvector = ENUMTY.Tvector;
    alias Tint128 = ENUMTY.Tint128;
    alias Tuns128 = ENUMTY.Tuns128;
    alias TMAX = ENUMTY.TMAX;

    alias TY = ubyte;

    enum TFLAGSintegral     = 1;
    enum TFLAGSfloating     = 2;
    enum TFLAGSunsigned     = 4;
    enum TFLAGSreal         = 8;
    enum TFLAGSimaginary    = 0x10;
    enum TFLAGScomplex      = 0x20;

    enum PKG : int
    {
        PKGunknown,     // not yet determined whether it's a package.d or not
        PKGmodule,      // already determined that's an actual package.d
        PKGpackage,     // already determined that's an actual package
    }

    alias PKGunknown = PKG.PKGunknown;
    alias PKGmodule = PKG.PKGmodule;
    alias PKGpackage = PKG.PKGpackage;

    enum StructPOD : int
    {
        ISPODno,    // struct is not POD
        ISPODyes,   // struct is POD
        ISPODfwd,   // POD not yet computed
    }

    alias ISPODno = StructPOD.ISPODno;
    alias ISPODyes = StructPOD.ISPODyes;
    alias ISPODfwd = StructPOD.ISPODfwd;

    enum TRUST : int
    {
        TRUSTdefault    = 0,
        TRUSTsystem     = 1,    // @system (same as TRUSTdefault)
        TRUSTtrusted    = 2,    // @trusted
        TRUSTsafe       = 3,    // @safe
    }

    alias TRUSTdefault = TRUST.TRUSTdefault;
    alias TRUSTsystem = TRUST.TRUSTsystem;
    alias TRUSTtrusted = TRUST.TRUSTtrusted;
    alias TRUSTsafe = TRUST.TRUSTsafe;

    enum PURE : int
    {
        PUREimpure      = 0,    // not pure at all
        PUREfwdref      = 1,    // it's pure, but not known which level yet
        PUREweak        = 2,    // no mutable globals are read or written
        PUREconst       = 3,    // parameters are values or const
        PUREstrong      = 4,    // parameters are values or immutable
    }

    alias PUREimpure = PURE.PUREimpure;
    alias PUREfwdref = PURE.PUREfwdref;
    alias PUREweak = PURE.PUREweak;
    alias PUREconst = PURE.PUREconst;
    alias PUREstrong = PURE.PUREstrong;

    enum AliasThisRec : int
    {
        RECno           = 0,    // no alias this recursion
        RECyes          = 1,    // alias this has recursive dependency
        RECfwdref       = 2,    // not yet known
        RECtypeMask     = 3,    // mask to read no/yes/fwdref
        RECtracing      = 0x4,  // mark in progress of implicitConvTo/deduceWild
        RECtracingDT    = 0x8,  // mark in progress of deduceType
    }

    alias RECno = AliasThisRec.RECno;
    alias RECyes = AliasThisRec.RECyes;
    alias RECfwdref = AliasThisRec.RECfwdref;
    alias RECtypeMask = AliasThisRec.RECtypeMask;
    alias RECtracing = AliasThisRec.RECtracing;
    alias RECtracingDT = AliasThisRec.RECtracingDT;
}
