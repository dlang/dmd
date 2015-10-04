// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.tokens;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.root.port;
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
    TOKdotti,
    TOKdotexp,
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
    TOKtobool,

    // 65
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

    // 73
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

    // 112
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

    // Char constants
    TOKcharv,
    TOKwcharv,
    TOKdcharv,

    // Leaf operators
    TOKidentifier,
    TOKstring,
    TOKxstring,
    TOKthis,
    TOKsuper,
    TOKhalt,
    TOKtuple,
    TOKerror,

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

    // 159
    // Aggregates
    TOKstruct,
    TOKclass,
    TOKinterface,
    TOKunion,
    TOKenum,
    TOKimport,
    TOKtypedef,
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
    TOKvolatile,
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

    // Contracts
    TOKbody,
    TOKinvariant,

    // Testing
    TOKunittest,

    // Added after 1.0
    TOKargTypes,
    TOKref,
    TOKmacro,
    TOKparameters,
    TOKtraits,
    TOKoverloadset,
    TOKpure,
    TOKnothrow,
    TOKgshared,
    TOKline,
    TOKfile,
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
alias TOKdotti = TOK.TOKdotti;
alias TOKdotexp = TOK.TOKdotexp;
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
alias TOKtobool = TOK.TOKtobool;
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
alias TOKtypedef = TOK.TOKtypedef;
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
alias TOKvolatile = TOK.TOKvolatile;
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
alias TOKbody = TOK.TOKbody;
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
        d_float80 float80value;

        struct
        {
            char* ustring; // UTF8 string
            uint len;
            ubyte postfix; // 'c', 'w', 'd'
        }

        Identifier ident;
    }

    static __gshared const(char)*[TOKMAX] tochars;

    static void initTokens()
    {
        foreach (kw; keywords)
        {
            //printf("keyword[%d] = '%s'\n",u, keywords[u].name);
            const(char)* s = kw.name;
            TOK v = kw.value;
            Identifier id = Identifier.idPool(s);
            id.value = v;
            //printf("tochars[%d] = '%s'\n",v, s);
            Token.tochars[v] = s;
        }
        Token.tochars[TOKeof] = "EOF";
        Token.tochars[TOKlcurly] = "{";
        Token.tochars[TOKrcurly] = "}";
        Token.tochars[TOKlparen] = "(";
        Token.tochars[TOKrparen] = ")";
        Token.tochars[TOKlbracket] = "[";
        Token.tochars[TOKrbracket] = "]";
        Token.tochars[TOKsemicolon] = ";";
        Token.tochars[TOKcolon] = ":";
        Token.tochars[TOKcomma] = ",";
        Token.tochars[TOKdot] = ".";
        Token.tochars[TOKxor] = "^";
        Token.tochars[TOKxorass] = "^=";
        Token.tochars[TOKassign] = "=";
        Token.tochars[TOKconstruct] = "=";
        Token.tochars[TOKblit] = "=";
        Token.tochars[TOKlt] = "<";
        Token.tochars[TOKgt] = ">";
        Token.tochars[TOKle] = "<=";
        Token.tochars[TOKge] = ">=";
        Token.tochars[TOKequal] = "==";
        Token.tochars[TOKnotequal] = "!=";
        Token.tochars[TOKnotidentity] = "!is";
        Token.tochars[TOKtobool] = "!!";
        Token.tochars[TOKunord] = "!<>=";
        Token.tochars[TOKue] = "!<>";
        Token.tochars[TOKlg] = "<>";
        Token.tochars[TOKleg] = "<>=";
        Token.tochars[TOKule] = "!>";
        Token.tochars[TOKul] = "!>=";
        Token.tochars[TOKuge] = "!<";
        Token.tochars[TOKug] = "!<=";
        Token.tochars[TOKnot] = "!";
        Token.tochars[TOKtobool] = "!!";
        Token.tochars[TOKshl] = "<<";
        Token.tochars[TOKshr] = ">>";
        Token.tochars[TOKushr] = ">>>";
        Token.tochars[TOKadd] = "+";
        Token.tochars[TOKmin] = "-";
        Token.tochars[TOKmul] = "*";
        Token.tochars[TOKdiv] = "/";
        Token.tochars[TOKmod] = "%";
        Token.tochars[TOKslice] = "..";
        Token.tochars[TOKdotdotdot] = "...";
        Token.tochars[TOKand] = "&";
        Token.tochars[TOKandand] = "&&";
        Token.tochars[TOKor] = "|";
        Token.tochars[TOKoror] = "||";
        Token.tochars[TOKarray] = "[]";
        Token.tochars[TOKindex] = "[i]";
        Token.tochars[TOKaddress] = "&";
        Token.tochars[TOKstar] = "*";
        Token.tochars[TOKtilde] = "~";
        Token.tochars[TOKdollar] = "$";
        Token.tochars[TOKcast] = "cast";
        Token.tochars[TOKplusplus] = "++";
        Token.tochars[TOKminusminus] = "--";
        Token.tochars[TOKpreplusplus] = "++";
        Token.tochars[TOKpreminusminus] = "--";
        Token.tochars[TOKtype] = "type";
        Token.tochars[TOKquestion] = "?";
        Token.tochars[TOKneg] = "-";
        Token.tochars[TOKuadd] = "+";
        Token.tochars[TOKvar] = "var";
        Token.tochars[TOKaddass] = "+=";
        Token.tochars[TOKminass] = "-=";
        Token.tochars[TOKmulass] = "*=";
        Token.tochars[TOKdivass] = "/=";
        Token.tochars[TOKmodass] = "%=";
        Token.tochars[TOKshlass] = "<<=";
        Token.tochars[TOKshrass] = ">>=";
        Token.tochars[TOKushrass] = ">>>=";
        Token.tochars[TOKandass] = "&=";
        Token.tochars[TOKorass] = "|=";
        Token.tochars[TOKcatass] = "~=";
        Token.tochars[TOKcat] = "~";
        Token.tochars[TOKcall] = "call";
        Token.tochars[TOKidentity] = "is";
        Token.tochars[TOKnotidentity] = "!is";
        Token.tochars[TOKorass] = "|=";
        Token.tochars[TOKidentifier] = "identifier";
        Token.tochars[TOKat] = "@";
        Token.tochars[TOKpow] = "^^";
        Token.tochars[TOKpowass] = "^^=";
        Token.tochars[TOKgoesto] = "=>";
        Token.tochars[TOKpound] = "#";
        // For debugging
        Token.tochars[TOKerror] = "error";
        Token.tochars[TOKdotexp] = "dotexp";
        Token.tochars[TOKdotti] = "dotti";
        Token.tochars[TOKdotvar] = "dotvar";
        Token.tochars[TOKdottype] = "dottype";
        Token.tochars[TOKsymoff] = "symoff";
        Token.tochars[TOKarraylength] = "arraylength";
        Token.tochars[TOKarrayliteral] = "arrayliteral";
        Token.tochars[TOKassocarrayliteral] = "assocarrayliteral";
        Token.tochars[TOKstructliteral] = "structliteral";
        Token.tochars[TOKstring] = "string";
        Token.tochars[TOKdsymbol] = "symbol";
        Token.tochars[TOKtuple] = "tuple";
        Token.tochars[TOKdeclaration] = "declaration";
        Token.tochars[TOKdottd] = "dottd";
        Token.tochars[TOKon_scope_exit] = "scope(exit)";
        Token.tochars[TOKon_scope_success] = "scope(success)";
        Token.tochars[TOKon_scope_failure] = "scope(failure)";
    }

    static __gshared Token* freelist = null;

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

    int isKeyword()
    {
        foreach (kw; keywords)
        {
            if (kw.value == value)
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

    extern (C++) const(char)* toChars()
    {
        __gshared char[3 + 3 * float80value.sizeof + 1] buffer;
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
            Port.ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "f");
            break;
        case TOKfloat64v:
            Port.ld_sprint(&buffer[0], 'g', float80value);
            break;
        case TOKfloat80v:
            Port.ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "L");
            break;
        case TOKimaginary32v:
            Port.ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "fi");
            break;
        case TOKimaginary64v:
            Port.ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "i");
            break;
        case TOKimaginary80v:
            Port.ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "Li");
            break;
        case TOKstring:
            {
                OutBuffer buf;
                buf.writeByte('"');
                for (size_t i = 0; i < len;)
                {
                    uint c;
                    utf_decodeChar(cast(char*)ustring, len, &i, &c);
                    switch (c)
                    {
                    case 0:
                        break;
                    case '"':
                    case '\\':
                        buf.writeByte('\\');
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
                p = cast(char*)buf.extractData();
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
        static __gshared char[3 + 3 * value.sizeof + 1] buffer;
        const(char)* p = tochars[value];
        if (!p)
        {
            sprintf(&buffer[0], "TOK%d", value);
            p = &buffer[0];
        }
        return p;
    }
}

/****************************************
 */
struct Keyword
{
    immutable(char)* name;
    TOK value;
}

immutable Keyword[] keywords =
[
    Keyword("this", TOKthis),
    Keyword("super", TOKsuper),
    Keyword("assert", TOKassert),
    Keyword("null", TOKnull),
    Keyword("true", TOKtrue),
    Keyword("false", TOKfalse),
    Keyword("cast", TOKcast),
    Keyword("new", TOKnew),
    Keyword("delete", TOKdelete),
    Keyword("throw", TOKthrow),
    Keyword("module", TOKmodule),
    Keyword("pragma", TOKpragma),
    Keyword("typeof", TOKtypeof),
    Keyword("typeid", TOKtypeid),
    Keyword("template", TOKtemplate),
    Keyword("void", TOKvoid),
    Keyword("byte", TOKint8),
    Keyword("ubyte", TOKuns8),
    Keyword("short", TOKint16),
    Keyword("ushort", TOKuns16),
    Keyword("int", TOKint32),
    Keyword("uint", TOKuns32),
    Keyword("long", TOKint64),
    Keyword("ulong", TOKuns64),
    Keyword("cent", TOKint128),
    Keyword("ucent", TOKuns128),
    Keyword("float", TOKfloat32),
    Keyword("double", TOKfloat64),
    Keyword("real", TOKfloat80),
    Keyword("bool", TOKbool),
    Keyword("char", TOKchar),
    Keyword("wchar", TOKwchar),
    Keyword("dchar", TOKdchar),
    Keyword("ifloat", TOKimaginary32),
    Keyword("idouble", TOKimaginary64),
    Keyword("ireal", TOKimaginary80),
    Keyword("cfloat", TOKcomplex32),
    Keyword("cdouble", TOKcomplex64),
    Keyword("creal", TOKcomplex80),
    Keyword("delegate", TOKdelegate),
    Keyword("function", TOKfunction),
    Keyword("is", TOKis),
    Keyword("if", TOKif),
    Keyword("else", TOKelse),
    Keyword("while", TOKwhile),
    Keyword("for", TOKfor),
    Keyword("do", TOKdo),
    Keyword("switch", TOKswitch),
    Keyword("case", TOKcase),
    Keyword("default", TOKdefault),
    Keyword("break", TOKbreak),
    Keyword("continue", TOKcontinue),
    Keyword("synchronized", TOKsynchronized),
    Keyword("return", TOKreturn),
    Keyword("goto", TOKgoto),
    Keyword("try", TOKtry),
    Keyword("catch", TOKcatch),
    Keyword("finally", TOKfinally),
    Keyword("with", TOKwith),
    Keyword("asm", TOKasm),
    Keyword("foreach", TOKforeach),
    Keyword("foreach_reverse", TOKforeach_reverse),
    Keyword("scope", TOKscope),
    Keyword("struct", TOKstruct),
    Keyword("class", TOKclass),
    Keyword("interface", TOKinterface),
    Keyword("union", TOKunion),
    Keyword("enum", TOKenum),
    Keyword("import", TOKimport),
    Keyword("mixin", TOKmixin),
    Keyword("static", TOKstatic),
    Keyword("final", TOKfinal),
    Keyword("const", TOKconst),
    Keyword("typedef", TOKtypedef),
    Keyword("alias", TOKalias),
    Keyword("override", TOKoverride),
    Keyword("abstract", TOKabstract),
    Keyword("volatile", TOKvolatile),
    Keyword("debug", TOKdebug),
    Keyword("deprecated", TOKdeprecated),
    Keyword("in", TOKin),
    Keyword("out", TOKout),
    Keyword("inout", TOKinout),
    Keyword("lazy", TOKlazy),
    Keyword("auto", TOKauto),
    Keyword("align", TOKalign),
    Keyword("extern", TOKextern),
    Keyword("private", TOKprivate),
    Keyword("package", TOKpackage),
    Keyword("protected", TOKprotected),
    Keyword("public", TOKpublic),
    Keyword("export", TOKexport),
    Keyword("body", TOKbody),
    Keyword("invariant", TOKinvariant),
    Keyword("unittest", TOKunittest),
    Keyword("version", TOKversion),
    Keyword("__argTypes", TOKargTypes),
    Keyword("__parameters", TOKparameters),
    Keyword("ref", TOKref),
    Keyword("macro", TOKmacro),
    Keyword("pure", TOKpure),
    Keyword("nothrow", TOKnothrow),
    Keyword("__gshared", TOKgshared),
    Keyword("__traits", TOKtraits),
    Keyword("__vector", TOKvector),
    Keyword("__overloadset", TOKoverloadset),
    Keyword("__FILE__", TOKfile),
    Keyword("__LINE__", TOKline),
    Keyword("__MODULE__", TOKmodulestring),
    Keyword("__FUNCTION__", TOKfuncstring),
    Keyword("__PRETTY_FUNCTION__", TOKprettyfunc),
    Keyword("shared", TOKshared),
    Keyword("immutable", TOKimmutable),
];
