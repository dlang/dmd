module ddmd.astbase;

import ddmd.astbasevisitor;

/** The ASTBase  family defines a family of AST nodes appropriate for parsing with
  * no semantic information. It defines all the AST nodes that the parser needs
  * and also all the conveniance methods and variables. The resulting AST can be
  * visited with the strict, permissive and transitive visitors.
  * The ASTBase family is used to instantiate the parser in the parser library.
  */
struct ASTBase
{
    import ddmd.root.file;
    import ddmd.root.filename;
    import ddmd.root.array;
    import ddmd.root.rootobject;
    import ddmd.root.outbuffer;
    import ddmd.root.ctfloat;
    import ddmd.root.rmem;
    import ddmd.root.stringtable;

    import ddmd.tokens;
    import ddmd.identifier;
    import ddmd.globals;
    import ddmd.id;
    import ddmd.errors;
    import ddmd.lexer;

    import core.stdc.string;
    import core.stdc.stdarg;

    alias Dsymbols              = Array!(Dsymbol);
    alias Objects               = Array!(RootObject);
    alias Expressions           = Array!(Expression);
    alias TemplateParameters    = Array!(TemplateParameter);
    alias BaseClasses           = Array!(BaseClass*);
    alias Parameters            = Array!(Parameter);
    alias Statements            = Array!(Statement);
    alias Catches               = Array!(Catch);
    alias Identifiers           = Array!(Identifier);
    alias Initializers          = Array!(Initializer);

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

    alias MODconst = MODFlags.MODconst;
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
    enum STCfuture              = (1L << 49);   // introducing new base class function

    enum STC_TYPECTOR = (STCconst | STCimmutable | STCshared | STCwild);

    private enum STC_FUNCATTR = (STCref | STCnothrow | STCnogc | STCpure | STCproperty | STCsafe | STCtrusted | STCsystem);

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

    extern (C++) class Dsymbol : RootObject
    {
        Loc loc;
        Identifier ident;
        UnitTestDeclaration ddocUnittest;
        UserAttributeDeclaration userAttribDecl;
        Dsymbol parent;

        const(char)* comment;

        final extern (D) this() {}
        final extern (D) this(Identifier ident)
        {
            this.ident = ident;
        }

        void addComment(const(char)* comment)
        {
            if (!this.comment)
                this.comment = comment;
            else if (comment && strcmp(cast(char*)comment, cast(char*)this.comment) != 0)
                this.comment = Lexer.combineComments(this.comment, comment, true);
        }

        override const(char)* toChars()
        {
            return ident ? ident.toChars() : "__anonymous";
        }

        bool oneMember(Dsymbol *ps, Identifier ident)
        {
            *ps = this;
            return true;
        }

        static bool oneMembers(Dsymbols* members, Dsymbol* ps, Identifier ident)
        {
            Dsymbol s = null;
            if (members)
            {
                for (size_t i = 0; i < members.dim; i++)
                {
                    Dsymbol sx = (*members)[i];
                    bool x = sx.oneMember(ps, ident);
                    if (!x)
                    {
                        assert(*ps is null);
                        return false;
                    }
                    if (*ps)
                    {
                        assert(ident);
                        if (!(*ps).ident || !(*ps).ident.equals(ident))
                            continue;
                        if (!s)
                            s = *ps;
                        else if (s.isOverloadable() && (*ps).isOverloadable())
                        {
                            // keep head of overload set
                            FuncDeclaration f1 = s.isFuncDeclaration();
                            FuncDeclaration f2 = (*ps).isFuncDeclaration();
                            if (f1 && f2)
                            {
                                for (; f1 != f2; f1 = f1.overnext0)
                                {
                                    if (f1.overnext0 is null)
                                    {
                                        f1.overnext0 = f2;
                                        break;
                                    }
                                }
                            }
                        }
                        else // more than one symbol
                        {
                            *ps = null;
                            //printf("\tfalse 2\n");
                            return false;
                        }
                    }
                }
            }
            *ps = s;
            return true;
        }

        bool isOverloadable()
        {
            return false;
        }

        const(char)* kind() const
        {
            return "symbol";
        }

        final void error(A...)(const(char)* format, A args)
        {
            va_list ap;
            va_start(ap, format);
            // last parameter : toPrettyChars
            verror(loc, format, ap, kind(), "");
            va_end(ap);
        }

        inout(AttribDeclaration) isAttribDeclaration() inout
        {
            return null;
        }

        inout(TemplateDeclaration) isTemplateDeclaration() inout
        {
            return null;
        }

        inout(FuncLiteralDeclaration) isFuncLiteralDeclaration() inout
        {
            return null;
        }

        inout(FuncDeclaration) isFuncDeclaration() inout
        {
            return null;
        }

        inout(VarDeclaration) isVarDeclaration() inout
        {
            return null;
        }

        inout(TemplateInstance) isTemplateInstance() inout
        {
            return null;
        }

        inout(Declaration) isDeclaration() inout
        {
            return null;
        }

        inout(ClassDeclaration) isClassDeclaration() inout
        {
            return null;
        }

        inout(AggregateDeclaration) isAggregateDeclaration() inout
        {
            return null;
        }

        Dsymbol syntaxCopy(Dsymbol s)
        {
            return null;
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class AliasThis : Dsymbol
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(null);
            this.loc = loc;
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class Declaration : Dsymbol
    {
        StorageClass storage_class;
        Prot protection;
        LINK linkage;
        Type type;

        final extern (D) this(Identifier id)
        {
            super(id);
            storage_class = STCundefined;
            protection = Prot(PROTundefined);
            linkage = LINKdefault;
        }

        override final inout(Declaration) isDeclaration() inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class ScopeDsymbol : Dsymbol
    {
        Dsymbols* members;
        final extern (D) this() {}
        final extern (D) this(Identifier id)
        {
            super(id);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class Import : Dsymbol
    {
        Identifiers* packages;
        Identifier id;
        Identifier aliasId;
        int isstatic;
        Prot protection;

        Identifiers names;
        Identifiers aliases;

        extern (D) this(Loc loc, Identifiers* packages, Identifier id, Identifier aliasId, int isstatic)
        {
            super(null);
            this.loc = loc;
            this.packages = packages;
            this.id = id;
            this.aliasId = aliasId;
            this.isstatic = isstatic;
            this.protection = Prot(PROTprivate);

            if (aliasId)
            {
                // import [cstdio] = std.stdio;
                this.ident = aliasId;
            }
            else if (packages && packages.dim)
            {
                // import [std].stdio;
                this.ident = (*packages)[0];
            }
            else
            {
                // import [foo];
                this.ident = id;
            }
        }
        void addAlias(Identifier name, Identifier _alias)
        {
            if (isstatic)
                error("cannot have an import bind list");
            if (!aliasId)
                this.ident = null;

            names.push(name);
            aliases.push(_alias);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class AttribDeclaration : Dsymbol
    {
        Dsymbols* decl;

        final extern (D) this(Dsymbols *decl)
        {
            this.decl = decl;
        }

        override final inout(AttribDeclaration) isAttribDeclaration() inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StaticAssert : Dsymbol
    {
        Expression exp;
        Expression msg;

        extern (D) this(Loc loc, Expression exp, Expression msg)
        {
            super(Id.empty);
            this.loc = loc;
            this.exp = exp;
            this.msg = msg;
        }
    }

    extern (C++) final class DebugSymbol : Dsymbol
    {
        uint level;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(ident);
            this.loc = loc;
        }
        extern (D) this(Loc loc, uint level)
        {
            this.level = level;
            this.loc = loc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class VersionSymbol : Dsymbol
    {
        uint level;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(ident);
            this.loc = loc;
        }
        extern (D) this(Loc loc, uint level)
        {
            this.level = level;
            this.loc = loc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class VarDeclaration : Declaration
    {
        Type type;
        Initializer _init;
        StorageClass storage_class;
        int ctfeAdrOnStack;
        uint sequenceNumber;
        __gshared uint nextSequenceNumber;

        final extern (D) this(Loc loc, Type type, Identifier id, Initializer _init, StorageClass st = STCundefined)
        {
            super(id);
            this.type = type;
            this._init = _init;
            this.loc = loc;
            this.storage_class = storage_class;
            sequenceNumber = ++nextSequenceNumber;
            ctfeAdrOnStack = -1;
        }

        override final inout(VarDeclaration) isVarDeclaration() inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class FuncDeclaration : Declaration
    {
        Statement fbody;
        Statement frequire;
        Statement fensure;
        Loc endloc;
        Identifier outId;
        StorageClass storage_class;
        Type type;
        bool inferRetType;
        ForeachStatement fes;
        FuncDeclaration overnext0;

        final extern (D) this(Loc loc, Loc endloc, Identifier id, StorageClass storage_class, Type type)
        {
            super(id);
            this.storage_class = storage_class;
            this.type = type;
            if (type)
            {
                // Normalize storage_class, because function-type related attributes
                // are already set in the 'type' in parsing phase.
                this.storage_class &= ~(STC_TYPECTOR | STC_FUNCATTR);
            }
            this.loc = loc;
            this.endloc = endloc;
            inferRetType = (type && type.nextOf() is null);
        }

        FuncLiteralDeclaration* isFuncLiteralDeclaration()
        {
            return null;
        }

        override bool isOverloadable()
        {
            return true;
        }

        override final inout(FuncDeclaration) isFuncDeclaration() inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AliasDeclaration : Declaration
    {
        Dsymbol aliassym;

        extern (D) this(Loc loc, Identifier id, Dsymbol s)
        {
            super(id);
            this.loc = loc;
            this.aliassym = s;
        }

        extern (D) this(Loc loc, Identifier id, Type type)
        {
            super(id);
            this.loc = loc;
            this.type = type;
        }

        override bool isOverloadable()
        {
            //assume overloadable until alias is resolved;
            // should be modified when semantic analysis is added
            return true;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TupleDeclaration : Declaration
    {
        Objects* objects;

        extern (D) this(Loc loc, Identifier id, Objects* objects)
        {
            super(id);
            this.loc = loc;
            this.objects = objects;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class FuncLiteralDeclaration : FuncDeclaration
    {
        TOK tok;

        extern (D) this(Loc loc, Loc endloc, Type type, TOK tok, ForeachStatement fes, Identifier id = null)
        {
            super(loc, endloc, null, STCundefined, type);
            this.ident = id ? id : Id.empty;
            this.tok = tok;
            this.fes = fes;
        }

        override inout(FuncLiteralDeclaration) isFuncLiteralDeclaration() inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PostBlitDeclaration : FuncDeclaration
    {
        extern (D) this(Loc loc, Loc endloc, StorageClass stc, Identifier id)
        {
            super(loc, endloc, id, stc, null);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CtorDeclaration : FuncDeclaration
    {
        extern (D) this(Loc loc, Loc endloc, StorageClass stc, Type type)
        {
            super(loc, endloc, Id.ctor, stc, type);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DtorDeclaration : FuncDeclaration
    {
        extern (D) this(Loc loc, Loc endloc)
        {
            super(loc, endloc, Id.dtor, STCundefined, null);
        }
        extern (D) this(Loc loc, Loc endloc, StorageClass stc, Identifier id)
        {
            super(loc, endloc, id, stc, null);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class InvariantDeclaration : FuncDeclaration
    {
        extern (D) this(Loc loc, Loc endloc, StorageClass stc, Identifier id, Statement fbody)
        {
            super(loc, endloc, id ? id : Identifier.generateId("__invariant"), stc, null);
            this.fbody = fbody;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class UnitTestDeclaration : FuncDeclaration
    {
        char* codedoc;

        extern (D) this(Loc loc, Loc endloc, StorageClass stc, char* codedoc)
        {
            OutBuffer buf;
            buf.printf("__unittestL%u_", loc.linnum);
            super(loc, endloc, Identifier.generateId(buf.peekString()), stc, null);
            this.codedoc = codedoc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class NewDeclaration : FuncDeclaration
    {
        Parameters* parameters;
        int varargs;

        extern (D) this(Loc loc, Loc endloc, StorageClass stc, Parameters* fparams, int varargs)
        {
            super(loc, endloc, Id.classNew, STCstatic | stc, null);
            this.parameters = fparams;
            this.varargs = varargs;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DeleteDeclaration : FuncDeclaration
    {
        Parameters* parameters;

        extern (D) this(Loc loc, Loc endloc, StorageClass stc, Parameters* fparams)
        {
            super(loc, endloc, Id.classDelete, STCstatic | stc, null);
            this.parameters = fparams;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class StaticCtorDeclaration : FuncDeclaration
    {
        final extern (D) this(Loc loc, Loc endloc, StorageClass stc)
        {
            super(loc, endloc, Identifier.generateId("_staticCtor"), STCstatic | stc, null);
        }
        final extern (D) this(Loc loc, Loc endloc, const(char)* name, StorageClass stc)
        {
            super(loc, endloc, Identifier.generateId(name), STCstatic | stc, null);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class StaticDtorDeclaration : FuncDeclaration
    {
        final extern (D) this()(Loc loc, Loc endloc, StorageClass stc)
        {
            super(loc, endloc, Identifier.generateId("__staticDtor"), STCstatic | stc, null);
        }
        final extern (D) this(Loc loc, Loc endloc, const(char)* name, StorageClass stc)
        {
            super(loc, endloc, Identifier.generateId(name), STCstatic | stc, null);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class SharedStaticCtorDeclaration : StaticCtorDeclaration
    {
        extern (D) this(Loc loc, Loc endloc, StorageClass stc)
        {
            super(loc, endloc, "_sharedStaticCtor", stc);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class SharedStaticDtorDeclaration : StaticDtorDeclaration
    {
        extern (D) this(Loc loc, Loc endloc, StorageClass stc)
        {
            super(loc, endloc, "_sharedStaticDtor", stc);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class Package : ScopeDsymbol
    {
        PKG isPkgMod;
        uint tag;

        final extern (D) this(Identifier ident)
        {
            super(ident);
            this.isPkgMod = PKGunknown;
            __gshared uint packageTag;
            this.tag = packageTag++;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class EnumDeclaration : ScopeDsymbol
    {
        Type type;
        Type memtype;
        Prot protection;

        extern (D) this(Loc loc, Identifier id, Type memtype)
        {
            super(id);
            this.loc = loc;
            type = new TypeEnum(this);
            this.memtype = memtype;
            protection = Prot(PROTundefined);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class AggregateDeclaration : ScopeDsymbol
    {
        Prot protection;
        Sizeok sizeok;
        Type type;

        final extern (D) this(Loc loc, Identifier id)
        {
            super(id);
            this.loc = loc;
            protection = Prot(PROTpublic);
            sizeok = SIZEOKnone;
        }

        override final inout(AggregateDeclaration) isAggregateDeclaration() inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TemplateDeclaration : ScopeDsymbol
    {
        TemplateParameters* parameters;
        TemplateParameters* origParameters;
        Expression constraint;
        bool literal;
        bool ismixin;
        bool isstatic;
        Prot protection;
        Dsymbol onemember;

        extern (D) this(Loc loc, Identifier id, TemplateParameters* parameters, Expression constraint, Dsymbols* decldefs, bool ismixin = false, bool literal = false)
        {
            super(id);
            this.loc = loc;
            this.parameters = parameters;
            this.origParameters = parameters;
            this.members = decldefs;
            this.literal = literal;
            this.ismixin = ismixin;
            this.isstatic = true;
            this.protection = Prot(PROTundefined);

            if (members && ident)
            {
                Dsymbol s;
                if (Dsymbol.oneMembers(members, &s, ident) && s)
                {
                    onemember = s;
                    s.parent = this;
                }
            }
        }

        override bool isOverloadable()
        {
            return true;
        }

        override inout(TemplateDeclaration) isTemplateDeclaration () inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TemplateInstance : ScopeDsymbol
    {
        Identifier name;
        Objects* tiargs;
        Dsymbol tempdecl;
        bool semantictiargsdone;
        bool havetempdecl;
        TemplateInstance inst;

        final extern (D) this(Loc loc, Identifier ident, Objects* tiards)
        {
            super(null);
            this.loc = loc;
            this.name = ident;
            this.tiargs = tiargs;
        }

        final extern (D) this(Loc loc, TemplateDeclaration td, Objects* tiargs)
        {
            super(null);
            this.loc = loc;
            this.name = td.ident;
            this.tempdecl = td;
            this.semantictiargsdone = true;
            this.havetempdecl = true;
        }

        override final inout(TemplateInstance) isTemplateInstance() inout
        {
            return this;
        }

        Objects* arraySyntaxCopy(Objects* objs)
        {
            Objects* a = null;
            if (objs)
            {
                a = new Objects();
                a.setDim(objs.dim);
                for (size_t i = 0; i < objs.dim; i++)
                    (*a)[i] = objectSyntaxCopy((*objs)[i]);
            }
            return a;
        }

        RootObject objectSyntaxCopy(RootObject o)
        {
            if (!o)
                return null;
            if (Type t = isType(o))
                return t.syntaxCopy();
            if (Expression e = isExpression(o))
                return e.syntaxCopy();
            return o;
        }

        override Dsymbol syntaxCopy(Dsymbol s)
        {
            TemplateInstance ti = s ? cast(TemplateInstance)s : new TemplateInstance(loc, name, null);
            ti.tiargs = arraySyntaxCopy(tiargs);
            TemplateDeclaration td;
            if (inst && tempdecl && (td = tempdecl.isTemplateDeclaration()) !is null)
                td.ScopeDsymbol.syntaxCopy(ti);
            else
                ScopeDsymbol.syntaxCopy(ti);
            return ti;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class Nspace : ScopeDsymbol
    {
        extern (D) this(Loc loc, Identifier ident, Dsymbols* members)
        {
            super(ident);
            this.loc = loc;
            this.members = members;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CompileDeclaration : AttribDeclaration
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(null);
            this.loc = loc;
            this.exp = exp;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class UserAttributeDeclaration : AttribDeclaration
    {
        Expressions* atts;

        extern (D) this(Expressions* atts, Dsymbols* decl)
        {
            super(decl);
            this.atts = atts;
        }

        static Expressions* concat(Expressions* udas1, Expressions* udas2)
        {
            Expressions* udas;
            if (!udas1 || udas1.dim == 0)
                udas = udas2;
            else if (!udas2 || udas2.dim == 0)
                udas = udas1;
            else
            {
                udas = new Expressions();
                udas.push(new TupleExp(Loc(), udas1));
                udas.push(new TupleExp(Loc(), udas2));
            }
            return udas;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class LinkDeclaration : AttribDeclaration
    {
        LINK linkage;

        extern (D) this(LINK p, Dsymbols* decl)
        {
            super(decl);
            linkage = p;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AnonDeclaration : AttribDeclaration
    {
        bool isunion;

        extern (D) this(Loc loc, bool isunion, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.isunion = isunion;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AlignDeclaration : AttribDeclaration
    {
        Expression ealign;

        extern (D) this(Loc loc, Expression ealign, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.ealign = ealign;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CPPMangleDeclaration : AttribDeclaration
    {
        CPPMANGLE cppmangle;

        extern (D) this(CPPMANGLE p, Dsymbols* decl)
        {
            super(decl);
            cppmangle = p;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ProtDeclaration : AttribDeclaration
    {
        Prot protection;
        Identifiers* pkg_identifiers;

        extern (D) this(Loc loc, Prot p, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.protection = p;
        }
        extern (D) this(Loc loc, Identifiers* pkg_identifiers, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.protection.kind = PROTpackage;
            this.protection.pkg = null;
            this.pkg_identifiers = pkg_identifiers;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PragmaDeclaration : AttribDeclaration
    {
        Expressions* args;

        extern (D) this(Loc loc, Identifier ident, Expressions* args, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.ident = ident;
            this.args = args;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class StorageClassDeclaration : AttribDeclaration
    {
        StorageClass stc;

        final extern (D) this(StorageClass stc, Dsymbols* decl)
        {
            super(decl);
            this.stc = stc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class ConditionalDeclaration : AttribDeclaration
    {
        Condition condition;
        Dsymbols* elsedecl;

        final extern (D) this(Condition condition, Dsymbols* decl, Dsymbols* elsedecl)
        {
            super(decl);
            this.condition = condition;
            this.elsedecl = elsedecl;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DeprecatedDeclaration : StorageClassDeclaration
    {
        Expression msg;

        extern (D) this(Expression msg, Dsymbols* decl)
        {
            super(STCdeprecated, decl);
            this.msg = msg;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StaticIfDeclaration : ConditionalDeclaration
    {
        extern (D) this(Condition condition, Dsymbols* decl, Dsymbols* elsedecl)
        {
            super(condition, decl, elsedecl);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StaticForeachDeclaration : AttribDeclaration
    {
        StaticForeach sfe;

        extern (D) this(StaticForeach sfe, Dsymbols* decl)
        {
            super(decl);
            this.sfe = sfe;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class EnumMember : VarDeclaration
    {
        Expression origValue;
        Type origType;

        @property ref value() { return (cast(ExpInitializer)_init).exp; }

        extern (D) this(Loc loc, Identifier id, Expression value, Type origType)
        {
            super(loc, null, id ? id : Id.empty, new ExpInitializer(loc, value));
            this.origValue = value;
            this.origType = origType;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class Module : Package
    {
        extern (C++) static __gshared AggregateDeclaration moduleinfo;

        File* srcfile;
        const(char)* arg;
        const(char)* srcfilePath;

        extern (D) this(const(char)* filename, Identifier ident, int doDocComment, int doHdrGen)
        {
            super(ident);
            this.arg = filename;
            const(char)* srcfilename = FileName.defaultExt(filename, global.mars_ext);
            srcfile = new File(srcfilename);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class StructDeclaration : AggregateDeclaration
    {
        int zeroInit;
        StructPOD ispod;

        final extern (D) this(Loc loc, Identifier id)
        {
            super(loc, id);
            zeroInit = 0;
            ispod = ISPODfwd;
            type = new TypeStruct(this);
            if (id == Id.ModuleInfo && !Module.moduleinfo)
                Module.moduleinfo = this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class UnionDeclaration : StructDeclaration
    {
        extern (D) this(Loc loc, Identifier id)
        {
            super(loc, id);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class ClassDeclaration : AggregateDeclaration
    {
        extern (C++) __gshared
        {
            // Names found by reading object.d in druntime
            ClassDeclaration object;
            ClassDeclaration throwable;
            ClassDeclaration exception;
            ClassDeclaration errorException;
            ClassDeclaration cpp_type_info_ptr;   // Object.__cpp_type_info_ptr
        }

        BaseClasses* baseclasses;
        Baseok baseok;

        final extern (D) this(Loc loc, Identifier id, BaseClasses* baseclasses, Dsymbols* members, bool inObject)
        {
            if(!id)
                id = Identifier.generateId("__anonclass");
            assert(id);

            super(loc, id);

            static __gshared const(char)* msg = "only object.d can define this reserved class name";

            if (baseclasses)
            {
                // Actually, this is a transfer
                this.baseclasses = baseclasses;
            }
            else
                this.baseclasses = new BaseClasses();

            this.members = members;

            //printf("ClassDeclaration(%s), dim = %d\n", id.toChars(), this.baseclasses.dim);

            // For forward references
            type = new TypeClass(this);

            if (id)
            {
                // Look for special class names
                if (id == Id.__sizeof || id == Id.__xalignof || id == Id._mangleof)
                    error("illegal class name");

                // BUG: What if this is the wrong TypeInfo, i.e. it is nested?
                if (id.toChars()[0] == 'T')
                {
                    if (id == Id.TypeInfo)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.dtypeinfo = this;
                    }
                    if (id == Id.TypeInfo_Class)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfoclass = this;
                    }
                    if (id == Id.TypeInfo_Interface)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfointerface = this;
                    }
                    if (id == Id.TypeInfo_Struct)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfostruct = this;
                    }
                    if (id == Id.TypeInfo_Pointer)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfopointer = this;
                    }
                    if (id == Id.TypeInfo_Array)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfoarray = this;
                    }
                    if (id == Id.TypeInfo_StaticArray)
                    {
                        //if (!inObject)
                        //    Type.typeinfostaticarray.error("%s", msg);
                        Type.typeinfostaticarray = this;
                    }
                    if (id == Id.TypeInfo_AssociativeArray)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfoassociativearray = this;
                    }
                    if (id == Id.TypeInfo_Enum)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfoenum = this;
                    }
                    if (id == Id.TypeInfo_Function)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfofunction = this;
                    }
                    if (id == Id.TypeInfo_Delegate)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfodelegate = this;
                    }
                    if (id == Id.TypeInfo_Tuple)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfotypelist = this;
                    }
                    if (id == Id.TypeInfo_Const)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfoconst = this;
                    }
                    if (id == Id.TypeInfo_Invariant)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfoinvariant = this;
                    }
                    if (id == Id.TypeInfo_Shared)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfoshared = this;
                    }
                    if (id == Id.TypeInfo_Wild)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfowild = this;
                    }
                    if (id == Id.TypeInfo_Vector)
                    {
                        if (!inObject)
                            error("%s", msg);
                        Type.typeinfovector = this;
                    }
                }

                if (id == Id.Object)
                {
                    if (!inObject)
                        error("%s", msg);
                    object = this;
                }

                if (id == Id.Throwable)
                {
                    if (!inObject)
                        error("%s", msg);
                    throwable = this;
                }
                if (id == Id.Exception)
                {
                    if (!inObject)
                        error("%s", msg);
                    exception = this;
                }
                if (id == Id.Error)
                {
                    if (!inObject)
                        error("%s", msg);
                    errorException = this;
                }
                if (id == Id.cpp_type_info_ptr)
                {
                    if (!inObject)
                        error("%s", msg);
                    cpp_type_info_ptr = this;
                }
            }
            baseok = BASEOKnone;
        }

        override final inout(ClassDeclaration) isClassDeclaration() inout
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class InterfaceDeclaration : ClassDeclaration
    {
        final extern (D) this(Loc loc, Identifier id, BaseClasses* baseclasses)
        {
            super(loc, id, baseclasses, null, false);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TemplateMixin : TemplateInstance
    {
        TypeQualified tqual;

        extern (D) this(Loc loc, Identifier ident, TypeQualified tqual, Objects *tiargs)
        {
            super(loc,
                  tqual.idents.dim ? cast(Identifier)tqual.idents[tqual.idents.dim - 1] : (cast(TypeIdentifier)tqual).ident,
                  tiargs ? tiargs : new Objects());
            this.ident = ident;
            this.tqual = tqual;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class Parameter : RootObject
    {
        StorageClass storageClass;
        Type type;
        Identifier ident;
        Expression defaultArg;

        extern (D) alias ForeachDg = int delegate(size_t idx, Parameter param);

        final extern (D) this(StorageClass storageClass, Type type, Identifier ident, Expression defaultArg)
        {
            this.storageClass = storageClass;
            this.type = type;
            this.ident = ident;
            this.defaultArg = defaultArg;
        }

        static size_t dim(Parameters* parameters)
        {
           size_t nargs = 0;

            int dimDg(size_t n, Parameter p)
            {
                ++nargs;
                return 0;
            }

            _foreach(parameters, &dimDg);
            return nargs;
        }

        static Parameter getNth(Parameters* parameters, size_t nth, size_t* pn = null)
        {
            Parameter param;

            int getNthParamDg(size_t n, Parameter p)
            {
                if (n == nth)
                {
                    param = p;
                    return 1;
                }
                return 0;
            }

            int res = _foreach(parameters, &getNthParamDg);
            return res ? param : null;
        }

        extern (D) static int _foreach(Parameters* parameters, scope ForeachDg dg, size_t* pn = null)
        {
            assert(dg);
            if (!parameters)
                return 0;

            size_t n = pn ? *pn : 0; // take over index
            int result = 0;
            foreach (i; 0 .. parameters.dim)
            {
                Parameter p = (*parameters)[i];
                Type t = p.type.toBasetype();

                if (t.ty == Ttuple)
                {
                    TypeTuple tu = cast(TypeTuple)t;
                    result = _foreach(tu.arguments, dg, &n);
                }
                else
                    result = dg(n++, p);

                if (result)
                    break;
            }

            if (pn)
                *pn = n; // update index
            return result;
        }

        Parameter syntaxCopy()
        {
            return new Parameter(storageClass, type ? type.syntaxCopy() : null, ident, defaultArg ? defaultArg.syntaxCopy() : null);
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }

        static Parameters* arraySyntaxCopy(Parameters* parameters)
        {
            Parameters* params = null;
            if (parameters)
            {
                params = new Parameters();
                params.setDim(parameters.dim);
                for (size_t i = 0; i < params.dim; i++)
                    (*params)[i] = (*parameters)[i].syntaxCopy();
            }
            return params;
        }

    }

    extern (C++) abstract class Statement : RootObject
    {
        Loc loc;

        final extern (D) this(Loc loc)
        {
            this.loc = loc;
        }

        ExpStatement isExpStatement()
        {
            return null;
        }

        inout(CompoundStatement) isCompoundStatement() inout nothrow pure
        {
            return null;
        }

        inout(ReturnStatement) isReturnStatement() inout nothrow pure
        {
            return null;
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ImportStatement : Statement
    {
        Dsymbols* imports;

        extern (D) this(Loc loc, Dsymbols* imports)
        {
            super(loc);
            this.imports = imports;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ScopeStatement : Statement
    {
        Statement statement;
        Loc endloc;

        extern (D) this(Loc loc, Statement s, Loc endloc)
        {
            super(loc);
            this.statement = s;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ReturnStatement : Statement
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
        }

        override inout(ReturnStatement) isReturnStatement() inout nothrow pure
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class LabelStatement : Statement
    {
        Identifier ident;
        Statement statement;

        final extern (D) this(Loc loc, Identifier ident, Statement statement)
        {
            super(loc);
            this.ident = ident;
            this.statement = statement;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StaticAssertStatement : Statement
    {
        StaticAssert sa;

        final extern (D) this(StaticAssert sa)
        {
            super(sa.loc);
            this.sa = sa;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CompileStatement : Statement
    {
        Expression exp;

        final extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class WhileStatement : Statement
    {
        Expression condition;
        Statement _body;
        Loc endloc;

        extern (D) this(Loc loc, Expression c, Statement b, Loc endloc)
        {
            super(loc);
            condition = c;
            _body = b;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ForStatement : Statement
    {
        Statement _init;
        Expression condition;
        Expression increment;
        Statement _body;
        Loc endloc;

        extern (D) this(Loc loc, Statement _init, Expression condition, Expression increment, Statement _body, Loc endloc)
        {
            super(loc);
            this._init = _init;
            this.condition = condition;
            this.increment = increment;
            this._body = _body;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DoStatement : Statement
    {
        Statement _body;
        Expression condition;
        Loc endloc;

        extern (D) this(Loc loc, Statement b, Expression c, Loc endloc)
        {
            super(loc);
            _body = b;
            condition = c;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ForeachRangeStatement : Statement
    {
        TOK op;                 // TOKforeach or TOKforeach_reverse
        Parameter prm;          // loop index variable
        Expression lwr;
        Expression upr;
        Statement _body;
        Loc endloc;             // location of closing curly bracket


        extern (D) this(Loc loc, TOK op, Parameter prm, Expression lwr, Expression upr, Statement _body, Loc endloc)
        {
            super(loc);
            this.op = op;
            this.prm = prm;
            this.lwr = lwr;
            this.upr = upr;
            this._body = _body;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ForeachStatement : Statement
    {
        TOK op;                     // TOKforeach or TOKforeach_reverse
        Parameters* parameters;     // array of Parameter*'s
        Expression aggr;
        Statement _body;
        Loc endloc;                 // location of closing curly bracket

        extern (D) this(Loc loc, TOK op, Parameters* parameters, Expression aggr, Statement _body, Loc endloc)
        {
            super(loc);
            this.op = op;
            this.parameters = parameters;
            this.aggr = aggr;
            this._body = _body;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class IfStatement : Statement
    {
        Parameter prm;
        Expression condition;
        Statement ifbody;
        Statement elsebody;
        VarDeclaration match;   // for MatchExpression results
        Loc endloc;                 // location of closing curly bracket

        extern (D) this(Loc loc, Parameter prm, Expression condition, Statement ifbody, Statement elsebody, Loc endloc)
        {
            super(loc);
            this.prm = prm;
            this.condition = condition;
            this.ifbody = ifbody;
            this.elsebody = elsebody;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class OnScopeStatement : Statement
    {
        TOK tok;
        Statement statement;

        extern (D) this(Loc loc, TOK tok, Statement statement)
        {
            super(loc);
            this.tok = tok;
            this.statement = statement;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ConditionalStatement : Statement
    {
        Condition condition;
        Statement ifbody;
        Statement elsebody;

        extern (D) this(Loc loc, Condition condition, Statement ifbody, Statement elsebody)
        {
            super(loc);
            this.condition = condition;
            this.ifbody = ifbody;
            this.elsebody = elsebody;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StaticForeachStatement : Statement
    {
        StaticForeach sfe;

        extern (D) this(Loc loc, StaticForeach sfe)
        {
            super(loc);
            this.sfe = sfe;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PragmaStatement : Statement
    {
        Identifier ident;
        Expressions* args;      // array of Expression's
        Statement _body;

        extern (D) this(Loc loc, Identifier ident, Expressions* args, Statement _body)
        {
            super(loc);
            this.ident = ident;
            this.args = args;
            this._body = _body;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class SwitchStatement : Statement
    {
        Expression condition;
        Statement _body;
        bool isFinal;

        extern (D) this(Loc loc, Expression c, Statement b, bool isFinal)
        {
            super(loc);
            this.condition = c;
            this._body = b;
            this.isFinal = isFinal;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CaseRangeStatement : Statement
    {
        Expression first;
        Expression last;
        Statement statement;

        extern (D) this(Loc loc, Expression first, Expression last, Statement s)
        {
            super(loc);
            this.first = first;
            this.last = last;
            this.statement = s;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CaseStatement : Statement
    {
        Expression exp;
        Statement statement;

        extern (D) this(Loc loc, Expression exp, Statement s)
        {
            super(loc);
            this.exp = exp;
            this.statement = s;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DefaultStatement : Statement
    {
        Statement statement;

        extern (D) this(Loc loc, Statement s)
        {
            super(loc);
            this.statement = s;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class BreakStatement : Statement
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(loc);
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ContinueStatement : Statement
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(loc);
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class GotoDefaultStatement : Statement
    {
        extern (D) this(Loc loc)
        {
            super(loc);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class GotoCaseStatement : Statement
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class GotoStatement : Statement
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(loc);
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class SynchronizedStatement : Statement
    {
        Expression exp;
        Statement _body;

        extern (D) this(Loc loc, Expression exp, Statement _body)
        {
            super(loc);
            this.exp = exp;
            this._body = _body;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class WithStatement : Statement
    {
        Expression exp;
        Statement _body;
        Loc endloc;

        extern (D) this(Loc loc, Expression exp, Statement _body, Loc endloc)
        {
            super(loc);
            this.exp = exp;
            this._body = _body;
            this.endloc = endloc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TryCatchStatement : Statement
    {
        Statement _body;
        Catches* catches;

        extern (D) this(Loc loc, Statement _body, Catches* catches)
        {
            super(loc);
            this._body = _body;
            this.catches = catches;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TryFinallyStatement : Statement
    {
        Statement _body;
        Statement finalbody;

        extern (D) this(Loc loc, Statement _body, Statement finalbody)
        {
            super(loc);
            this._body = _body;
            this.finalbody = finalbody;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ThrowStatement : Statement
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AsmStatement : Statement
    {
        Token* tokens;

        extern (D) this(Loc loc, Token* tokens)
        {
            super(loc);
            this.tokens = tokens;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class ExpStatement : Statement
    {
        Expression exp;

        final extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
        }
        final extern (D) this(Loc loc, Dsymbol declaration)
        {
            super(loc);
            this.exp = new DeclarationExp(loc, declaration);
        }

        override final ExpStatement isExpStatement()
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class CompoundStatement : Statement
    {
        Statements* statements;

        final extern (D) this(Loc loc, Statements* statements)
        {
            super(loc);
            this.statements = statements;
        }
        final extern (D) this(Loc loc, Statement[] sts...)
        {
            super(loc);
            statements = new Statements();
            statements.reserve(sts.length);
            foreach (s; sts)
                statements.push(s);
        }

        override final inout(CompoundStatement) isCompoundStatement() inout nothrow pure
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CompoundDeclarationStatement : CompoundStatement
    {
        final extern (D) this(Loc loc, Statements* statements)
        {
            super(loc, statements);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CompoundAsmStatement : CompoundStatement
    {
        StorageClass stc;

        final extern (D) this(Loc loc, Statements* s, StorageClass stc)
        {
            super(loc, s);
            this.stc = stc;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class Catch : RootObject
    {
        Loc loc;
        Type type;
        Identifier ident;
        Statement handler;

        extern (D) this(Loc loc, Type t, Identifier id, Statement handler)
        {
            this.loc = loc;
            this.type = t;
            this.ident = id;
            this.handler = handler;
        }
    }

    extern (C++) __gshared int Tsize_t = Tuns32;
    extern (C++) __gshared int Tptrdiff_t = Tint32;

    extern (C++) abstract class Type : RootObject
    {
        TY ty;
        MOD mod;
        char* deco;

        extern (C++) static __gshared Type tvoid;
        extern (C++) static __gshared Type tint8;
        extern (C++) static __gshared Type tuns8;
        extern (C++) static __gshared Type tint16;
        extern (C++) static __gshared Type tuns16;
        extern (C++) static __gshared Type tint32;
        extern (C++) static __gshared Type tuns32;
        extern (C++) static __gshared Type tint64;
        extern (C++) static __gshared Type tuns64;
        extern (C++) static __gshared Type tint128;
        extern (C++) static __gshared Type tuns128;
        extern (C++) static __gshared Type tfloat32;
        extern (C++) static __gshared Type tfloat64;
        extern (C++) static __gshared Type tfloat80;
        extern (C++) static __gshared Type timaginary32;
        extern (C++) static __gshared Type timaginary64;
        extern (C++) static __gshared Type timaginary80;
        extern (C++) static __gshared Type tcomplex32;
        extern (C++) static __gshared Type tcomplex64;
        extern (C++) static __gshared Type tcomplex80;
        extern (C++) static __gshared Type tbool;
        extern (C++) static __gshared Type tchar;
        extern (C++) static __gshared Type twchar;
        extern (C++) static __gshared Type tdchar;

        extern (C++) static __gshared Type[TMAX] basic;

        extern (C++) static __gshared Type tshiftcnt;
        extern (C++) static __gshared Type tvoidptr;    // void*
        extern (C++) static __gshared Type tstring;     // immutable(char)[]
        extern (C++) static __gshared Type twstring;    // immutable(wchar)[]
        extern (C++) static __gshared Type tdstring;    // immutable(dchar)[]
        extern (C++) static __gshared Type tvalist;     // va_list alias
        extern (C++) static __gshared Type terror;      // for error recovery
        extern (C++) static __gshared Type tnull;       // for null type

        extern (C++) static __gshared Type tsize_t;     // matches size_t alias
        extern (C++) static __gshared Type tptrdiff_t;  // matches ptrdiff_t alias
        extern (C++) static __gshared Type thash_t;     // matches hash_t alias



        extern (C++) static __gshared ClassDeclaration dtypeinfo;
        extern (C++) static __gshared ClassDeclaration typeinfoclass;
        extern (C++) static __gshared ClassDeclaration typeinfointerface;
        extern (C++) static __gshared ClassDeclaration typeinfostruct;
        extern (C++) static __gshared ClassDeclaration typeinfopointer;
        extern (C++) static __gshared ClassDeclaration typeinfoarray;
        extern (C++) static __gshared ClassDeclaration typeinfostaticarray;
        extern (C++) static __gshared ClassDeclaration typeinfoassociativearray;
        extern (C++) static __gshared ClassDeclaration typeinfovector;
        extern (C++) static __gshared ClassDeclaration typeinfoenum;
        extern (C++) static __gshared ClassDeclaration typeinfofunction;
        extern (C++) static __gshared ClassDeclaration typeinfodelegate;
        extern (C++) static __gshared ClassDeclaration typeinfotypelist;
        extern (C++) static __gshared ClassDeclaration typeinfoconst;
        extern (C++) static __gshared ClassDeclaration typeinfoinvariant;
        extern (C++) static __gshared ClassDeclaration typeinfoshared;
        extern (C++) static __gshared ClassDeclaration typeinfowild;
        extern (C++) static __gshared StringTable stringtable;
        extern (C++) static __gshared ubyte[TMAX] sizeTy = ()
            {
                ubyte[TMAX] sizeTy = __traits(classInstanceSize, TypeBasic);
                sizeTy[Tsarray] = __traits(classInstanceSize, TypeSArray);
                sizeTy[Tarray] = __traits(classInstanceSize, TypeDArray);
                sizeTy[Taarray] = __traits(classInstanceSize, TypeAArray);
                sizeTy[Tpointer] = __traits(classInstanceSize, TypePointer);
                sizeTy[Treference] = __traits(classInstanceSize, TypeReference);
                sizeTy[Tfunction] = __traits(classInstanceSize, TypeFunction);
                sizeTy[Tdelegate] = __traits(classInstanceSize, TypeDelegate);
                sizeTy[Tident] = __traits(classInstanceSize, TypeIdentifier);
                sizeTy[Tinstance] = __traits(classInstanceSize, TypeInstance);
                sizeTy[Ttypeof] = __traits(classInstanceSize, TypeTypeof);
                sizeTy[Tenum] = __traits(classInstanceSize, TypeEnum);
                sizeTy[Tstruct] = __traits(classInstanceSize, TypeStruct);
                sizeTy[Tclass] = __traits(classInstanceSize, TypeClass);
                sizeTy[Ttuple] = __traits(classInstanceSize, TypeTuple);
                sizeTy[Tslice] = __traits(classInstanceSize, TypeSlice);
                sizeTy[Treturn] = __traits(classInstanceSize, TypeReturn);
                sizeTy[Terror] = __traits(classInstanceSize, TypeError);
                sizeTy[Tnull] = __traits(classInstanceSize, TypeNull);
                sizeTy[Tvector] = __traits(classInstanceSize, TypeVector);
                return sizeTy;
            }();

        Type cto;
        Type ito;
        Type sto;
        Type scto;
        Type wto;
        Type wcto;
        Type swto;
        Type swcto;

        Type pto;
        Type rto;
        Type arrayof;

        // These members are probably used in semnatic analysis
        //TypeInfoDeclaration vtinfo;
        //type* ctype;

        final extern (D) this(TY ty)
        {
            this.ty = ty;
        }

        override const(char)* toChars()
        {
            return "type";
        }

        static void _init()
        {
            stringtable._init(14000);

            // Set basic types
            static __gshared TY* basetab =
            [
                Tvoid,
                Tint8,
                Tuns8,
                Tint16,
                Tuns16,
                Tint32,
                Tuns32,
                Tint64,
                Tuns64,
                Tint128,
                Tuns128,
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
                Terror
            ];

            for (size_t i = 0; basetab[i] != Terror; i++)
            {
                Type t = new TypeBasic(basetab[i]);
                t = t.merge();
                basic[basetab[i]] = t;
            }
            basic[Terror] = new TypeError();

            tvoid = basic[Tvoid];
            tint8 = basic[Tint8];
            tuns8 = basic[Tuns8];
            tint16 = basic[Tint16];
            tuns16 = basic[Tuns16];
            tint32 = basic[Tint32];
            tuns32 = basic[Tuns32];
            tint64 = basic[Tint64];
            tuns64 = basic[Tuns64];
            tint128 = basic[Tint128];
            tuns128 = basic[Tuns128];
            tfloat32 = basic[Tfloat32];
            tfloat64 = basic[Tfloat64];
            tfloat80 = basic[Tfloat80];

            timaginary32 = basic[Timaginary32];
            timaginary64 = basic[Timaginary64];
            timaginary80 = basic[Timaginary80];

            tcomplex32 = basic[Tcomplex32];
            tcomplex64 = basic[Tcomplex64];
            tcomplex80 = basic[Tcomplex80];

            tbool = basic[Tbool];
            tchar = basic[Tchar];
            twchar = basic[Twchar];
            tdchar = basic[Tdchar];

            tshiftcnt = tint32;
            terror = basic[Terror];
            tnull = basic[Tnull];
            tnull = new TypeNull();
            tnull.deco = tnull.merge().deco;

            tvoidptr = tvoid.pointerTo();
            tstring = tchar.immutableOf().arrayOf();
            twstring = twchar.immutableOf().arrayOf();
            tdstring = tdchar.immutableOf().arrayOf();
            tvalist = Target.va_listType();

            if (global.params.isLP64)
            {
                Tsize_t = Tuns64;
                Tptrdiff_t = Tint64;
            }
            else
            {
                Tsize_t = Tuns32;
                Tptrdiff_t = Tint32;
            }

            tsize_t = basic[Tsize_t];
            tptrdiff_t = basic[Tptrdiff_t];
            thash_t = tsize_t;
        }

        final Type pointerTo()
        {
            if (ty == Terror)
                return this;
            if (!pto)
            {
                Type t = new TypePointer(this);
                if (ty == Tfunction)
                {
                    t.deco = t.merge().deco;
                    pto = t;
                }
                else
                    pto = t.merge();
            }
            return pto;
        }

        final Type arrayOf()
        {
            if (ty == Terror)
                return this;
            if (!arrayof)
            {
                Type t = new TypeDArray(this);
                arrayof = t.merge();
            }
            return arrayof;
        }

        final bool isImmutable() const
        {
            return (mod & MODimmutable) != 0;
        }

        final Type nullAttributes()
        {
            uint sz = sizeTy[ty];
            Type t = cast(Type)mem.xmalloc(sz);
            memcpy(cast(void*)t, cast(void*)this, sz);
            // t.mod = NULL;  // leave mod unchanged
            t.deco = null;
            t.arrayof = null;
            t.pto = null;
            t.rto = null;
            t.cto = null;
            t.ito = null;
            t.sto = null;
            t.scto = null;
            t.wto = null;
            t.wcto = null;
            t.swto = null;
            t.swcto = null;
            //t.vtinfo = null; these aren't used in parsing
            //t.ctype = null;
            if (t.ty == Tstruct)
                (cast(TypeStruct)t).att = RECfwdref;
            if (t.ty == Tclass)
                (cast(TypeClass)t).att = RECfwdref;
            return t;
        }

        Type makeConst()
        {
            if (cto)
                return cto;
            Type t = this.nullAttributes();
            t.mod = MODconst;
            return t;
        }

        Type makeWildConst()
        {
            if (wcto)
                return wcto;
            Type t = this.nullAttributes();
            t.mod = MODwildconst;
            return t;
        }

        Type makeShared()
        {
            if (sto)
                return sto;
            Type t = this.nullAttributes();
            t.mod = MODshared;
            return t;
        }

        Type makeSharedConst()
        {
            if (scto)
                return scto;
            Type t = this.nullAttributes();
            t.mod = MODshared | MODconst;
            return t;
        }

        Type makeImmutable()
        {
            if (ito)
                return ito;
            Type t = this.nullAttributes();
            t.mod = MODimmutable;
            return t;
        }

        Type makeWild()
        {
            if (wto)
                return wto;
            Type t = this.nullAttributes();
            t.mod = MODwild;
            return t;
        }

        Type makeSharedWildConst()
        {
            if (swcto)
                return swcto;
            Type t = this.nullAttributes();
            t.mod = MODshared | MODwildconst;
            return t;
        }

        Type makeSharedWild()
        {
            if (swto)
                return swto;
            Type t = this.nullAttributes();
            t.mod = MODshared | MODwild;
            return t;
        }

        // Truncated
        final Type merge()
        {
            if (ty == Terror)
                return this;
            if (ty == Ttypeof)
                return this;
            if (ty == Tident)
                return this;
            if (ty == Tinstance)
                return this;
            if (ty == Taarray && !(cast(TypeAArray)this).index.merge().deco)
                return this;
            if (ty != Tenum && nextOf() && !nextOf().deco)
                return this;

            // if (!deco) - code missing

            Type t = this;
            assert(t);
            return t;
        }

        final Type addSTC(StorageClass stc)
        {
            Type t = this;
            if (t.isImmutable())
            {
            }
            else if (stc & STCimmutable)
            {
                t = t.makeImmutable();
            }
            else
            {
                if ((stc & STCshared) && !t.isShared())
                {
                    if (t.isWild())
                    {
                        if (t.isConst())
                            t = t.makeSharedWildConst();
                        else
                            t = t.makeSharedWild();
                    }
                    else
                    {
                        if (t.isConst())
                            t = t.makeSharedConst();
                        else
                            t = t.makeShared();
                    }
                }
                if ((stc & STCconst) && !t.isConst())
                {
                    if (t.isShared())
                    {
                        if (t.isWild())
                            t = t.makeSharedWildConst();
                        else
                            t = t.makeSharedConst();
                    }
                    else
                    {
                        if (t.isWild())
                            t = t.makeWildConst();
                        else
                            t = t.makeConst();
                    }
                }
                if ((stc & STCwild) && !t.isWild())
                {
                    if (t.isShared())
                    {
                        if (t.isConst())
                            t = t.makeSharedWildConst();
                        else
                            t = t.makeSharedWild();
                    }
                    else
                    {
                        if (t.isConst())
                            t = t.makeWildConst();
                        else
                            t = t.makeWild();
                    }
                }
            }
            return t;
        }

        Expression toExpression()
        {
            return null;
        }

        Type syntaxCopy()
        {
            return null;
        }

        final Type sharedWildConstOf()
        {
            if (mod == (MODshared | MODwildconst))
                return this;
            if (swcto)
            {
                assert(swcto.mod == (MODshared | MODwildconst));
                return swcto;
            }
            Type t = makeSharedWildConst();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final Type sharedConstOf()
        {
            if (mod == (MODshared | MODconst))
                return this;
            if (scto)
            {
                assert(scto.mod == (MODshared | MODconst));
                return scto;
            }
            Type t = makeSharedConst();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final Type wildConstOf()
        {
            if (mod == MODwildconst)
                return this;
            if (wcto)
            {
                assert(wcto.mod == MODwildconst);
                return wcto;
            }
            Type t = makeWildConst();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final Type constOf()
        {
            if (mod == MODconst)
                return this;
            if (cto)
            {
                assert(cto.mod == MODconst);
                return cto;
            }
            Type t = makeConst();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final Type sharedWildOf()
        {
            if (mod == (MODshared | MODwild))
                return this;
            if (swto)
            {
                assert(swto.mod == (MODshared | MODwild));
                return swto;
            }
            Type t = makeSharedWild();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final Type wildOf()
        {
            if (mod == MODwild)
                return this;
            if (wto)
            {
                assert(wto.mod == MODwild);
                return wto;
            }
            Type t = makeWild();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final Type sharedOf()
        {
            if (mod == MODshared)
                return this;
            if (sto)
            {
                assert(sto.mod == MODshared);
                return sto;
            }
            Type t = makeShared();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final Type immutableOf()
        {
            if (isImmutable())
                return this;
            if (ito)
            {
                assert(ito.isImmutable());
                return ito;
            }
            Type t = makeImmutable();
            t = t.merge();
            t.fixTo(this);
            return t;
        }

        final void fixTo(Type t)
        {
            Type mto = null;
            Type tn = nextOf();
            if (!tn || ty != Tsarray && tn.mod == t.nextOf().mod)
            {
                switch (t.mod)
                {
                case 0:
                    mto = t;
                    break;

                case MODconst:
                    cto = t;
                    break;

                case MODwild:
                    wto = t;
                    break;

                case MODwildconst:
                    wcto = t;
                    break;

                case MODshared:
                    sto = t;
                    break;

                case MODshared | MODconst:
                    scto = t;
                    break;

                case MODshared | MODwild:
                    swto = t;
                    break;

                case MODshared | MODwildconst:
                    swcto = t;
                    break;

                case MODimmutable:
                    ito = t;
                    break;

                default:
                    break;
                }
            }
            assert(mod != t.mod);

            auto X(T, U)(T m, U n)
            {
                return ((m << 4) | n);
            }

            switch (mod)
            {
            case 0:
                break;

            case MODconst:
                cto = mto;
                t.cto = this;
                break;

            case MODwild:
                wto = mto;
                t.wto = this;
                break;

            case MODwildconst:
                wcto = mto;
                t.wcto = this;
                break;

            case MODshared:
                sto = mto;
                t.sto = this;
                break;

            case MODshared | MODconst:
                scto = mto;
                t.scto = this;
                break;

            case MODshared | MODwild:
                swto = mto;
                t.swto = this;
                break;

            case MODshared | MODwildconst:
                swcto = mto;
                t.swcto = this;
                break;

            case MODimmutable:
                t.ito = this;
                if (t.cto)
                    t.cto.ito = this;
                if (t.sto)
                    t.sto.ito = this;
                if (t.scto)
                    t.scto.ito = this;
                if (t.wto)
                    t.wto.ito = this;
                if (t.wcto)
                    t.wcto.ito = this;
                if (t.swto)
                    t.swto.ito = this;
                if (t.swcto)
                    t.swcto.ito = this;
                break;

            default:
                assert(0);
            }
        }

        final Type addMod(MOD mod)
        {
            Type t = this;
            if (!t.isImmutable())
            {
                switch (mod)
                {
                case 0:
                    break;

                case MODconst:
                    if (isShared())
                    {
                        if (isWild())
                            t = sharedWildConstOf();
                        else
                            t = sharedConstOf();
                    }
                    else
                    {
                        if (isWild())
                            t = wildConstOf();
                        else
                            t = constOf();
                    }
                    break;

                case MODwild:
                    if (isShared())
                    {
                        if (isConst())
                            t = sharedWildConstOf();
                        else
                            t = sharedWildOf();
                    }
                    else
                    {
                        if (isConst())
                            t = wildConstOf();
                        else
                            t = wildOf();
                    }
                    break;

                case MODwildconst:
                    if (isShared())
                        t = sharedWildConstOf();
                    else
                        t = wildConstOf();
                    break;

                case MODshared:
                    if (isWild())
                    {
                        if (isConst())
                            t = sharedWildConstOf();
                        else
                            t = sharedWildOf();
                    }
                    else
                    {
                        if (isConst())
                            t = sharedConstOf();
                        else
                            t = sharedOf();
                    }
                    break;

                case MODshared | MODconst:
                    if (isWild())
                        t = sharedWildConstOf();
                    else
                        t = sharedConstOf();
                    break;

                case MODshared | MODwild:
                    if (isConst())
                        t = sharedWildConstOf();
                    else
                        t = sharedWildOf();
                    break;

                case MODshared | MODwildconst:
                    t = sharedWildConstOf();
                    break;

                case MODimmutable:
                    t = immutableOf();
                    break;

                default:
                    assert(0);
                }
            }
            return t;
        }

        // TypeEnum overrides this method
        Type nextOf()
        {
            return null;
        }

        // TypeBasic, TypeVector, TypePointer, TypeEnum override this method
        bool isscalar()
        {
            return false;
        }

        final bool isConst() const
        {
            return (mod & MODconst) != 0;
        }

        final bool isWild() const
        {
            return (mod & MODwild) != 0;
        }

        final bool isShared() const
        {
            return (mod & MODshared) != 0;
        }

        Type toBasetype()
        {
            return this;
        }

        // TypeIdentifier, TypeInstance, TypeTypeOf, TypeReturn, TypeStruct, TypeEnum, TypeClass override this method
        Dsymbol toDsymbol(Scope* sc)
        {
            return null;
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    // missing functionality in constructor, but that's ok
    // since the class is needed only for its size; need to add all method definitions
    extern (C++) final class TypeBasic : Type
    {
        const(char)* dstring;
        uint flags;

        extern (D) this(TY ty)
        {
            super(ty);
            const(char)* d;
            uint flags = 0;
            switch (ty)
            {
            case Tvoid:
                d = Token.toChars(TOKvoid);
                break;

            case Tint8:
                d = Token.toChars(TOKint8);
                flags |= TFLAGSintegral;
                break;

            case Tuns8:
                d = Token.toChars(TOKuns8);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Tint16:
                d = Token.toChars(TOKint16);
                flags |= TFLAGSintegral;
                break;

            case Tuns16:
                d = Token.toChars(TOKuns16);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Tint32:
                d = Token.toChars(TOKint32);
                flags |= TFLAGSintegral;
                break;

            case Tuns32:
                d = Token.toChars(TOKuns32);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Tfloat32:
                d = Token.toChars(TOKfloat32);
                flags |= TFLAGSfloating | TFLAGSreal;
                break;

            case Tint64:
                d = Token.toChars(TOKint64);
                flags |= TFLAGSintegral;
                break;

            case Tuns64:
                d = Token.toChars(TOKuns64);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Tint128:
                d = Token.toChars(TOKint128);
                flags |= TFLAGSintegral;
                break;

            case Tuns128:
                d = Token.toChars(TOKuns128);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Tfloat64:
                d = Token.toChars(TOKfloat64);
                flags |= TFLAGSfloating | TFLAGSreal;
                break;

            case Tfloat80:
                d = Token.toChars(TOKfloat80);
                flags |= TFLAGSfloating | TFLAGSreal;
                break;

            case Timaginary32:
                d = Token.toChars(TOKimaginary32);
                flags |= TFLAGSfloating | TFLAGSimaginary;
                break;

            case Timaginary64:
                d = Token.toChars(TOKimaginary64);
                flags |= TFLAGSfloating | TFLAGSimaginary;
                break;

            case Timaginary80:
                d = Token.toChars(TOKimaginary80);
                flags |= TFLAGSfloating | TFLAGSimaginary;
                break;

            case Tcomplex32:
                d = Token.toChars(TOKcomplex32);
                flags |= TFLAGSfloating | TFLAGScomplex;
                break;

            case Tcomplex64:
                d = Token.toChars(TOKcomplex64);
                flags |= TFLAGSfloating | TFLAGScomplex;
                break;

            case Tcomplex80:
                d = Token.toChars(TOKcomplex80);
                flags |= TFLAGSfloating | TFLAGScomplex;
                break;

            case Tbool:
                d = "bool";
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Tchar:
                d = Token.toChars(TOKchar);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Twchar:
                d = Token.toChars(TOKwchar);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            case Tdchar:
                d = Token.toChars(TOKdchar);
                flags |= TFLAGSintegral | TFLAGSunsigned;
                break;

            default:
                assert(0);
            }
            this.dstring = d;
            this.flags = flags;
            merge();
        }

        override bool isscalar() const
        {
            return (flags & (TFLAGSintegral | TFLAGSfloating)) != 0;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeError : Type
    {
        extern (D) this()
        {
            super(Terror);
        }

        override Type syntaxCopy()
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeNull : Type
    {
        extern (D) this()
        {
            super(Tnull);
        }

        override Type syntaxCopy()
        {
            // No semantic analysis done, no need to copy
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TypeVector : Type
    {
        Type basetype;

        extern (D) this(Loc loc, Type baseType)
        {
            super(Tvector);
            this.basetype = basetype;
        }

        override Type syntaxCopy()
        {
            return new TypeVector(Loc(), basetype.syntaxCopy());
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeEnum : Type
    {
        EnumDeclaration sym;

        extern (D) this(EnumDeclaration sym)
        {
            super(Tenum);
            this.sym = sym;
        }

        override Type syntaxCopy()
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeTuple : Type
    {
        Parameters* arguments;

        extern (D) this(Parameters* arguments)
        {
            super(Ttuple);
            this.arguments = arguments;
        }

        extern (D) this(Expressions* exps)
        {
            super(Ttuple);
            auto arguments = new Parameters();
            if (exps)
            {
                arguments.setDim(exps.dim);
                for (size_t i = 0; i < exps.dim; i++)
                {
                    Expression e = (*exps)[i];
                    if (e.type.ty == Ttuple)
                        e.error("cannot form tuple of tuples");
                    auto arg = new Parameter(STCundefined, e.type, null, null);
                    (*arguments)[i] = arg;
                }
            }
            this.arguments = arguments;
        }

        override Type syntaxCopy()
        {
            Parameters* args = Parameter.arraySyntaxCopy(arguments);
            Type t = new TypeTuple(args);
            t.mod = mod;
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeClass : Type
    {
        ClassDeclaration sym;
        AliasThisRec att = RECfwdref;

        extern (D) this (ClassDeclaration sym)
        {
            super(Tclass);
            this.sym = sym;
        }

        override Type syntaxCopy()
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeStruct : Type
    {
        StructDeclaration sym;
        AliasThisRec att = RECfwdref;

        extern (D) this(StructDeclaration sym)
        {
            super(Tstruct);
            this.sym = sym;
        }

        override Type syntaxCopy()
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeReference : TypeNext
    {
        extern (D) this(Type t)
        {
            super(Treference, t);
            // BUG: what about references to static arrays?
        }

        override Type syntaxCopy()
        {
            Type t = next.syntaxCopy();
            if (t == next)
                t = this;
            else
            {
                t = new TypeReference(t);
                t.mod = mod;
            }
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class TypeNext : Type
    {
        Type next;

        final extern (D) this(TY ty, Type next)
        {
            super(ty);
            this.next = next;
        }

        override final Type nextOf()
        {
            return next;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeSlice : TypeNext
    {
        Expression lwr;
        Expression upr;

        extern (D) this(Type next, Expression lwr, Expression upr)
        {
            super(Tslice, next);
            this.lwr = lwr;
            this.upr = upr;
        }

        override Type syntaxCopy()
        {
            Type t = new TypeSlice(next.syntaxCopy(), lwr.syntaxCopy(), upr.syntaxCopy());
            t.mod = mod;
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TypeDelegate : TypeNext
    {
        extern (D) this(Type t)
        {
            super(Tfunction, t);
            ty = Tdelegate;
        }

        override Type syntaxCopy()
        {
            Type t = next.syntaxCopy();
            if (t == next)
                t = this;
            else
            {
                t = new TypeDelegate(t);
                t.mod = mod;
            }
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypePointer : TypeNext
    {
        extern (D) this(Type t)
        {
            super(Tpointer, t);
        }

        override Type syntaxCopy()
        {
            Type t = next.syntaxCopy();
            if (t == next)
                t = this;
            else
            {
                t = new TypePointer(t);
                t.mod = mod;
            }
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TypeFunction : TypeNext
    {
        Parameters* parameters;     // function parameters
        int varargs;                // 1: T t, ...) style for variable number of arguments
                                    // 2: T t ...) style for variable number of arguments
        bool isnothrow;             // true: nothrow
        bool isnogc;                // true: is @nogc
        bool isproperty;            // can be called without parentheses
        bool isref;                 // true: returns a reference
        bool isreturn;              // true: 'this' is returned by ref
        bool isscope;               // true: 'this' is scope
        LINK linkage;               // calling convention
        TRUST trust;                // level of trust
        PURE purity = PUREimpure;

        ubyte iswild;
        Expressions* fargs;

        extern (D) this(Parameters* parameters, Type treturn, int varargs, LINK linkage, StorageClass stc = 0)
        {
            super(Tfunction, treturn);
            assert(0 <= varargs && varargs <= 2);
            this.parameters = parameters;
            this.varargs = varargs;
            this.linkage = linkage;

            if (stc & STCpure)
                this.purity = PUREfwdref;
            if (stc & STCnothrow)
                this.isnothrow = true;
            if (stc & STCnogc)
                this.isnogc = true;
            if (stc & STCproperty)
                this.isproperty = true;

            if (stc & STCref)
                this.isref = true;
            if (stc & STCreturn)
                this.isreturn = true;
            if (stc & STCscope)
                this.isscope = true;

            this.trust = TRUSTdefault;
            if (stc & STCsafe)
                this.trust = TRUSTsafe;
            if (stc & STCsystem)
                this.trust = TRUSTsystem;
            if (stc & STCtrusted)
                this.trust = TRUSTtrusted;
        }

        override Type syntaxCopy()
        {
            Type treturn = next ? next.syntaxCopy() : null;
            Parameters* params = Parameter.arraySyntaxCopy(parameters);
            auto t = new TypeFunction(params, treturn, varargs, linkage);
            t.mod = mod;
            t.isnothrow = isnothrow;
            t.isnogc = isnogc;
            t.purity = purity;
            t.isproperty = isproperty;
            t.isref = isref;
            t.isreturn = isreturn;
            t.isscope = isscope;
            t.iswild = iswild;
            t.trust = trust;
            t.fargs = fargs;
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TypeArray : TypeNext
    {
        final extern (D) this(TY ty, Type next)
        {
            super(ty, next);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeDArray : TypeArray
    {
        extern (D) this(Type t)
        {
            super(Tarray, t);
        }

        override Type syntaxCopy()
        {
            Type t = next.syntaxCopy();
            if (t == next)
                t = this;
            else
            {
                t = new TypeDArray(t);
                t.mod = mod;
            }
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeAArray : TypeArray
    {
        Type index;
        Loc loc;

        extern (D) this(Type t, Type index)
        {
            super(Taarray, t);
            this.index = index;
        }

        override Type syntaxCopy()
        {
            Type t = next.syntaxCopy();
            Type ti = index.syntaxCopy();
            if (t == next && ti == index)
                t = this;
            else
            {
                t = new TypeAArray(t, ti);
                t.mod = mod;
            }
            return t;
        }

        override Expression toExpression()
        {
            Expression e = next.toExpression();
            if (e)
            {
                Expression ei = index.toExpression();
                if (ei)
                    return new ArrayExp(loc, e, ei);
            }
            return null;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeSArray : TypeArray
    {
        Expression dim;

        final extern (D) this(Type t, Expression dim)
        {
            super(Tsarray, t);
            this.dim = dim;
        }

        override Type syntaxCopy()
        {
            Type t = next.syntaxCopy();
            Expression e = dim.syntaxCopy();
            t = new TypeSArray(t, e);
            t.mod = mod;
            return t;
        }

        override Expression toExpression()
        {
            Expression e = next.toExpression();
            if (e)
                e = new ArrayExp(dim.loc, e, dim);
            return e;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class TypeQualified : Type
    {
        Objects idents;
        Loc loc;

        final extern (D) this(TY ty, Loc loc)
        {
            super(ty);
            this.loc = loc;
        }

        final void addIdent(Identifier id)
        {
            idents.push(id);
        }

        final void addInst(TemplateInstance ti)
        {
            idents.push(ti);
        }

        final void addIndex(RootObject e)
        {
            idents.push(e);
        }

        final void syntaxCopyHelper(TypeQualified t)
        {
            idents.setDim(t.idents.dim);
            for (size_t i = 0; i < idents.dim; i++)
            {
                RootObject id = t.idents[i];
                if (id.dyncast() == DYNCAST.dsymbol)
                {
                    TemplateInstance ti = cast(TemplateInstance)id;
                    ti = cast(TemplateInstance)ti.syntaxCopy(null);
                    id = ti;
                }
                else if (id.dyncast() == DYNCAST.expression)
                {
                    Expression e = cast(Expression)id;
                    e = e.syntaxCopy();
                    id = e;
                }
                else if (id.dyncast() == DYNCAST.type)
                {
                    Type tx = cast(Type)id;
                    tx = tx.syntaxCopy();
                    id = tx;
                }
                idents[i] = id;
            }
        }

        final Expression toExpressionHelper(Expression e, size_t i = 0)
        {
            for (; i < idents.dim; i++)
            {
                RootObject id = idents[i];

                switch (id.dyncast())
                {
                    case DYNCAST.identifier:
                        e = new DotIdExp(e.loc, e, cast(Identifier)id);
                        break;

                    case DYNCAST.dsymbol:
                        auto ti = (cast(Dsymbol)id).isTemplateInstance();
                        assert(ti);
                        e = new DotTemplateInstanceExp(e.loc, e, ti.name, ti.tiargs);
                        break;

                    case DYNCAST.type:          // Bugzilla 1215
                        e = new ArrayExp(loc, e, new TypeExp(loc, cast(Type)id));
                        break;

                    case DYNCAST.expression:    // Bugzilla 1215
                        e = new ArrayExp(loc, e, cast(Expression)id);
                        break;

                    default:
                        assert(0);
                }
            }
            return e;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeIdentifier : TypeQualified
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(Tident, loc);
            this.ident = ident;
        }

        override Type syntaxCopy()
        {
            auto t = new TypeIdentifier(loc, ident);
            t.syntaxCopyHelper(this);
            t.mod = mod;
            return t;
        }

        override Expression toExpression()
        {
            return toExpressionHelper(new IdentifierExp(loc, ident));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeReturn : TypeQualified
    {
        extern (D) this(Loc loc)
        {
            super(Treturn, loc);
        }

        override Type syntaxCopy()
        {
            auto t = new TypeReturn(loc);
            t.syntaxCopyHelper(this);
            t.mod = mod;
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeTypeof : TypeQualified
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(Ttypeof, loc);
            this.exp = exp;
        }

        override Type syntaxCopy()
        {
            auto t = new TypeTypeof(loc, exp.syntaxCopy());
            t.syntaxCopyHelper(this);
            t.mod = mod;
            return t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeInstance : TypeQualified
    {
        TemplateInstance tempinst;

        final extern (D) this(Loc loc, TemplateInstance tempinst)
        {
            super(Tinstance, loc);
            this.tempinst = tempinst;
        }

        override Type syntaxCopy()
        {
            auto t = new TypeInstance(loc, cast(TemplateInstance)tempinst.syntaxCopy(null));
            t.syntaxCopyHelper(this);
            t.mod = mod;
            return t;
        }

        override Expression toExpression()
        {
            return toExpressionHelper(new ScopeExp(loc, tempinst));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class Expression : RootObject
    {
        TOK op;
        Loc loc;
        Type type;
        ubyte parens;
        ubyte size;

        final extern (D) this(Loc loc, TOK op, int size)
        {
            this.loc = loc;
            this.op = op;
            this.size = cast(ubyte)size;
        }

        Expression syntaxCopy()
        {
            return copy();
        }

        final void error(const(char)* format, ...) const
        {
            if (type != Type.terror)
            {
                va_list ap;
                va_start(ap, format);
                verror(loc, format, ap);
                va_end(ap);
            }
        }

        final Expression copy()
        {
            Expression e;
            if (!size)
            {
                assert(0);
            }
            e = cast(Expression)mem.xmalloc(size);
            return cast(Expression)memcpy(cast(void*)e, cast(void*)this, size);
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DeclarationExp : Expression
    {
        Dsymbol declaration;

        extern (D) this(Loc loc, Dsymbol declaration)
        {
            super(loc, TOKdeclaration, __traits(classInstanceSize, DeclarationExp));
            this.declaration = declaration;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class IntegerExp : Expression
    {
        dinteger_t value;

        extern (D) this(Loc loc, dinteger_t value, Type type)
        {
            super(loc, TOKint64, __traits(classInstanceSize, IntegerExp));
            assert(type);
            if (!type.isscalar())
            {
                if (type.ty != Terror)
                    error("integral constant must be scalar type, not %s", type.toChars());
                type = Type.terror;
            }
            this.type = type;
            setInteger(value);
        }

        void setInteger(dinteger_t value)
        {
            this.value = value;
            normalize();
        }

        void normalize()
        {
            /* 'Normalize' the value of the integer to be in range of the type
             */
            switch (type.toBasetype().ty)
            {
            case Tbool:
                value = (value != 0);
                break;

            case Tint8:
                value = cast(d_int8)value;
                break;

            case Tchar:
            case Tuns8:
                value = cast(d_uns8)value;
                break;

            case Tint16:
                value = cast(d_int16)value;
                break;

            case Twchar:
            case Tuns16:
                value = cast(d_uns16)value;
                break;

            case Tint32:
                value = cast(d_int32)value;
                break;

            case Tdchar:
            case Tuns32:
                value = cast(d_uns32)value;
                break;

            case Tint64:
                value = cast(d_int64)value;
                break;

            case Tuns64:
                value = cast(d_uns64)value;
                break;

            case Tpointer:
                if (Target.ptrsize == 4)
                    value = cast(d_uns32)value;
                else if (Target.ptrsize == 8)
                    value = cast(d_uns64)value;
                else
                    assert(0);
                break;

            default:
                break;
            }
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class NewAnonClassExp : Expression
    {
        Expression thisexp;     // if !=null, 'this' for class being allocated
        Expressions* newargs;   // Array of Expression's to call new operator
        ClassDeclaration cd;    // class being instantiated
        Expressions* arguments; // Array of Expression's to call class constructor

        extern (D) this(Loc loc, Expression thisexp, Expressions* newargs, ClassDeclaration cd, Expressions* arguments)
        {
            super(loc, TOKnewanonclass, __traits(classInstanceSize, NewAnonClassExp));
            this.thisexp = thisexp;
            this.newargs = newargs;
            this.cd = cd;
            this.arguments = arguments;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class IsExp : Expression
    {
        Type targ;
        Identifier id;      // can be null
        TOK tok;            // ':' or '=='
        Type tspec;         // can be null
        TOK tok2;           // 'struct', 'union', etc.
        TemplateParameters* parameters;

        extern (D) this(Loc loc, Type targ, Identifier id, TOK tok, Type tspec, TOK tok2, TemplateParameters* parameters)
        {
            super(loc, TOKis, __traits(classInstanceSize, IsExp));
            this.targ = targ;
            this.id = id;
            this.tok = tok;
            this.tspec = tspec;
            this.tok2 = tok2;
            this.parameters = parameters;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class RealExp : Expression
    {
        real_t value;

        extern (D) this(Loc loc, real_t value, Type type)
        {
            super(loc, TOKfloat64, __traits(classInstanceSize, RealExp));
            this.value = value;
            this.type = type;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class NullExp : Expression
    {
        extern (D) this(Loc loc, Type type = null)
        {
            super(loc, TOKnull, __traits(classInstanceSize, NullExp));
            this.type = type;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeidExp : Expression
    {
        RootObject obj;

        extern (D) this(Loc loc, RootObject o)
        {
            super(loc, TOKtypeid, __traits(classInstanceSize, TypeidExp));
            this.obj = o;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TraitsExp : Expression
    {
        Identifier ident;
        Objects* args;

        extern (D) this(Loc loc, Identifier ident, Objects* args)
        {
            super(loc, TOKtraits, __traits(classInstanceSize, TraitsExp));
            this.ident = ident;
            this.args = args;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StringExp : Expression
    {
        union
        {
            char* string;   // if sz == 1
            wchar* wstring; // if sz == 2
            dchar* dstring; // if sz == 4
        }                   // (const if ownedByCtfe == OWNEDcode)
        size_t len;         // number of code units
        ubyte sz = 1;       // 1: char, 2: wchar, 4: dchar
        char postfix = 0;   // 'c', 'w', 'd'

        extern (D) this(Loc loc, char* string)
        {
            super(loc, TOKstring, __traits(classInstanceSize, StringExp));
            this.string = string;
            this.len = strlen(string);
            this.sz = 1;                    // work around LDC bug #1286
        }

        extern (D) this(Loc loc, void* string, size_t len)
        {
            super(loc, TOKstring, __traits(classInstanceSize, StringExp));
            this.string = cast(char*)string;
            this.len = len;
            this.sz = 1;                    // work around LDC bug #1286
        }

        extern (D) this(Loc loc, void* string, size_t len, char postfix)
        {
            super(loc, TOKstring, __traits(classInstanceSize, StringExp));
            this.string = cast(char*)string;
            this.len = len;
            this.postfix = postfix;
            this.sz = 1;                    // work around LDC bug #1286
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class NewExp : Expression
    {
        Expression thisexp;         // if !=null, 'this' for class being allocated
        Expressions* newargs;       // Array of Expression's to call new operator
        Type newtype;
        Expressions* arguments;     // Array of Expression's

        extern (D) this(Loc loc, Expression thisexp, Expressions* newargs, Type newtype, Expressions* arguments)
        {
            super(loc, TOKnew, __traits(classInstanceSize, NewExp));
            this.thisexp = thisexp;
            this.newargs = newargs;
            this.newtype = newtype;
            this.arguments = arguments;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AssocArrayLiteralExp : Expression
    {
        Expressions* keys;
        Expressions* values;

        extern (D) this(Loc loc, Expressions* keys, Expressions* values)
        {
            super(loc, TOKassocarrayliteral, __traits(classInstanceSize, AssocArrayLiteralExp));
            assert(keys.dim == values.dim);
            this.keys = keys;
            this.values = values;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ArrayLiteralExp : Expression
    {
        Expression basis;
        Expressions* elements;

        extern (D) this(Loc loc, Expressions* elements)
        {
            super(loc, TOKarrayliteral, __traits(classInstanceSize, ArrayLiteralExp));
            this.elements = elements;
        }

        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKarrayliteral, __traits(classInstanceSize, ArrayLiteralExp));
            elements = new Expressions();
            elements.push(e);
        }

        extern (D) this(Loc loc, Expression basis, Expressions* elements)
        {
            super(loc, TOKarrayliteral, __traits(classInstanceSize, ArrayLiteralExp));
            this.basis = basis;
            this.elements = elements;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class FuncExp : Expression
    {
        FuncLiteralDeclaration fd;
        TemplateDeclaration td;
        TOK tok;

        extern (D) this(Loc loc, Dsymbol s)
        {
            super(loc, TOKfunction, __traits(classInstanceSize, FuncExp));
            this.td = s.isTemplateDeclaration();
            this.fd = s.isFuncLiteralDeclaration();
            if (td)
            {
                assert(td.literal);
                assert(td.members && td.members.dim == 1);
                fd = (*td.members)[0].isFuncLiteralDeclaration();
            }
            tok = fd.tok; // save original kind of function/delegate/(infer)
            assert(fd.fbody);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class IntervalExp : Expression
    {
        Expression lwr;
        Expression upr;

        extern (D) this(Loc loc, Expression lwr, Expression upr)
        {
            super(loc, TOKinterval, __traits(classInstanceSize, IntervalExp));
            this.lwr = lwr;
            this.upr = upr;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TypeExp : Expression
    {
        extern (D) this(Loc loc, Type type)
        {
            super(loc, TOKtype, __traits(classInstanceSize, TypeExp));
            this.type = type;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ScopeExp : Expression
    {
        ScopeDsymbol sds;

        extern (D) this(Loc loc, ScopeDsymbol sds)
        {
            super(loc, TOKscope, __traits(classInstanceSize, ScopeExp));
            this.sds = sds;
            assert(!sds.isTemplateDeclaration());
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class IdentifierExp : Expression
    {
        Identifier ident;

        final extern (D) this(Loc loc, Identifier ident)
        {
            super(loc, TOKidentifier, __traits(classInstanceSize, IdentifierExp));
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class UnaExp : Expression
    {
        Expression e1;

        final extern (D) this(Loc loc, TOK op, int size, Expression e1)
        {
            super(loc, op, size);
            this.e1 = e1;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class DefaultInitExp : Expression
    {
        TOK subop;      // which of the derived classes this is

        final extern (D) this(Loc loc, TOK subop, int size)
        {
            super(loc, TOKdefault, size);
            this.subop = subop;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class BinExp : Expression
    {
        Expression e1;
        Expression e2;

        final extern (D) this(Loc loc, TOK op, int size, Expression e1, Expression e2)
        {
            super(loc, op, size);
            this.e1 = e1;
            this.e2 = e2;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DsymbolExp : Expression
    {
        Dsymbol s;
        bool hasOverloads;

        extern (D) this(Loc loc, Dsymbol s, bool hasOverloads = true)
        {
            super(loc, TOKdsymbol, __traits(classInstanceSize, DsymbolExp));
            this.s = s;
            this.hasOverloads = hasOverloads;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TemplateExp : Expression
    {
        TemplateDeclaration td;
        FuncDeclaration fd;

        extern (D) this(Loc loc, TemplateDeclaration td, FuncDeclaration fd = null)
        {
            super(loc, TOKtemplate, __traits(classInstanceSize, TemplateExp));
            //printf("TemplateExp(): %s\n", td.toChars());
            this.td = td;
            this.fd = fd;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class SymbolExp : Expression
    {
        Declaration var;
        bool hasOverloads;

        final extern (D) this(Loc loc, TOK op, int size, Declaration var, bool hasOverloads)
        {
            super(loc, op, size);
            assert(var);
            this.var = var;
            this.hasOverloads = hasOverloads;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class VarExp : SymbolExp
    {
        extern (D) this(Loc loc, Declaration var, bool hasOverloads = true)
        {
            if (var.isVarDeclaration())
                hasOverloads = false;

            super(loc, TOKvar, __traits(classInstanceSize, VarExp), var, hasOverloads);
            this.type = var.type;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TupleExp : Expression
    {
        Expression e0;
        Expressions* exps;

        extern (D) this(Loc loc, Expression e0, Expressions* exps)
        {
            super(loc, TOKtuple, __traits(classInstanceSize, TupleExp));
            //printf("TupleExp(this = %p)\n", this);
            this.e0 = e0;
            this.exps = exps;
        }

        extern (D) this(Loc loc, Expressions* exps)
        {
            super(loc, TOKtuple, __traits(classInstanceSize, TupleExp));
            //printf("TupleExp(this = %p)\n", this);
            this.exps = exps;
        }

        extern (D) this(Loc loc, TupleDeclaration tup)
        {
            super(loc, TOKtuple, __traits(classInstanceSize, TupleExp));
            this.exps = new Expressions();

            this.exps.reserve(tup.objects.dim);
            for (size_t i = 0; i < tup.objects.dim; i++)
            {
                RootObject o = (*tup.objects)[i];
                if (Dsymbol s = getDsymbol(o))
                {
                    Expression e = new DsymbolExp(loc, s);
                    this.exps.push(e);
                }
                else if (o.dyncast() == DYNCAST.expression)
                {
                    auto e = (cast(Expression)o).copy();
                    e.loc = loc;    // Bugzilla 15669
                    this.exps.push(e);
                }
                else if (o.dyncast() == DYNCAST.type)
                {
                    Type t = cast(Type)o;
                    Expression e = new TypeExp(loc, t);
                    this.exps.push(e);
                }
                else
                {
                    error("%s is not an expression", o.toChars());
                }
            }
        }

        extern (C++) Dsymbol isDsymbol(RootObject o)
        {
            if (!o || o.dyncast || DYNCAST.dsymbol)
                return null;
            return cast(Dsymbol)o;
        }

        extern (C++) Dsymbol getDsymbol(RootObject oarg)
        {
            Dsymbol sa;
            Expression ea = isExpression(oarg);
            if (ea)
            {
                // Try to convert Expression to symbol
                if (ea.op == TOKvar)
                    sa = (cast(VarExp)ea).var;
                else if (ea.op == TOKfunction)
                {
                    if ((cast(FuncExp)ea).td)
                        sa = (cast(FuncExp)ea).td;
                    else
                        sa = (cast(FuncExp)ea).fd;
                }
                else if (ea.op == TOKtemplate)
                    sa = (cast(TemplateExp)ea).td;
                else
                    sa = null;
            }
            else
            {
                // Try to convert Type to symbol
                Type ta = isType(oarg);
                if (ta)
                    sa = ta.toDsymbol(null);
                else
                    sa = isDsymbol(oarg); // if already a symbol
            }
            return sa;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DollarExp : IdentifierExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, Id.dollar);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class ThisExp : Expression
    {
        final extern (D) this(Loc loc)
        {
            super(loc, TOKthis, __traits(classInstanceSize, ThisExp));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class SuperExp : ThisExp
    {
        extern (D) this(Loc loc)
        {
            super(loc);
            op = TOKsuper;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AddrExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKaddress, __traits(classInstanceSize, AddrExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PreExp : UnaExp
    {
        extern (D) this(TOK op, Loc loc, Expression e)
        {
            super(loc, op, __traits(classInstanceSize, PreExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PtrExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKstar, __traits(classInstanceSize, PtrExp), e);
        }
        extern (D) this(Loc loc, Expression e, Type t)
        {
            super(loc, TOKstar, __traits(classInstanceSize, PtrExp), e);
            type = t;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class NegExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKneg, __traits(classInstanceSize, NegExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class UAddExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKuadd, __traits(classInstanceSize, UAddExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class NotExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKnot, __traits(classInstanceSize, NotExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ComExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKtilde, __traits(classInstanceSize, ComExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DeleteExp : UnaExp
    {
        bool isRAII;

        extern (D) this(Loc loc, Expression e, bool isRAII)
        {
            super(loc, TOKdelete, __traits(classInstanceSize, DeleteExp), e);
            this.isRAII = isRAII;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CastExp : UnaExp
    {
        Type to;
        ubyte mod = cast(ubyte)~0;

        extern (D) this(Loc loc, Expression e, Type t)
        {
            super(loc, TOKcast, __traits(classInstanceSize, CastExp), e);
            this.to = t;
        }
        extern (D) this(Loc loc, Expression e, ubyte mod)
        {
            super(loc, TOKcast, __traits(classInstanceSize, CastExp), e);
            this.mod = mod;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CallExp : UnaExp
    {
        Expressions* arguments;

        extern (D) this(Loc loc, Expression e, Expressions* exps)
        {
            super(loc, TOKcall, __traits(classInstanceSize, CallExp), e);
            this.arguments = exps;
        }

        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKcall, __traits(classInstanceSize, CallExp), e);
        }

        extern (D) this(Loc loc, Expression e, Expression earg1)
        {
            super(loc, TOKcall, __traits(classInstanceSize, CallExp), e);
            auto arguments = new Expressions();
            if (earg1)
            {
                arguments.setDim(1);
                (*arguments)[0] = earg1;
            }
            this.arguments = arguments;
        }

        extern (D) this(Loc loc, Expression e, Expression earg1, Expression earg2)
        {
            super(loc, TOKcall, __traits(classInstanceSize, CallExp), e);
            auto arguments = new Expressions();
            arguments.setDim(2);
            (*arguments)[0] = earg1;
            (*arguments)[1] = earg2;
            this.arguments = arguments;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DotIdExp : UnaExp
    {
        Identifier ident;

        extern (D) this(Loc loc, Expression e, Identifier ident)
        {
            super(loc, TOKdotid, __traits(classInstanceSize, DotIdExp), e);
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AssertExp : UnaExp
    {
        Expression msg;

        extern (D) this(Loc loc, Expression e, Expression msg = null)
        {
            super(loc, TOKassert, __traits(classInstanceSize, AssertExp), e);
            this.msg = msg;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CompileExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKmixin, __traits(classInstanceSize, CompileExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ImportExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKimport, __traits(classInstanceSize, ImportExp), e);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DotTemplateInstanceExp : UnaExp
    {
        TemplateInstance ti;

        extern (D) this(Loc loc, Expression e, Identifier name, Objects* tiargs)
        {
            super(loc, TOKdotti, __traits(classInstanceSize, DotTemplateInstanceExp), e);
            this.ti = new TemplateInstance(loc, name, tiargs);
        }
        extern (D) this(Loc loc, Expression e, TemplateInstance ti)
        {
            super(loc, TOKdotti, __traits(classInstanceSize, DotTemplateInstanceExp), e);
            this.ti = ti;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ArrayExp : UnaExp
    {
        Expressions* arguments;

        extern (D) this(Loc loc, Expression e1, Expression index = null)
        {
            super(loc, TOKarray, __traits(classInstanceSize, ArrayExp), e1);
            arguments = new Expressions();
            if (index)
                arguments.push(index);
        }

        extern (D) this(Loc loc, Expression e1, Expressions* args)
        {
            super(loc, TOKarray, __traits(classInstanceSize, ArrayExp), e1);
            arguments = args;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class FuncInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKfuncstring, __traits(classInstanceSize, FuncInitExp));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PrettyFuncInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKprettyfunc, __traits(classInstanceSize, PrettyFuncInitExp));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class FileInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc, TOK tok)
        {
            super(loc, tok, __traits(classInstanceSize, FileInitExp));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class LineInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKline, __traits(classInstanceSize, LineInitExp));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ModuleInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKmodulestring, __traits(classInstanceSize, ModuleInitExp));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CommaExp : BinExp
    {
        const bool isGenerated;
        bool allowCommaExp;

        extern (D) this(Loc loc, Expression e1, Expression e2, bool generated = true)
        {
            super(loc, TOKcomma, __traits(classInstanceSize, CommaExp), e1, e2);
            allowCommaExp = isGenerated = generated;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PostExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e)
        {
            super(loc, op, __traits(classInstanceSize, PostExp), e, new IntegerExp(loc, 1, Type.tint32));
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PowExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKpow, __traits(classInstanceSize, PowExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class MulExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmul, __traits(classInstanceSize, MulExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DivExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKdiv, __traits(classInstanceSize, DivExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ModExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmod, __traits(classInstanceSize, ModExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AddExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKadd, __traits(classInstanceSize, AddExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class MinExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmin, __traits(classInstanceSize, MinExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CatExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKcat, __traits(classInstanceSize, CatExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ShlExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshl, __traits(classInstanceSize, ShlExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ShrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshr, __traits(classInstanceSize, ShrExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class UshrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKushr, __traits(classInstanceSize, UshrExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class EqualExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e1, Expression e2)
        {
            super(loc, op, __traits(classInstanceSize, EqualExp), e1, e2);
            assert(op == TOKequal || op == TOKnotequal);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class InExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKin, __traits(classInstanceSize, InExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class IdentityExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e1, Expression e2)
        {
            super(loc, op, __traits(classInstanceSize, IdentityExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CmpExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e1, Expression e2)
        {
            super(loc, op, __traits(classInstanceSize, CmpExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AndExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKand, __traits(classInstanceSize, AndExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class XorExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKxor, __traits(classInstanceSize, XorExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class OrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKor, __traits(classInstanceSize, OrExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AndAndExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKandand, __traits(classInstanceSize, AndAndExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class OrOrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKoror, __traits(classInstanceSize, OrOrExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CondExp : BinExp
    {
        Expression econd;

        extern (D) this(Loc loc, Expression econd, Expression e1, Expression e2)
        {
            super(loc, TOKquestion, __traits(classInstanceSize, CondExp), e1, e2);
            this.econd = econd;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AssignExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKassign, __traits(classInstanceSize, AssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class BinAssignExp : BinExp
    {
        final extern (D) this(Loc loc, TOK op, int size, Expression e1, Expression e2)
        {
            super(loc, op, size, e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AddAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKaddass, __traits(classInstanceSize, AddAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class MinAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKminass, __traits(classInstanceSize, MinAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class MulAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmulass, __traits(classInstanceSize, MulAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DivAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKdivass, __traits(classInstanceSize, DivAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ModAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmodass, __traits(classInstanceSize, ModAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class PowAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKpowass, __traits(classInstanceSize, PowAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class AndAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKandass, __traits(classInstanceSize, AndAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class OrAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKorass, __traits(classInstanceSize, OrAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class XorAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKxorass, __traits(classInstanceSize, XorAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ShlAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshlass, __traits(classInstanceSize, ShlAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ShrAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshrass, __traits(classInstanceSize, ShrAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class UshrAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKushrass, __traits(classInstanceSize, UshrAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class CatAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKcatass, __traits(classInstanceSize, CatAssignExp), e1, e2);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TemplateParameter
    {
        Loc loc;
        Identifier ident;

        final extern (D) this(Loc loc, Identifier ident)
        {
            this.loc = loc;
            this.ident = ident;
        }

        abstract TemplateParameter syntaxCopy(){ return null;}

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TemplateAliasParameter : TemplateParameter
    {
        Type specType;
        RootObject specAlias;
        RootObject defaultAlias;

        extern (D) this(Loc loc, Identifier ident, Type specType, RootObject specAlias, RootObject defaultAlias)
        {
            super(loc, ident);
            this.ident = ident;
            this.specType = specType;
            this.specAlias = specAlias;
            this.defaultAlias = defaultAlias;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class TemplateTypeParameter : TemplateParameter
    {
        Type specType;
        Type defaultType;

        final extern (D) this(Loc loc, Identifier ident, Type specType, Type defaultType)
        {
            super(loc, ident);
            this.ident = ident;
            this.specType = specType;
            this.defaultType = defaultType;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TemplateTupleParameter : TemplateParameter
    {
        extern (D) this(Loc loc, Identifier ident)
        {
            super(loc, ident);
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TemplateValueParameter : TemplateParameter
    {
        Type valType;
        Expression specValue;
        Expression defaultValue;

        extern (D) this(Loc loc, Identifier ident, Type valType,
            Expression specValue, Expression defaultValue)
        {
            super(loc, ident);
            this.ident = ident;
            this.valType = valType;
            this.specValue = specValue;
            this.defaultValue = defaultValue;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class TemplateThisParameter : TemplateTypeParameter
    {
        extern (D) this(Loc loc, Identifier ident, Type specType, Type defaultType)
        {
            super(loc, ident, specType, defaultType);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) abstract class Condition : RootObject
    {
        Loc loc;

        final extern (D) this(Loc loc)
        {
            this.loc = loc;
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StaticForeach : RootObject
    {
        Loc loc;

        ForeachStatement aggrfe;
        ForeachRangeStatement rangefe;

        final extern (D) this(Loc loc, ForeachStatement aggrfe, ForeachRangeStatement rangefe)
        in
        {
            assert(!!aggrfe ^ !!rangefe);
        }
        body
        {
            this.loc = loc;
            this.aggrfe = aggrfe;
            this.rangefe = rangefe;
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StaticIfCondition : Condition
    {
        Expression exp;

        final extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class DVCondition : Condition
    {
        uint level;
        Identifier ident;
        Module mod;

        final extern (D) this(Module mod, uint level, Identifier ident)
        {
            super(Loc());
            this.mod = mod;
            this.ident = ident;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class DebugCondition : DVCondition
    {
        extern (D) this(Module mod, uint level, Identifier ident)
        {
            super(mod, level, ident);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class VersionCondition : DVCondition
    {
        extern (D) this(Module mod, uint level, Identifier ident)
        {
            super(mod, level, ident);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) class Initializer : RootObject
    {
        Loc loc;

        final extern (D) this(Loc loc)
        {
            this.loc = loc;
        }

        // this should be abstract and implemented in child classes
        Expression toExpression(Type t = null)
        {
            return null;
        }

        ExpInitializer isExpInitializer()
        {
            return null;
        }

        void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ExpInitializer : Initializer
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
        }

        override ExpInitializer isExpInitializer()
        {
            return this;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class StructInitializer : Initializer
    {
        Identifiers field;
        Initializers value;

        extern (D) this(Loc loc)
        {
            super(loc);
        }

        void addInit(Identifier field, Initializer value)
        {
            this.field.push(field);
            this.value.push(value);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class ArrayInitializer : Initializer
    {
        Expressions index;
        Initializers value;
        uint dim;
        Type type;

        extern (D) this(Loc loc)
        {
            super(loc);
        }

        void addInit(Expression index, Initializer value)
        {
            this.index.push(index);
            this.value.push(value);
            dim = 0;
            type = null;
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class VoidInitializer : Initializer
    {
        extern (D) this(Loc loc)
        {
            super(loc);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }

    extern (C++) final class Tuple : RootObject
    {
        Objects objects;

        // kludge for template.isType()
        override DYNCAST dyncast() const
        {
            return DYNCAST.tuple;
        }

        override const(char)* toChars()
        {
            return objects.toChars();
        }
    }

    struct BaseClass
    {
        Type type;
    }

    struct ModuleDeclaration
    {
        Loc loc;
        Identifier id;
        Identifiers *packages;
        bool isdeprecated;
        Expression msg;

        extern (D) this(Loc loc, Identifiers* packages, Identifier id, Expression msg, bool isdeprecated)
        {
            this.loc = loc;
            this.packages = packages;
            this.id = id;
            this.msg = msg;
            this.isdeprecated = isdeprecated;
        }

        extern (C++) const(char)* toChars()
        {
            OutBuffer buf;
            if (packages && packages.dim)
            {
                for (size_t i = 0; i < packages.dim; i++)
                {
                    Identifier pid = (*packages)[i];
                    buf.writestring(pid.toChars());
                    buf.writeByte('.');
                }
            }
            buf.writestring(id.toChars());
            return buf.extractString();
        }
    }

    struct Prot
    {
        PROTKIND kind;
        Package pkg;
    }

    struct Scope
    {

    }

    static extern (C++) Tuple isTuple(RootObject o)
    {
        //return dynamic_cast<Tuple *>(o);
        if (!o || o.dyncast() != DYNCAST.tuple)
            return null;
        return cast(Tuple)o;
    }

    static extern (C++) Type isType(RootObject o)
    {
        if (!o || o.dyncast() != DYNCAST.type)
            return null;
        return cast(Type)o;
    }

    static extern (C++) Expression isExpression(RootObject o)
    {
        if (!o || o.dyncast() != DYNCAST.expression)
            return null;
        return cast(Expression)o;
    }



    extern (C++) static const(char)* protectionToChars(PROTKIND kind)
    {
        switch (kind)
        {
        case PROTundefined:
            return null;
        case PROTnone:
            return "none";
        case PROTprivate:
            return "private";
        case PROTpackage:
            return "package";
        case PROTprotected:
            return "protected";
        case PROTpublic:
            return "public";
        case PROTexport:
            return "export";
        default:
            assert(0);
        }
    }

    extern (C++) static bool stcToBuffer(OutBuffer* buf, StorageClass stc)
    {
        bool result = false;
        if ((stc & (STCreturn | STCscope)) == (STCreturn | STCscope))
            stc &= ~STCscope;
        while (stc)
        {
            const(char)* p = stcToChars(stc);
            if (!p) // there's no visible storage classes
                break;
            if (!result)
                result = true;
            else
                buf.writeByte(' ');
            buf.writestring(p);
        }
        return result;
    }

    static extern (C++) Expression initializerToExpression(Initializer i)
    {
        return i.toExpression;
    }

    static extern (C++) Expression typeToExpression(Type t)
    {
        return t.toExpression;
    }

    extern (C++) static const(char)* stcToChars(ref StorageClass stc)
    {
        struct SCstring
        {
            StorageClass stc;
            TOK tok;
            const(char)* id;
        }

        static __gshared SCstring* table =
        [
            SCstring(STCauto, TOKauto),
            SCstring(STCscope, TOKscope),
            SCstring(STCstatic, TOKstatic),
            SCstring(STCextern, TOKextern),
            SCstring(STCconst, TOKconst),
            SCstring(STCfinal, TOKfinal),
            SCstring(STCabstract, TOKabstract),
            SCstring(STCsynchronized, TOKsynchronized),
            SCstring(STCdeprecated, TOKdeprecated),
            SCstring(STCoverride, TOKoverride),
            SCstring(STClazy, TOKlazy),
            SCstring(STCalias, TOKalias),
            SCstring(STCout, TOKout),
            SCstring(STCin, TOKin),
            SCstring(STCmanifest, TOKenum),
            SCstring(STCimmutable, TOKimmutable),
            SCstring(STCshared, TOKshared),
            SCstring(STCnothrow, TOKnothrow),
            SCstring(STCwild, TOKwild),
            SCstring(STCpure, TOKpure),
            SCstring(STCref, TOKref),
            SCstring(STCtls),
            SCstring(STCgshared, TOKgshared),
            SCstring(STCnogc, TOKat, "@nogc"),
            SCstring(STCproperty, TOKat, "@property"),
            SCstring(STCsafe, TOKat, "@safe"),
            SCstring(STCtrusted, TOKat, "@trusted"),
            SCstring(STCsystem, TOKat, "@system"),
            SCstring(STCdisable, TOKat, "@disable"),
            SCstring(STCfuture, TOKat, "@__future"),
            SCstring(0, TOKreserved)
        ];
        for (int i = 0; table[i].stc; i++)
        {
            StorageClass tbl = table[i].stc;
            assert(tbl & STCStorageClass);
            if (stc & tbl)
            {
                stc &= ~tbl;
                if (tbl == STCtls) // TOKtls was removed
                    return "__thread";
                TOK tok = table[i].tok;
                if (tok == TOKat)
                    return table[i].id;
                else
                    return Token.toChars(tok);
            }
        }
        //printf("stc = %llx\n", stc);
        return null;
    }

    extern (C++) static const(char)* linkageToChars(LINK linkage)
    {
        switch (linkage)
        {
        case LINKdefault:
            return null;
        case LINKd:
            return "D";
        case LINKc:
            return "C";
        case LINKcpp:
            return "C++";
        case LINKwindows:
            return "Windows";
        case LINKpascal:
            return "Pascal";
        case LINKobjc:
            return "Objective-C";
        default:
            assert(0);
        }
    }

    struct Target
    {
        extern (C++) static __gshared int ptrsize;

        extern (C++) static Type va_listType()
        {
            if (global.params.isWindows)
            {
                return Type.tchar.pointerTo();
            }
            else if (global.params.isLinux || global.params.isFreeBSD || global.params.isOpenBSD || global.params.isSolaris || global.params.isOSX)
            {
                if (global.params.is64bit)
                {
                    return (new TypeIdentifier(Loc(), Identifier.idPool("__va_list_tag"))).pointerTo();
                }
                else
                {
                    return Type.tchar.pointerTo();
                }
            }
            else
            {
                assert(0);
            }
        }
    }
}
