module ddmd.astbaremetal;

struct ASTBaremetal
{
    import ddmd.root.file;
    import ddmd.root.filename;
    import ddmd.root.array;
    import ddmd.root.rootobject;
    import ddmd.root.outbuffer;
    import ddmd.root.ctfloat;

    import ddmd.tokens;
    import ddmd.identifier;
    import ddmd.globals;
    import ddmd.id;
    import ddmd.errors;
    import ddmd.lexer;

    import core.stdc.string;

    alias Dsymbols              = Array!(Dsymbol);
    alias Objects               = Array!(RootObject);
    alias Expressions           = Array!(Expression);
    alias TemplateParameters    = Array!(TemplateParameter);
    alias BaseClasses           = Array!(BaseClass*);
    alias Parameters            = Array!(Parameter);
    alias Statements            = Array!(Statement);
    alias Catches               = Array!(Catch);
    alias Identifiers           = Array!(Identifier);

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

    enum MODconst            = 0;
    enum MODimmutable        = 0;
    enum MODshared           = 0;
    enum MODwild             = 0;

    enum STCconst                  = 0;
    enum STCimmutable              = 0;
    enum STCshared                 = 0;
    enum STCwild                   = 0;
    enum STCin                     = 0;
    enum STCout                    = 0;
    enum STCref                    = 0;
    enum STClazy                   = 0;
    enum STCscope                  = 0;
    enum STCfinal                  = 0;
    enum STCauto                   = 0;
    enum STCreturn                 = 0;
    enum STCmanifest               = 0;
    enum STCgshared                = 0;
    enum STCtls                    = 0;
    enum STCsafe                   = 0;
    enum STCsystem                 = 0;
    enum STCtrusted                = 0;
    enum STCnothrow                = 0;
    enum STCpure                   = 0;
    enum STCproperty               = 0;
    enum STCnogc                   = 0;
    enum STCdisable                = 0;
    enum STCundefined              = 0;
    enum STC_TYPECTOR              = 0;
    enum STCoverride               = 0;
    enum STCabstract               = 0;
    enum STCsynchronized           = 0;
    enum STCdeprecated             = 0;
    enum STCstatic                 = 0;
    enum STCextern                 = 0;

    private enum STC_FUNCATTR = (STCref | STCnothrow | STCnogc | STCpure | STCproperty | STCsafe | STCtrusted | STCsystem);

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
        TMAX,
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

    extern (C++) class Dsymbol
    {
        Loc loc;
        Identifier ident;
        UnitTestDeclaration ddocUnittest;
        UserAttributeDeclaration userAttribDecl;
        Dsymbol parent;

        final extern (D) this() {}
        final extern (D) this(Identifier ident)
        {
            this.ident = ident;
        }

        void addComment(const(char)* comment) {}
        AttribDeclaration isAttribDeclaration()
        {
            return null;
        }

        static bool oneMembers(Dsymbols* members, Dsymbol* ps, Identifier ident)
        {
            return false;
        }

        final void error(const(char)* format, const(char)* p1, const(char)* p2) {}
        final void error(const(char)* format, const(char)* p1) {}
        final void error(const(char)* format) {}

        inout(TemplateDeclaration) isTemplateDeclaration() inout
        {
            return null;
        }

        inout(FuncLiteralDeclaration) isFuncLiteralDeclaration() inout
        {
            return null;
        }
    }

    extern (C++) class AliasThis : Dsymbol
    {
        Identifier ident;

        final extern (D) this(Loc loc, Identifier ident)
        {
            super(null);
            this.loc = loc;
            this.ident = ident;
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
    }

    extern (C++) class ScopeDsymbol : Dsymbol
    {
        Dsymbols* members;
        final extern (D) this() {}
        final extern (D) this(Identifier id)
        {
            super(id);
        }
    }

    extern (C++) class Import : Dsymbol
    {
        Identifiers* packages;
        Identifier id;
        Identifier aliasId;
        int isstatic;
        Prot protection;

        final extern (D) this(Loc loc, Identifiers* packages, Identifier id, Identifier aliasId, int isstatic)
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
        void addAlias(A, B)(A a, B b) {}
    }

    extern (C++) abstract class AttribDeclaration : Dsymbol
    {
        Dsymbols* decl;

        final extern (D) this(Dsymbols *decl)
        {
            this.decl = decl;
        }
    }

    extern (C++) final class StaticAssert : Dsymbol
    {
        Expression exp;
        Expression msg;

        final extern (D) this(Loc loc, Expression exp, Expression msg)
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
    }

    extern (C++) final class AliasDeclaration : Declaration
    {
        Dsymbol aliassym;

        final extern (D) this(Loc loc, Identifier id, Dsymbol s)
        {
            super(id);
            this.loc = loc;
            this.aliassym = s;
        }
        final extern (D) this(Loc loc, Identifier id, Type type)
        {
            super(id);
            this.loc = loc;
            this.type = type;
        }
    }

    extern (C++) final class FuncLiteralDeclaration : FuncDeclaration
    {
        TOK tok;

        final extern (D) this(Loc loc, Loc endloc, Type type, TOK tok, ForeachStatement fes, Identifier id = null)
        {
            super(loc, endloc, null, STCundefined, type);
            this.ident = id ? id : Id.empty;
            this.tok = tok;
            this.fes = fes;
        }
    }

    extern (C++) final class PostBlitDeclaration : FuncDeclaration
    {
        final extern (D) this(Loc loc, Loc endloc, StorageClass stc, Identifier id)
        {
            super(loc, endloc, id, stc, null);
        }
    }

    extern (C++) final class CtorDeclaration : FuncDeclaration
    {
        final extern (D) this(Loc loc, Loc endloc, StorageClass stc, Type type)
        {
            super(loc, endloc, Id.ctor, stc, type);
        }
    }

    extern (C++) final class DtorDeclaration : FuncDeclaration
    {
        final extern (D) this(Loc loc, Loc endloc)
        {
            super(loc, endloc, Id.dtor, STCundefined, null);
        }
        final extern (D) this(Loc loc, Loc endloc, StorageClass stc, Identifier id)
        {
            super(loc, endloc, id, stc, null);
        }
    }

    extern (C++) final class InvariantDeclaration : FuncDeclaration
    {
        final extern (D) this(Loc loc, Loc endloc, StorageClass stc, Identifier id, Statement fbody)
        {
            super(loc, endloc, id ? id : Identifier.generateId("__invariant"), stc, null);
            this.fbody = fbody;
        }
    }

    extern (C++) final class UnitTestDeclaration : FuncDeclaration
    {
        char* codedoc;

        final extern (D) this(Loc loc, Loc endloc, StorageClass stc, char* codedoc)
        {
            OutBuffer buf;
            buf.printf("__unittestL%u_", loc.linnum);
            super(loc, endloc, Identifier.generateId(buf.peekString()), stc, null);
            this.codedoc = codedoc;
        }
    }

    extern (C++) final class NewDeclaration : FuncDeclaration
    {
        Parameters* parameters;
        int varargs;

        final extern (D) this(Loc loc, Loc endloc, StorageClass stc, Parameters* fparams, int varargs)
        {
            super(loc, endloc, Id.classNew, STCstatic | stc, null);
            this.parameters = fparams;
            this.varargs = varargs;
        }
    }

    extern (C++) final class DeleteDeclaration : FuncDeclaration
    {
        Parameters* parameters;

        final extern (D) this(Loc loc, Loc endloc, StorageClass stc, Parameters* fparams)
        {
            super(loc, endloc, Id.classDelete, STCstatic | stc, null);
            this.parameters = fparams;
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
    }

    extern (C++) final class SharedStaticCtorDeclaration : StaticCtorDeclaration
    {
        final extern (D) this(Loc loc, Loc endloc, StorageClass stc)
        {
            super(loc, endloc, "_sharedStaticCtor", stc);
        }
    }

    extern (C++) final class SharedStaticDtorDeclaration : StaticDtorDeclaration
    {
        final extern (D) this(Loc loc, Loc endloc, StorageClass stc)
        {
            super(loc, endloc, "_sharedStaticDtor", stc);
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
    }

    extern (C++) final class EnumDeclaration : ScopeDsymbol
    {
        Type type;
        Type memtype;
        Prot protection;

        final extern (D) this(Loc loc, Identifier id, Type memtype)
        {
            super(id);
            this.loc = loc;
            type = new TypeEnum(this);
            this.memtype = memtype;
            protection = Prot(PROTundefined);
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

        final extern (D) this(Loc loc, Identifier id, TemplateParameters* parameters, Expression constraint, Dsymbols* decldefs, bool ismixin = false, bool literal = false)
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
    }

    extern (C++) class TemplateInstance : ScopeDsymbol
    {
        Identifier name;
        Objects* tiargs;
        Dsymbol tempdecl;
        bool semantictiargsdone;
        bool havetempdecl;

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
    }

    extern (C++) final class Nspace : ScopeDsymbol
    {
        final extern (D) this(Loc loc, Identifier ident, Dsymbols* members)
        {
            super(ident);
            this.loc = loc;
            this.members = members;
        }
    }

    extern (C++) final class CompileDeclaration : AttribDeclaration
    {
        Expression exp;

        final extern (D) this(Loc loc, Expression exp)
        {
            super(null);
            this.loc = loc;
            this.exp = exp;
        }
    }

    extern (C++) final class UserAttributeDeclaration : AttribDeclaration
    {
        Expressions* atts;

        final extern (D) this(Expressions* atts, Dsymbols* decl)
        {
            super(decl);
            this.atts = atts;
        }
        static Expressions* concat(Expressions* a, Expressions* b)
        {
            return null;
        }
    }

    extern (C++) final class LinkDeclaration : AttribDeclaration
    {
        LINK linkage;

        final extern (D) this(LINK p, Dsymbols* decl)
        {
            super(decl);
            linkage = p;
        }
    }

    extern (C++) final class AnonDeclaration : AttribDeclaration
    {
        bool isunion;

        final extern (D) this(Loc loc, bool isunion, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.isunion = isunion;
        }
    }

    extern (C++) final class AlignDeclaration : AttribDeclaration
    {
        Expression ealign;

        final extern (D) this(Loc loc, Expression ealign, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.ealign = ealign;
        }
    }

    extern (C++) final class CPPMangleDeclaration : AttribDeclaration
    {
        CPPMANGLE cppmangle;

        final extern (D) this(CPPMANGLE p, Dsymbols* decl)
        {
            super(decl);
            cppmangle = p;
        }
    }

    extern (C++) final class ProtDeclaration : AttribDeclaration
    {
        Prot protection;
        Identifiers* pkg_identifiers;

        final extern (D) this(Loc loc, Prot p, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.protection = p;
        }
        final extern (D) this(Loc loc, Identifiers* pkg_identifiers, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.protection.kind = PROTpackage;
            this.protection.pkg = null;
            this.pkg_identifiers = pkg_identifiers;
        }
    }

    extern (C++) final class PragmaDeclaration : AttribDeclaration
    {
        Expressions* args;

        final extern (D) this(Loc loc, Identifier ident, Expressions* args, Dsymbols* decl)
        {
            super(decl);
            this.loc = loc;
            this.ident = ident;
            this.args = args;
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
    }

    extern (C++) final class DeprecatedDeclaration : StorageClassDeclaration
    {
        Expression msg;

        final extern (D) this(Expression msg, Dsymbols* decl)
        {
            super(STCdeprecated, decl);
            this.msg = msg;
        }
    }

    extern (C++) final class StaticIfDeclaration : ConditionalDeclaration
    {
        final extern (D) this(Condition condition, Dsymbols* decl, Dsymbols* elsedecl)
        {
            super(condition, decl, elsedecl);
        }
    }

    extern (C++) final class EnumMember : VarDeclaration
    {
        Expression origValue;
        Type origType;

        final extern (D) this(Loc loc, Identifier id, Expression value, Type origType)
        {
            super(loc, null, id ? id : Id.empty, new ExpInitializer(loc, value));
            this.origValue = value;
            this.origType = origType;
        }
    }

    extern (C++) final class Module : Package
    {
        version(Windows)
        {
            extern (C) char* getcwd(char* buffer, size_t maxlen);
        }
        else
        {
            import core.sys.posix.unistd : getcwd;
        }

        extern (C++) static __gshared AggregateDeclaration moduleinfo;

        File* srcfile;
        File* objfile;
        File* hdrfile;
        File* docfile;
        const(char)* arg;
        const(char)* srcfilePath;

        extern (D) this(const(char)* filename, Identifier ident, int doDocComment, int doHdrGen)
        {
            super(ident);
            this.arg = filename;
            const(char)* srcfilename = FileName.defaultExt(filename, global.mars_ext);
            if (global.run_noext && global.params.run && !FileName.ext(filename)
                && FileName.exists(srcfilename) == 0 && FileName.exists(filename) == 1)
            {
                FileName.free(srcfilename);
                srcfilename = FileName.removeExt(filename); // just does a mem.strdup(filename)
            }
            else if (!FileName.equalsExt(srcfilename, global.mars_ext)
                     && !FileName.equalsExt(srcfilename, global.hdr_ext)
                     && !FileName.equalsExt(srcfilename, "dd"))
            {
                error("source file name '%s' must have .%s extension", srcfilename, global.mars_ext);
                fatal();
            }
            srcfile = new File(srcfilename);
            if(!FileName.absolute(srcfilename)) {
                srcfilePath = getcwd(null, 0);
            }
            objfile = setOutfile(global.params.objname, global.params.objdir, filename, global.obj_ext);
            if (doDocComment)
                docfile = setOutfile(global.params.docname, global.params.docdir, arg, global.doc_ext);
            if (doHdrGen)
                hdrfile = setOutfile(global.params.hdrname, global.params.hdrdir, arg, global.hdr_ext);
        }

        File* setOutfile(const(char)* name, const(char)* dir, const(char)* arg, const(char)* ext)
        {
            const(char)* docfilename;
            if (name)
            {
                docfilename = name;
            }
            else
            {
                const(char)* argdoc;
                if (global.params.preservePaths)
                    argdoc = arg;
                else
                    argdoc = FileName.name(arg);
                // If argdoc doesn't have an absolute path, make it relative to dir
                if (!FileName.absolute(argdoc))
                {
                    //FileName::ensurePathExists(dir);
                    argdoc = FileName.combine(dir, argdoc);
                }
                docfilename = FileName.forceExt(argdoc, ext);
            }
            if (FileName.equals(docfilename, srcfile.name.str))
            {
                error("source file and output file have same name '%s'", srcfile.name.str);
                fatal();
            }
            return new File(docfilename);
        }

        const(char)* toChars() const
        {
            return "";
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
    }

    extern (C++) final class UnionDeclaration : StructDeclaration
    {
        final extern (D) this(Loc loc, Identifier id)
        {
            super(loc, id);
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
    }

    extern (C++) class InterfaceDeclaration : ClassDeclaration
    {
        final extern (D) this(Loc loc, Identifier id, BaseClasses* baseclasses)
        {
            super(loc, id, baseclasses, null, false);
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
    }

    extern (C++) final class Parameter : RootObject
    {
        StorageClass storageClass;
        Type type;
        Identifier ident;
        Expression defaultArg;

        final extern (D) this(StorageClass storageClass, Type type, Identifier ident, Expression defaultArg)
        {
            this.storageClass = storageClass;
            this.type = type;
            this.ident = ident;
            this.defaultArg = defaultArg;
        }

        static size_t dim(Parameters* parameters)
        {
            return 0;
        }
    }

    extern (C++) abstract class Statement : RootObject
    {
        Loc loc;

        final extern (D) this(Loc loc)
        {
            this.loc = loc;
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
    }

    extern (C++) final class ReturnStatement : Statement
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
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
    }

    extern (C++) final class StaticAssertStatement : Statement
    {
        StaticAssert sa;

        final extern (D) this(StaticAssert sa)
        {
            super(sa.loc);
            this.sa = sa;
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
    }

    extern (C++) final class DefaultStatement : Statement
    {
        Statement statement;

        extern (D) this(Loc loc, Statement s)
        {
            super(loc);
            this.statement = s;
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
    }

    extern (C++) final class ContinueStatement : Statement
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(loc);
            this.ident = ident;
        }
    }

    extern (C++) final class GotoDefaultStatement : Statement
    {
        extern (D) this(Loc loc)
        {
            super(loc);
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
    }

    extern (C++) final class GotoStatement : Statement
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(loc);
            this.ident = ident;
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
    }

    extern (C++) final class ThrowStatement : Statement
    {
        Expression exp;

        extern (D) this(Loc loc, Expression exp)
        {
            super(loc);
            this.exp = exp;
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
    }

    extern (C++) final class CompoundDeclarationStatement : CompoundStatement
    {
        final extern (D) this(Loc loc, Statements* statements)
        {
            super(loc, statements);
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
    extern (C++) abstract class Type : RootObject
    {
        TY ty;

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

        extern (C++) static __gshared Type terror;

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

        final extern (D) this(TY ty)
        {
            this.ty = ty;
        }

        final Type addSTC(B)(B b)
        {
            return null;
        }
        Expression toExpression()
        {
            return null;
        }
        Type syntaxCopy()
        {
            return null;
        }
        final Type addMod(T)(T...)
        {
            return null;
        }
        Type nextOf()
        {
            return null;
        }
        bool isscalar()
        {
            return false;
        }
        Type toBasetype()
        {
            return this;
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
    }

    extern (C++) final class TypeEnum : Type
    {
        EnumDeclaration sym;

        extern (D) this(EnumDeclaration sym)
        {
            super(Tenum);
            this.sym = sym;
        }
    }

    extern (C++) final class TypeClass : Type
    {
        ClassDeclaration sym;

        extern (D) this (ClassDeclaration sym)
        {
            super(Tclass);
            this.sym = sym;
        }
    }

    extern (C++) final class TypeStruct : Type
    {
        StructDeclaration sym;

        extern (D) this(StructDeclaration sym)
        {
            super(Tstruct);
            this.sym = sym;
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
    }

    extern (C++) class TypeDelegate : TypeNext
    {
        extern (D) this(Type t)
        {
            super(Tfunction, t);
            ty = Tdelegate;
        }
    }

    extern (C++) final class TypePointer : TypeNext
    {
        extern (D) this(Type t)
        {
            super(Tpointer, t);
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
    }

    extern (C++) class TypeArray : TypeNext
    {
        final extern (D) this(TY ty, Type next)
        {
            super(ty, next);
        }
    }

    extern (C++) final class TypeDArray : TypeArray
    {
        extern (D) this(Type t)
        {
            super(Tarray, t);
        }
    }

    extern (C++) final class TypeAArray : TypeArray
    {
        Type index;

        extern (D) this(Type t, Type index)
        {
            super(Taarray, t);
            this.index = index;
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

        final void addIdent(Identifier id) {}
        final void addInst(TemplateInstance ti) {}
        final void addIndex(RootObject e) {}
    }

    extern (C++) final class TypeIdentifier : TypeQualified
    {
        Identifier ident;

        extern (D) this(Loc loc, Identifier ident)
        {
            super(Tident, loc);
            this.ident = ident;
        }
    }

    extern (C++) final class TypeReturn : TypeQualified
    {
        extern (D) this(Loc loc)
        {
            super(Treturn, loc);
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
    }

    extern (C++) final class TypeInstance : TypeQualified
    {
        TemplateInstance tempinst;

        final extern (D) this(Loc loc, TemplateInstance tempinst)
        {
            super(Tinstance, loc);
            this.tempinst = tempinst;
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
            return null;
        }

        final void error(const(char)* format, const(char)* p1) const {}
    }

    extern (C++) final class DeclarationExp : Expression
    {
        Dsymbol declaration;

        extern (D) this(Loc loc, Dsymbol declaration)
        {
            super(loc, TOKdeclaration, __traits(classInstanceSize, DeclarationExp));
            this.declaration = declaration;
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

    private:
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
    }

    extern (C++) final class RealExp : Expression
    {
        real_t value;

        extern (D) this(Loc loc, real_t value, Type type)
        {
            super(loc, TOKfloat64, __traits(classInstanceSize, RealExp));
            //printf("RealExp::RealExp(%Lg)\n", value);
            this.value = value;
            this.type = type;
        }
    }

    extern (C++) final class NullExp : Expression
    {
        extern (D) this(Loc loc, Type type = null)
        {
            super(loc, TOKnull, __traits(classInstanceSize, NullExp));
            this.type = type;
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
    }

    extern (C++) final class TypeExp : Expression
    {
        extern (D) this(Loc loc, Type type)
        {
            super(loc, TOKtype, __traits(classInstanceSize, TypeExp));
            this.type = type;
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
    }

    extern (C++) class IdentifierExp : Expression
    {
        Identifier ident;

        final extern (D) this(Loc loc, Identifier ident)
        {
            super(loc, TOKidentifier, __traits(classInstanceSize, IdentifierExp));
            this.ident = ident;
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
    }

    extern (C++) class DefaultInitExp : Expression
    {
        TOK subop;      // which of the derived classes this is

        final extern (D) this(Loc loc, TOK subop, int size)
        {
            super(loc, TOKdefault, size);
            this.subop = subop;
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
    }

    extern (C++) final class DollarExp : IdentifierExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, Id.dollar);
        }
    }

    extern (C++) class ThisExp : Expression
    {
        final extern (D) this(Loc loc)
        {
            super(loc, TOKthis, __traits(classInstanceSize, ThisExp));
        }
    }

    extern (C++) final class SuperExp : ThisExp
    {
        extern (D) this(Loc loc)
        {
            super(loc);
            op = TOKsuper;
        }
    }

    extern (C++) final class AddrExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKaddress, __traits(classInstanceSize, AddrExp), e);
        }
    }

    extern (C++) final class PreExp : UnaExp
    {
        extern (D) this(TOK op, Loc loc, Expression e)
        {
            super(loc, op, __traits(classInstanceSize, PreExp), e);
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
    }

    extern (C++) final class NegExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKneg, __traits(classInstanceSize, NegExp), e);
        }
    }

    extern (C++) final class UAddExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKuadd, __traits(classInstanceSize, UAddExp), e);
        }
    }

    extern (C++) final class NotExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKnot, __traits(classInstanceSize, NotExp), e);
        }
    }

    extern (C++) final class ComExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKtilde, __traits(classInstanceSize, ComExp), e);
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
    }

    extern (C++) final class DotIdExp : UnaExp
    {
        Identifier ident;

        extern (D) this(Loc loc, Expression e, Identifier ident)
        {
            super(loc, TOKdotid, __traits(classInstanceSize, DotIdExp), e);
            this.ident = ident;
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
    }

    extern (C++) final class CompileExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKmixin, __traits(classInstanceSize, CompileExp), e);
        }
    }

    extern (C++) final class ImportExp : UnaExp
    {
        extern (D) this(Loc loc, Expression e)
        {
            super(loc, TOKimport, __traits(classInstanceSize, ImportExp), e);
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
    }

    extern (C++) final class FuncInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKfuncstring, __traits(classInstanceSize, FuncInitExp));
        }
    }

    extern (C++) final class PrettyFuncInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKprettyfunc, __traits(classInstanceSize, PrettyFuncInitExp));
        }
    }

    extern (C++) final class FileInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc, TOK tok)
        {
            super(loc, tok, __traits(classInstanceSize, FileInitExp));
        }
    }

    extern (C++) final class LineInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKline, __traits(classInstanceSize, LineInitExp));
        }
    }

    extern (C++) final class ModuleInitExp : DefaultInitExp
    {
        extern (D) this(Loc loc)
        {
            super(loc, TOKmodulestring, __traits(classInstanceSize, ModuleInitExp));
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
    }

    extern (C++) final class PostExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e)
        {
            super(loc, op, __traits(classInstanceSize, PostExp), e, new IntegerExp(loc, 1, Type.tint32));
        }
    }

    extern (C++) final class PowExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKpow, __traits(classInstanceSize, PowExp), e1, e2);
        }
    }

    extern (C++) final class MulExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmul, __traits(classInstanceSize, MulExp), e1, e2);
        }
    }

    extern (C++) final class DivExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKdiv, __traits(classInstanceSize, DivExp), e1, e2);
        }
    }

    extern (C++) final class ModExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmod, __traits(classInstanceSize, ModExp), e1, e2);
        }
    }

    extern (C++) final class AddExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKadd, __traits(classInstanceSize, AddExp), e1, e2);
        }
    }

    extern (C++) final class MinExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmin, __traits(classInstanceSize, MinExp), e1, e2);
        }
    }

    extern (C++) final class CatExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKcat, __traits(classInstanceSize, CatExp), e1, e2);
        }
    }

    extern (C++) final class ShlExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshl, __traits(classInstanceSize, ShlExp), e1, e2);
        }
    }

    extern (C++) final class ShrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshr, __traits(classInstanceSize, ShrExp), e1, e2);
        }
    }

    extern (C++) final class UshrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKushr, __traits(classInstanceSize, UshrExp), e1, e2);
        }
    }

    extern (C++) final class EqualExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e1, Expression e2)
        {
            super(loc, op, __traits(classInstanceSize, EqualExp), e1, e2);
            assert(op == TOKequal || op == TOKnotequal);
        }
    }

    extern (C++) final class InExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKin, __traits(classInstanceSize, InExp), e1, e2);
        }
    }

    extern (C++) final class IdentityExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e1, Expression e2)
        {
            super(loc, op, __traits(classInstanceSize, IdentityExp), e1, e2);
        }
    }

    extern (C++) final class CmpExp : BinExp
    {
        extern (D) this(TOK op, Loc loc, Expression e1, Expression e2)
        {
            super(loc, op, __traits(classInstanceSize, CmpExp), e1, e2);
        }
    }

    extern (C++) final class AndExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKand, __traits(classInstanceSize, AndExp), e1, e2);
        }
    }

    extern (C++) final class XorExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKxor, __traits(classInstanceSize, XorExp), e1, e2);
        }
    }

    extern (C++) final class OrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKor, __traits(classInstanceSize, OrExp), e1, e2);
        }
    }

    extern (C++) final class AndAndExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKandand, __traits(classInstanceSize, AndAndExp), e1, e2);
        }
    }

    extern (C++) final class OrOrExp : BinExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKoror, __traits(classInstanceSize, OrOrExp), e1, e2);
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
    }

    extern (C++) final class AssignExp : BinExp
    {
        final extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKassign, __traits(classInstanceSize, AssignExp), e1, e2);
        }
    }

    extern (C++) class BinAssignExp : BinExp
    {
        final extern (D) this(Loc loc, TOK op, int size, Expression e1, Expression e2)
        {
            super(loc, op, size, e1, e2);
        }
    }

    extern (C++) final class AddAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKaddass, __traits(classInstanceSize, AddAssignExp), e1, e2);
        }
    }

    extern (C++) final class MinAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKminass, __traits(classInstanceSize, MinAssignExp), e1, e2);
        }
    }

    extern (C++) final class MulAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmulass, __traits(classInstanceSize, MulAssignExp), e1, e2);
        }
    }

    extern (C++) final class DivAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKdivass, __traits(classInstanceSize, DivAssignExp), e1, e2);
        }
    }

    extern (C++) final class ModAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKmodass, __traits(classInstanceSize, ModAssignExp), e1, e2);
        }
    }

    extern (C++) final class PowAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKpowass, __traits(classInstanceSize, PowAssignExp), e1, e2);
        }
    }

    extern (C++) final class AndAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKandass, __traits(classInstanceSize, AndAssignExp), e1, e2);
        }
    }

    extern (C++) final class OrAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKorass, __traits(classInstanceSize, OrAssignExp), e1, e2);
        }
    }

    extern (C++) final class XorAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKxorass, __traits(classInstanceSize, XorAssignExp), e1, e2);
        }
    }

    extern (C++) final class ShlAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshlass, __traits(classInstanceSize, ShlAssignExp), e1, e2);
        }
    }

    extern (C++) final class ShrAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKshrass, __traits(classInstanceSize, ShrAssignExp), e1, e2);
        }
    }

    extern (C++) final class UshrAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKushrass, __traits(classInstanceSize, UshrAssignExp), e1, e2);
        }
    }

    extern (C++) final class CatAssignExp : BinAssignExp
    {
        extern (D) this(Loc loc, Expression e1, Expression e2)
        {
            super(loc, TOKcatass, __traits(classInstanceSize, CatAssignExp), e1, e2);
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
        abstract TemplateParameter syntaxCopy();
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
    }

    extern (C++) final class TemplateTupleParameter : TemplateParameter
    {
        extern (D) this(Loc loc, Identifier ident)
        {
            super(loc, ident);
            this.ident = ident;
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
    }

    extern (C++) final class TemplateThisParameter : TemplateTypeParameter
    {
        extern (D) this(Loc loc, Identifier ident, Type specType, Type defaultType)
        {
            super(loc, ident, specType, defaultType);
        }
    }

    extern (C++) abstract class Condition : RootObject
    {
        Loc loc;

        final extern (D) this(Loc loc)
        {
            this.loc = loc;
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
    }

    extern (C++) final class DebugCondition : DVCondition
    {
        extern (D) this(Module mod, uint level, Identifier ident)
        {
            super(mod, level, ident);
        }
    }

    extern (C++) final class VersionCondition : DVCondition
    {
        extern (D) this(Module mod, uint level, Identifier ident)
        {
            super(mod, level, ident);
        }
    }

    extern (C++) class Initializer : RootObject
    {
        Loc loc;

        final extern (D) this(Loc loc)
        {
            this.loc = loc;
        }

        Expression toExpression(Type t = null)
        {
            return null;
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
    }

    extern (C++) final class StructInitializer : Initializer
    {
        extern (D) this(Loc loc)
        {
            super(loc);
        }

        void addInit(Identifier id, Initializer init) {}
    }

    extern (C++) final class ArrayInitializer : Initializer
    {
        extern (D) this(Loc loc)
        {
            super(loc);
        }

        void addInit(Expression e, Initializer i) {}
    }

    extern (C++) final class VoidInitializer : Initializer
    {
        extern (D) this(Loc loc)
        {
            super(loc);
        }
    }

    struct BaseClass
    {
        Type t;
    }

    struct ModuleDeclaration
    {
        Identifier id;
        Identifiers *packages;

        extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e) {}

        extern (C++) const(char)* toChars()
        {
            return "";
        }
    }

    struct Prot
    {
        PROTKIND kind;
        Package pkg;
    }

    extern (C++) static const(char)* protectionToChars(PROTKIND kind)
    {
        return null;
    }

    extern (C++) static bool stcToBuffer(A, B)(A a, B b)
    {
        return false;
    }

    extern (C++) static bool linkageToChars(A)(A a)
    {
        return false;
    }

    struct Target
    {
        extern (C++) static __gshared int ptrsize;
    }

}
