/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _tokens.d)
 */

module ddmd.tokens;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import ddmd.globals;
import ddmd.identifier;
import ddmd.root.ctfloat;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.utf;

enum TOK : int
{
    TOKreserved,

    // Other
    TOKlparen,
    TOKrparen,
    TOKlbracket,
    TOKrbracket,
    TOKlcurly,
    TOKrcurly,
    TOKcolon,
    TOKneg,
    TOKsemicolon,
    TOKdotdotdot,
    TOKeof,
    TOKcast,
    TOKnull,
    TOKassert,
    TOKtrue,
    TOKfalse,
    TOKarray,
    TOKcall,
    TOKaddress,
    TOKtype,
    TOKthrow,
    TOKnew,
    TOKdelete,
    TOKstar,
    TOKsymoff,
    TOKvar,
    TOKdotvar,
    TOKdotid,
    TOKdotti,
    TOKdottype,
    TOKslice,
    TOKarraylength,
    TOKversion,
    TOKmodule,
    TOKdollar,
    TOKtemplate,
    TOKdottd,
    TOKdeclaration,
    TOKtypeof,
    TOKpragma,
    TOKdsymbol,
    TOKtypeid,
    TOKuadd,
    TOKremove,
    TOKnewanonclass,
    TOKcomment,
    TOKarrayliteral,
    TOKassocarrayliteral,
    TOKstructliteral,
    TOKclassreference,
    TOKthrownexception,
    TOKdelegateptr,
    TOKdelegatefuncptr,

    // 54
    // Operators
    TOKlt,
    TOKgt,
    TOKle,
    TOKge,
    TOKequal,
    TOKnotequal,
    TOKidentity,
    TOKnotidentity,
    TOKindex,
    TOKis,

    // 64
    // NCEG floating point compares
    // !<>=     <>    <>=    !>     !>=   !<     !<=   !<>
    TOKunord,
    TOKlg,
    TOKleg,
    TOKule,
    TOKul,
    TOKuge,
    TOKug,
    TOKue,

    // 72
    TOKshl,
    TOKshr,
    TOKshlass,
    TOKshrass,
    TOKushr,
    TOKushrass,
    TOKcat,
    TOKcatass, // ~ ~=
    TOKadd,
    TOKmin,
    TOKaddass,
    TOKminass,
    TOKmul,
    TOKdiv,
    TOKmod,
    TOKmulass,
    TOKdivass,
    TOKmodass,
    TOKand,
    TOKor,
    TOKxor,
    TOKandass,
    TOKorass,
    TOKxorass,
    TOKassign,
    TOKnot,
    TOKtilde,
    TOKplusplus,
    TOKminusminus,
    TOKconstruct,
    TOKblit,
    TOKdot,
    TOKarrow,
    TOKcomma,
    TOKquestion,
    TOKandand,
    TOKoror,
    TOKpreplusplus,
    TOKpreminusminus,

    // 111
    // Numeric literals
    TOKint32v,
    TOKuns32v,
    TOKint64v,
    TOKuns64v,
    TOKint128v,
    TOKuns128v,
    TOKfloat32v,
    TOKfloat64v,
    TOKfloat80v,
    TOKimaginary32v,
    TOKimaginary64v,
    TOKimaginary80v,

    // 123
    // Char constants
    TOKcharv,
    TOKwcharv,
    TOKdcharv,

    // 126
    // Leaf operators
    TOKidentifier,
    TOKstring,
    TOKxstring,
    TOKthis,
    TOKsuper,
    TOKhalt,
    TOKtuple,
    TOKerror,

    // 134
    // Basic types
    TOKvoid,
    TOKint8,
    TOKuns8,
    TOKint16,
    TOKuns16,
    TOKint32,
    TOKuns32,
    TOKint64,
    TOKuns64,
    TOKint128,
    TOKuns128,
    TOKfloat32,
    TOKfloat64,
    TOKfloat80,
    TOKimaginary32,
    TOKimaginary64,
    TOKimaginary80,
    TOKcomplex32,
    TOKcomplex64,
    TOKcomplex80,
    TOKchar,
    TOKwchar,
    TOKdchar,
    TOKbool,

    // 158
    // Aggregates
    TOKstruct,
    TOKclass,
    TOKinterface,
    TOKunion,
    TOKenum,
    TOKimport,
    TOKalias,
    TOKoverride,
    TOKdelegate,
    TOKfunction,
    TOKmixin,
    TOKalign,
    TOKextern,
    TOKprivate,
    TOKprotected,
    TOKpublic,
    TOKexport,
    TOKstatic,
    TOKfinal,
    TOKconst,
    TOKabstract,
    TOKdebug,
    TOKdeprecated,
    TOKin,
    TOKout,
    TOKinout,
    TOKlazy,
    TOKauto,
    TOKpackage,
    TOKmanifest,
    TOKimmutable,

    // 189
    // Statements
    TOKif,
    TOKelse,
    TOKwhile,
    TOKfor,
    TOKdo,
    TOKswitch,
    TOKcase,
    TOKdefault,
    TOKbreak,
    TOKcontinue,
    TOKwith,
    TOKsynchronized,
    TOKreturn,
    TOKgoto,
    TOKtry,
    TOKcatch,
    TOKfinally,
    TOKasm,
    TOKforeach,
    TOKforeach_reverse,
    TOKscope,
    TOKon_scope_exit,
    TOKon_scope_failure,
    TOKon_scope_success,

    // 213
    // Contracts
    TOKinvariant,

    // Testing
    TOKunittest,

    // Added after 1.0
    TOKargTypes,
    TOKref,
    TOKmacro,

    // 219
    TOKparameters,
    TOKtraits,
    TOKoverloadset,
    TOKpure,
    TOKnothrow,
    TOKgshared,
    TOKline,
    TOKfile,
    TOKfilefullpath,
    TOKmodulestring,
    TOKfuncstring,
    TOKprettyfunc,
    TOKshared,
    TOKat,
    TOKpow,
    TOKpowass,
    TOKgoesto,
    TOKvector,
    TOKpound,

    // 237
    TOKinterval,
    TOKvoidexp,
    TOKcantexp,

    TOKMAX,
}

alias TOKreserved = TOK.TOKreserved;
alias TOKlparen = TOK.TOKlparen;
alias TOKrparen = TOK.TOKrparen;
alias TOKlbracket = TOK.TOKlbracket;
alias TOKrbracket = TOK.TOKrbracket;
alias TOKlcurly = TOK.TOKlcurly;
alias TOKrcurly = TOK.TOKrcurly;
alias TOKcolon = TOK.TOKcolon;
alias TOKneg = TOK.TOKneg;
alias TOKsemicolon = TOK.TOKsemicolon;
alias TOKdotdotdot = TOK.TOKdotdotdot;
alias TOKeof = TOK.TOKeof;
alias TOKcast = TOK.TOKcast;
alias TOKnull = TOK.TOKnull;
alias TOKassert = TOK.TOKassert;
alias TOKtrue = TOK.TOKtrue;
alias TOKfalse = TOK.TOKfalse;
alias TOKarray = TOK.TOKarray;
alias TOKcall = TOK.TOKcall;
alias TOKaddress = TOK.TOKaddress;
alias TOKtype = TOK.TOKtype;
alias TOKthrow = TOK.TOKthrow;
alias TOKnew = TOK.TOKnew;
alias TOKdelete = TOK.TOKdelete;
alias TOKstar = TOK.TOKstar;
alias TOKsymoff = TOK.TOKsymoff;
alias TOKvar = TOK.TOKvar;
alias TOKdotvar = TOK.TOKdotvar;
alias TOKdotid = TOK.TOKdotid;
alias TOKdotti = TOK.TOKdotti;
alias TOKdottype = TOK.TOKdottype;
alias TOKslice = TOK.TOKslice;
alias TOKarraylength = TOK.TOKarraylength;
alias TOKversion = TOK.TOKversion;
alias TOKmodule = TOK.TOKmodule;
alias TOKdollar = TOK.TOKdollar;
alias TOKtemplate = TOK.TOKtemplate;
alias TOKdottd = TOK.TOKdottd;
alias TOKdeclaration = TOK.TOKdeclaration;
alias TOKtypeof = TOK.TOKtypeof;
alias TOKpragma = TOK.TOKpragma;
alias TOKdsymbol = TOK.TOKdsymbol;
alias TOKtypeid = TOK.TOKtypeid;
alias TOKuadd = TOK.TOKuadd;
alias TOKremove = TOK.TOKremove;
alias TOKnewanonclass = TOK.TOKnewanonclass;
alias TOKcomment = TOK.TOKcomment;
alias TOKarrayliteral = TOK.TOKarrayliteral;
alias TOKassocarrayliteral = TOK.TOKassocarrayliteral;
alias TOKstructliteral = TOK.TOKstructliteral;
alias TOKclassreference = TOK.TOKclassreference;
alias TOKthrownexception = TOK.TOKthrownexception;
alias TOKdelegateptr = TOK.TOKdelegateptr;
alias TOKdelegatefuncptr = TOK.TOKdelegatefuncptr;
alias TOKlt = TOK.TOKlt;
alias TOKgt = TOK.TOKgt;
alias TOKle = TOK.TOKle;
alias TOKge = TOK.TOKge;
alias TOKequal = TOK.TOKequal;
alias TOKnotequal = TOK.TOKnotequal;
alias TOKidentity = TOK.TOKidentity;
alias TOKnotidentity = TOK.TOKnotidentity;
alias TOKindex = TOK.TOKindex;
alias TOKis = TOK.TOKis;
alias TOKunord = TOK.TOKunord;
alias TOKlg = TOK.TOKlg;
alias TOKleg = TOK.TOKleg;
alias TOKule = TOK.TOKule;
alias TOKul = TOK.TOKul;
alias TOKuge = TOK.TOKuge;
alias TOKug = TOK.TOKug;
alias TOKue = TOK.TOKue;
alias TOKshl = TOK.TOKshl;
alias TOKshr = TOK.TOKshr;
alias TOKshlass = TOK.TOKshlass;
alias TOKshrass = TOK.TOKshrass;
alias TOKushr = TOK.TOKushr;
alias TOKushrass = TOK.TOKushrass;
alias TOKcat = TOK.TOKcat;
alias TOKcatass = TOK.TOKcatass;
alias TOKadd = TOK.TOKadd;
alias TOKmin = TOK.TOKmin;
alias TOKaddass = TOK.TOKaddass;
alias TOKminass = TOK.TOKminass;
alias TOKmul = TOK.TOKmul;
alias TOKdiv = TOK.TOKdiv;
alias TOKmod = TOK.TOKmod;
alias TOKmulass = TOK.TOKmulass;
alias TOKdivass = TOK.TOKdivass;
alias TOKmodass = TOK.TOKmodass;
alias TOKand = TOK.TOKand;
alias TOKor = TOK.TOKor;
alias TOKxor = TOK.TOKxor;
alias TOKandass = TOK.TOKandass;
alias TOKorass = TOK.TOKorass;
alias TOKxorass = TOK.TOKxorass;
alias TOKassign = TOK.TOKassign;
alias TOKnot = TOK.TOKnot;
alias TOKtilde = TOK.TOKtilde;
alias TOKplusplus = TOK.TOKplusplus;
alias TOKminusminus = TOK.TOKminusminus;
alias TOKconstruct = TOK.TOKconstruct;
alias TOKblit = TOK.TOKblit;
alias TOKdot = TOK.TOKdot;
alias TOKarrow = TOK.TOKarrow;
alias TOKcomma = TOK.TOKcomma;
alias TOKquestion = TOK.TOKquestion;
alias TOKandand = TOK.TOKandand;
alias TOKoror = TOK.TOKoror;
alias TOKpreplusplus = TOK.TOKpreplusplus;
alias TOKpreminusminus = TOK.TOKpreminusminus;
alias TOKint32v = TOK.TOKint32v;
alias TOKuns32v = TOK.TOKuns32v;
alias TOKint64v = TOK.TOKint64v;
alias TOKuns64v = TOK.TOKuns64v;
alias TOKint128v = TOK.TOKint128v;
alias TOKuns128v = TOK.TOKuns128v;
alias TOKfloat32v = TOK.TOKfloat32v;
alias TOKfloat64v = TOK.TOKfloat64v;
alias TOKfloat80v = TOK.TOKfloat80v;
alias TOKimaginary32v = TOK.TOKimaginary32v;
alias TOKimaginary64v = TOK.TOKimaginary64v;
alias TOKimaginary80v = TOK.TOKimaginary80v;
alias TOKcharv = TOK.TOKcharv;
alias TOKwcharv = TOK.TOKwcharv;
alias TOKdcharv = TOK.TOKdcharv;
alias TOKidentifier = TOK.TOKidentifier;
alias TOKstring = TOK.TOKstring;
alias TOKxstring = TOK.TOKxstring;
alias TOKthis = TOK.TOKthis;
alias TOKsuper = TOK.TOKsuper;
alias TOKhalt = TOK.TOKhalt;
alias TOKtuple = TOK.TOKtuple;
alias TOKerror = TOK.TOKerror;
alias TOKvoid = TOK.TOKvoid;
alias TOKint8 = TOK.TOKint8;
alias TOKuns8 = TOK.TOKuns8;
alias TOKint16 = TOK.TOKint16;
alias TOKuns16 = TOK.TOKuns16;
alias TOKint32 = TOK.TOKint32;
alias TOKuns32 = TOK.TOKuns32;
alias TOKint64 = TOK.TOKint64;
alias TOKuns64 = TOK.TOKuns64;
alias TOKint128 = TOK.TOKint128;
alias TOKuns128 = TOK.TOKuns128;
alias TOKfloat32 = TOK.TOKfloat32;
alias TOKfloat64 = TOK.TOKfloat64;
alias TOKfloat80 = TOK.TOKfloat80;
alias TOKimaginary32 = TOK.TOKimaginary32;
alias TOKimaginary64 = TOK.TOKimaginary64;
alias TOKimaginary80 = TOK.TOKimaginary80;
alias TOKcomplex32 = TOK.TOKcomplex32;
alias TOKcomplex64 = TOK.TOKcomplex64;
alias TOKcomplex80 = TOK.TOKcomplex80;
alias TOKchar = TOK.TOKchar;
alias TOKwchar = TOK.TOKwchar;
alias TOKdchar = TOK.TOKdchar;
alias TOKbool = TOK.TOKbool;
alias TOKstruct = TOK.TOKstruct;
alias TOKclass = TOK.TOKclass;
alias TOKinterface = TOK.TOKinterface;
alias TOKunion = TOK.TOKunion;
alias TOKenum = TOK.TOKenum;
alias TOKimport = TOK.TOKimport;
alias TOKalias = TOK.TOKalias;
alias TOKoverride = TOK.TOKoverride;
alias TOKdelegate = TOK.TOKdelegate;
alias TOKfunction = TOK.TOKfunction;
alias TOKmixin = TOK.TOKmixin;
alias TOKalign = TOK.TOKalign;
alias TOKextern = TOK.TOKextern;
alias TOKprivate = TOK.TOKprivate;
alias TOKprotected = TOK.TOKprotected;
alias TOKpublic = TOK.TOKpublic;
alias TOKexport = TOK.TOKexport;
alias TOKstatic = TOK.TOKstatic;
alias TOKfinal = TOK.TOKfinal;
alias TOKconst = TOK.TOKconst;
alias TOKabstract = TOK.TOKabstract;
alias TOKdebug = TOK.TOKdebug;
alias TOKdeprecated = TOK.TOKdeprecated;
alias TOKin = TOK.TOKin;
alias TOKout = TOK.TOKout;
alias TOKinout = TOK.TOKinout;
alias TOKlazy = TOK.TOKlazy;
alias TOKauto = TOK.TOKauto;
alias TOKpackage = TOK.TOKpackage;
alias TOKmanifest = TOK.TOKmanifest;
alias TOKimmutable = TOK.TOKimmutable;
alias TOKif = TOK.TOKif;
alias TOKelse = TOK.TOKelse;
alias TOKwhile = TOK.TOKwhile;
alias TOKfor = TOK.TOKfor;
alias TOKdo = TOK.TOKdo;
alias TOKswitch = TOK.TOKswitch;
alias TOKcase = TOK.TOKcase;
alias TOKdefault = TOK.TOKdefault;
alias TOKbreak = TOK.TOKbreak;
alias TOKcontinue = TOK.TOKcontinue;
alias TOKwith = TOK.TOKwith;
alias TOKsynchronized = TOK.TOKsynchronized;
alias TOKreturn = TOK.TOKreturn;
alias TOKgoto = TOK.TOKgoto;
alias TOKtry = TOK.TOKtry;
alias TOKcatch = TOK.TOKcatch;
alias TOKfinally = TOK.TOKfinally;
alias TOKasm = TOK.TOKasm;
alias TOKforeach = TOK.TOKforeach;
alias TOKforeach_reverse = TOK.TOKforeach_reverse;
alias TOKscope = TOK.TOKscope;
alias TOKon_scope_exit = TOK.TOKon_scope_exit;
alias TOKon_scope_failure = TOK.TOKon_scope_failure;
alias TOKon_scope_success = TOK.TOKon_scope_success;
alias TOKinvariant = TOK.TOKinvariant;
alias TOKunittest = TOK.TOKunittest;
alias TOKargTypes = TOK.TOKargTypes;
alias TOKref = TOK.TOKref;
alias TOKmacro = TOK.TOKmacro;
alias TOKparameters = TOK.TOKparameters;
alias TOKtraits = TOK.TOKtraits;
alias TOKoverloadset = TOK.TOKoverloadset;
alias TOKpure = TOK.TOKpure;
alias TOKnothrow = TOK.TOKnothrow;
alias TOKgshared = TOK.TOKgshared;
alias TOKline = TOK.TOKline;
alias TOKfile = TOK.TOKfile;
alias TOKfilefullpath = TOK.TOKfilefullpath;
alias TOKmodulestring = TOK.TOKmodulestring;
alias TOKfuncstring = TOK.TOKfuncstring;
alias TOKprettyfunc = TOK.TOKprettyfunc;
alias TOKshared = TOK.TOKshared;
alias TOKat = TOK.TOKat;
alias TOKpow = TOK.TOKpow;
alias TOKpowass = TOK.TOKpowass;
alias TOKgoesto = TOK.TOKgoesto;
alias TOKvector = TOK.TOKvector;
alias TOKpound = TOK.TOKpound;
alias TOKinterval = TOK.TOKinterval;
alias TOKvoidexp = TOK.TOKvoidexp;
alias TOKcantexp = TOK.TOKcantexp;

alias TOKMAX = TOK.TOKMAX;

enum TOKwild = TOKinout;

/***********************************************************
 */
extern (C++) struct Token
{
    Token* next;
    Loc loc;
    const(char)* ptr; // pointer to first character of this token within buffer
    TOK value;
    const(char)* blockComment; // doc comment string prior to this token
    const(char)* lineComment; // doc comment for previous token

    union
    {
        // Integers
        d_int64 int64value;
        d_uns64 uns64value;
        // Floats
        real_t floatvalue;

        struct
        {
            const(char)* ustring; // UTF8 string
            uint len;
            ubyte postfix; // 'c', 'w', 'd'
        }

        Identifier ident;
    }

    extern (D) private __gshared immutable string[TOKMAX] tochars =
    [
        // Keywords
        TOKthis: "this",
        TOKsuper: "super",
        TOKassert: "assert",
        TOKnull: "null",
        TOKtrue: "true",
        TOKfalse: "false",
        TOKcast: "cast",
        TOKnew: "new",
        TOKdelete: "delete",
        TOKthrow: "throw",
        TOKmodule: "module",
        TOKpragma: "pragma",
        TOKtypeof: "typeof",
        TOKtypeid: "typeid",
        TOKtemplate: "template",
        TOKvoid: "void",
        TOKint8: "byte",
        TOKuns8: "ubyte",
        TOKint16: "short",
        TOKuns16: "ushort",
        TOKint32: "int",
        TOKuns32: "uint",
        TOKint64: "long",
        TOKuns64: "ulong",
        TOKint128: "cent",
        TOKuns128: "ucent",
        TOKfloat32: "float",
        TOKfloat64: "double",
        TOKfloat80: "real",
        TOKbool: "bool",
        TOKchar: "char",
        TOKwchar: "wchar",
        TOKdchar: "dchar",
        TOKimaginary32: "ifloat",
        TOKimaginary64: "idouble",
        TOKimaginary80: "ireal",
        TOKcomplex32: "cfloat",
        TOKcomplex64: "cdouble",
        TOKcomplex80: "creal",
        TOKdelegate: "delegate",
        TOKfunction: "function",
        TOKis: "is",
        TOKif: "if",
        TOKelse: "else",
        TOKwhile: "while",
        TOKfor: "for",
        TOKdo: "do",
        TOKswitch: "switch",
        TOKcase: "case",
        TOKdefault: "default",
        TOKbreak: "break",
        TOKcontinue: "continue",
        TOKsynchronized: "synchronized",
        TOKreturn: "return",
        TOKgoto: "goto",
        TOKtry: "try",
        TOKcatch: "catch",
        TOKfinally: "finally",
        TOKwith: "with",
        TOKasm: "asm",
        TOKforeach: "foreach",
        TOKforeach_reverse: "foreach_reverse",
        TOKscope: "scope",
        TOKstruct: "struct",
        TOKclass: "class",
        TOKinterface: "interface",
        TOKunion: "union",
        TOKenum: "enum",
        TOKimport: "import",
        TOKmixin: "mixin",
        TOKstatic: "static",
        TOKfinal: "final",
        TOKconst: "const",
        TOKalias: "alias",
        TOKoverride: "override",
        TOKabstract: "abstract",
        TOKdebug: "debug",
        TOKdeprecated: "deprecated",
        TOKin: "in",
        TOKout: "out",
        TOKinout: "inout",
        TOKlazy: "lazy",
        TOKauto: "auto",
        TOKalign: "align",
        TOKextern: "extern",
        TOKprivate: "private",
        TOKpackage: "package",
        TOKprotected: "protected",
        TOKpublic: "public",
        TOKexport: "export",
        TOKinvariant: "invariant",
        TOKunittest: "unittest",
        TOKversion: "version",
        TOKargTypes: "__argTypes",
        TOKparameters: "__parameters",
        TOKref: "ref",
        TOKmacro: "macro",
        TOKpure: "pure",
        TOKnothrow: "nothrow",
        TOKgshared: "__gshared",
        TOKtraits: "__traits",
        TOKvector: "__vector",
        TOKoverloadset: "__overloadset",
        TOKfile: "__FILE__",
        TOKfilefullpath: "__FILE_FULL_PATH__",
        TOKline: "__LINE__",
        TOKmodulestring: "__MODULE__",
        TOKfuncstring: "__FUNCTION__",
        TOKprettyfunc: "__PRETTY_FUNCTION__",
        TOKshared: "shared",
        TOKimmutable: "immutable",

        TOKeof: "EOF",
        TOKlcurly: "{",
        TOKrcurly: "}",
        TOKlparen: "(",
        TOKrparen: ")",
        TOKlbracket: "[",
        TOKrbracket: "]",
        TOKsemicolon: ";",
        TOKcolon: ":",
        TOKcomma: ",",
        TOKdot: ".",
        TOKxor: "^",
        TOKxorass: "^=",
        TOKassign: "=",
        TOKconstruct: "=",
        TOKblit: "=",
        TOKlt: "<",
        TOKgt: ">",
        TOKle: "<=",
        TOKge: ">=",
        TOKequal: "==",
        TOKnotequal: "!=",
        TOKunord: "!<>=",
        TOKue: "!<>",
        TOKlg: "<>",
        TOKleg: "<>=",
        TOKule: "!>",
        TOKul: "!>=",
        TOKuge: "!<",
        TOKug: "!<=",
        TOKnot: "!",
        TOKshl: "<<",
        TOKshr: ">>",
        TOKushr: ">>>",
        TOKadd: "+",
        TOKmin: "-",
        TOKmul: "*",
        TOKdiv: "/",
        TOKmod: "%",
        TOKslice: "..",
        TOKdotdotdot: "...",
        TOKand: "&",
        TOKandand: "&&",
        TOKor: "|",
        TOKoror: "||",
        TOKarray: "[]",
        TOKindex: "[i]",
        TOKaddress: "&",
        TOKstar: "*",
        TOKtilde: "~",
        TOKdollar: "$",
        TOKplusplus: "++",
        TOKminusminus: "--",
        TOKpreplusplus: "++",
        TOKpreminusminus: "--",
        TOKtype: "type",
        TOKquestion: "?",
        TOKneg: "-",
        TOKuadd: "+",
        TOKvar: "var",
        TOKaddass: "+=",
        TOKminass: "-=",
        TOKmulass: "*=",
        TOKdivass: "/=",
        TOKmodass: "%=",
        TOKshlass: "<<=",
        TOKshrass: ">>=",
        TOKushrass: ">>>=",
        TOKandass: "&=",
        TOKorass: "|=",
        TOKcatass: "~=",
        TOKcat: "~",
        TOKcall: "call",
        TOKidentity: "is",
        TOKnotidentity: "!is",
        TOKidentifier: "identifier",
        TOKat: "@",
        TOKpow: "^^",
        TOKpowass: "^^=",
        TOKgoesto: "=>",
        TOKpound: "#",

        // For debugging
        TOKerror: "error",
        TOKdotid: "dotid",
        TOKdottd: "dottd",
        TOKdotti: "dotti",
        TOKdotvar: "dotvar",
        TOKdottype: "dottype",
        TOKsymoff: "symoff",
        TOKarraylength: "arraylength",
        TOKarrayliteral: "arrayliteral",
        TOKassocarrayliteral: "assocarrayliteral",
        TOKstructliteral: "structliteral",
        TOKstring: "string",
        TOKdsymbol: "symbol",
        TOKtuple: "tuple",
        TOKdeclaration: "declaration",
        TOKon_scope_exit: "scope(exit)",
        TOKon_scope_success: "scope(success)",
        TOKon_scope_failure: "scope(failure)",
        TOKdelegateptr: "delegateptr",

        // Finish up
        TOKreserved: "reserved",
        TOKremove: "remove",
        TOKnewanonclass: "newanonclass",
        TOKcomment: "comment",
        TOKclassreference: "classreference",
        TOKthrownexception: "thrownexception",
        TOKdelegatefuncptr: "delegatefuncptr",
        TOKarrow: "arrow",
        TOKint32v: "int32v",
        TOKuns32v: "uns32v",
        TOKint64v: "int64v",
        TOKuns64v: "uns64v",
        TOKint128v: "int128v",
        TOKuns128v: "uns128v",
        TOKfloat32v: "float32v",
        TOKfloat64v: "float64v",
        TOKfloat80v: "float80v",
        TOKimaginary32v: "imaginary32v",
        TOKimaginary64v: "imaginary64v",
        TOKimaginary80v: "imaginary80v",
        TOKcharv: "charv",
        TOKwcharv: "wcharv",
        TOKdcharv: "dcharv",

        TOKhalt: "halt",
        TOKxstring: "xstring",
        TOKmanifest: "manifest",

        TOKinterval: "interval",
        TOKvoidexp: "voidexp",
        TOKcantexp: "cantexp",
    ];

    static assert(() {
        foreach (s; tochars)
            assert(s.length);
        return true;
    }());

    static this()
    {
        Identifier.initTable();
        foreach (kw; keywords)
        {
            //printf("keyword[%d] = '%s'\n",kw, tochars[kw].ptr);
            Identifier.idPool(tochars[kw].ptr, tochars[kw].length, cast(uint)kw);
        }
    }

    __gshared Token* freelist = null;

    static Token* alloc()
    {
        if (Token.freelist)
        {
            Token* t = freelist;
            freelist = t.next;
            t.next = null;
            return t;
        }
        return new Token();
    }

    void free()
    {
        next = freelist;
        freelist = &this;
    }

    int isKeyword() const
    {
        foreach (kw; keywords)
        {
            if (kw == value)
                return 1;
        }
        return 0;
    }

    debug
    {
        void print()
        {
            fprintf(stderr, "%s\n", toChars());
        }
    }

    /****
     * Set to contents of ptr[0..length]
     * Params:
     *  ptr = pointer to string
     *  length = length of string
     */
    final void setString(const(char)* ptr, size_t length)
    {
        auto s = cast(char*)mem.xmalloc(length + 1);
        memcpy(s, ptr, length);
        s[length] = 0;
        ustring = s;
        len = cast(uint)length;
        postfix = 0;
    }

    /****
     * Set to contents of buf
     * Params:
     *  buf = string (not zero terminated)
     */
    final void setString(const ref OutBuffer buf)
    {
        setString(cast(const(char)*)buf.data, buf.offset);
    }

    /****
     * Set to empty string
     */
    final void setString()
    {
        ustring = "";
        len = 0;
        postfix = 0;
    }

    extern (C++) const(char)* toChars() const
    {
        __gshared char[3 + 3 * floatvalue.sizeof + 1] buffer;
        const(char)* p = &buffer[0];
        switch (value)
        {
        case TOKint32v:
            sprintf(&buffer[0], "%d", cast(d_int32)int64value);
            break;
        case TOKuns32v:
        case TOKcharv:
        case TOKwcharv:
        case TOKdcharv:
            sprintf(&buffer[0], "%uU", cast(d_uns32)uns64value);
            break;
        case TOKint64v:
            sprintf(&buffer[0], "%lldL", cast(long)int64value);
            break;
        case TOKuns64v:
            sprintf(&buffer[0], "%lluUL", cast(ulong)uns64value);
            break;
        case TOKfloat32v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "f");
            break;
        case TOKfloat64v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            break;
        case TOKfloat80v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "L");
            break;
        case TOKimaginary32v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "fi");
            break;
        case TOKimaginary64v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "i");
            break;
        case TOKimaginary80v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "Li");
            break;
        case TOKstring:
            {
                OutBuffer buf;
                buf.writeByte('"');
                for (size_t i = 0; i < len;)
                {
                    dchar c;
                    utf_decodeChar(ustring, len, i, c);
                    switch (c)
                    {
                    case 0:
                        break;
                    case '"':
                    case '\\':
                        buf.writeByte('\\');
                        goto default;
                    default:
                        if (c <= 0x7F)
                        {
                            if (isprint(c))
                                buf.writeByte(c);
                            else
                                buf.printf("\\x%02x", c);
                        }
                        else if (c <= 0xFFFF)
                            buf.printf("\\u%04x", c);
                        else
                            buf.printf("\\U%08x", c);
                        continue;
                    }
                    break;
                }
                buf.writeByte('"');
                if (postfix)
                    buf.writeByte(postfix);
                p = buf.extractString();
            }
            break;
        case TOKxstring:
            {
                OutBuffer buf;
                buf.writeByte('x');
                buf.writeByte('"');
                foreach (size_t i; 0 .. len)
                {
                    if (i)
                        buf.writeByte(' ');
                    buf.printf("%02x", ustring[i]);
                }
                buf.writeByte('"');
                if (postfix)
                    buf.writeByte(postfix);
                buf.writeByte(0);
                p = buf.extractData();
                break;
            }
        case TOKidentifier:
        case TOKenum:
        case TOKstruct:
        case TOKimport:
        case TOKwchar:
        case TOKdchar:
        case TOKbool:
        case TOKchar:
        case TOKint8:
        case TOKuns8:
        case TOKint16:
        case TOKuns16:
        case TOKint32:
        case TOKuns32:
        case TOKint64:
        case TOKuns64:
        case TOKint128:
        case TOKuns128:
        case TOKfloat32:
        case TOKfloat64:
        case TOKfloat80:
        case TOKimaginary32:
        case TOKimaginary64:
        case TOKimaginary80:
        case TOKcomplex32:
        case TOKcomplex64:
        case TOKcomplex80:
        case TOKvoid:
            p = ident.toChars();
            break;
        default:
            p = toChars(value);
            break;
        }
        return p;
    }

    static const(char)* toChars(TOK value)
    {
        return toString(value).ptr;
    }

    extern (D) static string toString(TOK value) pure nothrow @nogc @safe
    {
        return tochars[value];
    }
}

/****************************************
 */

private immutable TOK[] keywords =
[
    TOKthis,
    TOKsuper,
    TOKassert,
    TOKnull,
    TOKtrue,
    TOKfalse,
    TOKcast,
    TOKnew,
    TOKdelete,
    TOKthrow,
    TOKmodule,
    TOKpragma,
    TOKtypeof,
    TOKtypeid,
    TOKtemplate,
    TOKvoid,
    TOKint8,
    TOKuns8,
    TOKint16,
    TOKuns16,
    TOKint32,
    TOKuns32,
    TOKint64,
    TOKuns64,
    TOKint128,
    TOKuns128,
    TOKfloat32,
    TOKfloat64,
    TOKfloat80,
    TOKbool,
    TOKchar,
    TOKwchar,
    TOKdchar,
    TOKimaginary32,
    TOKimaginary64,
    TOKimaginary80,
    TOKcomplex32,
    TOKcomplex64,
    TOKcomplex80,
    TOKdelegate,
    TOKfunction,
    TOKis,
    TOKif,
    TOKelse,
    TOKwhile,
    TOKfor,
    TOKdo,
    TOKswitch,
    TOKcase,
    TOKdefault,
    TOKbreak,
    TOKcontinue,
    TOKsynchronized,
    TOKreturn,
    TOKgoto,
    TOKtry,
    TOKcatch,
    TOKfinally,
    TOKwith,
    TOKasm,
    TOKforeach,
    TOKforeach_reverse,
    TOKscope,
    TOKstruct,
    TOKclass,
    TOKinterface,
    TOKunion,
    TOKenum,
    TOKimport,
    TOKmixin,
    TOKstatic,
    TOKfinal,
    TOKconst,
    TOKalias,
    TOKoverride,
    TOKabstract,
    TOKdebug,
    TOKdeprecated,
    TOKin,
    TOKout,
    TOKinout,
    TOKlazy,
    TOKauto,
    TOKalign,
    TOKextern,
    TOKprivate,
    TOKpackage,
    TOKprotected,
    TOKpublic,
    TOKexport,
    TOKinvariant,
    TOKunittest,
    TOKversion,
    TOKargTypes,
    TOKparameters,
    TOKref,
    TOKmacro,
    TOKpure,
    TOKnothrow,
    TOKgshared,
    TOKtraits,
    TOKvector,
    TOKoverloadset,
    TOKfile,
    TOKfilefullpath,
    TOKline,
    TOKmodulestring,
    TOKfuncstring,
    TOKprettyfunc,
    TOKshared,
    TOKimmutable,
];
