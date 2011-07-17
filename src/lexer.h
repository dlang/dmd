
// Compiler implementation of the D programming language
// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_LEXER_H
#define DMD_LEXER_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "mars.h"

struct StringTable;
struct Identifier;
struct Module;

/* Tokens:
        (       )
        [       ]
        {       }
        <       >       <=      >=      ==      !=      ===     !==
        <<      >>      <<=     >>=     >>>     >>>=
        +       -       +=      -=
        *       /       %       *=      /=      %=
        &       |       ^       &=      |=      ^=
        =       !       ~       @
        ^^      ^^=
        ++      --
        .       ->      :       ,
        ?       &&      ||
 */

enum TOK
{
        TOKreserved,

        // Other
        TOKlparen,      TOKrparen,
        TOKlbracket,    TOKrbracket,
        TOKlcurly,      TOKrcurly,
        TOKcolon,       TOKneg,
        TOKsemicolon,   TOKdotdotdot,
        TOKeof,         TOKcast,
        TOKnull,        TOKassert,
        TOKtrue,        TOKfalse,
        TOKarray,       TOKcall,
        TOKaddress,
        TOKtype,        TOKthrow,
        TOKnew,         TOKdelete,
        TOKstar,        TOKsymoff,
        TOKvar,         TOKdotvar,
        TOKdotti,       TOKdotexp,
        TOKdottype,     TOKslice,
        TOKarraylength, TOKversion,
        TOKmodule,      TOKdollar,
        TOKtemplate,    TOKdottd,
        TOKdeclaration, TOKtypeof,
        TOKpragma,      TOKdsymbol,
        TOKtypeid,      TOKuadd,
        TOKremove,
        TOKnewanonclass, TOKcomment,
        TOKarrayliteral, TOKassocarrayliteral,
        TOKstructliteral,

        // Operators
        TOKlt,          TOKgt,
        TOKle,          TOKge,
        TOKequal,       TOKnotequal,
        TOKidentity,    TOKnotidentity,
        TOKindex,       TOKis,
        TOKtobool,

// 60
        // NCEG floating point compares
        // !<>=     <>    <>=    !>     !>=   !<     !<=   !<>
        TOKunord,TOKlg,TOKleg,TOKule,TOKul,TOKuge,TOKug,TOKue,

        TOKshl,         TOKshr,
        TOKshlass,      TOKshrass,
        TOKushr,        TOKushrass,
        TOKcat,         TOKcatass,      // ~ ~=
        TOKadd,         TOKmin,         TOKaddass,      TOKminass,
        TOKmul,         TOKdiv,         TOKmod,
        TOKmulass,      TOKdivass,      TOKmodass,
        TOKand,         TOKor,          TOKxor,
        TOKandass,      TOKorass,       TOKxorass,
        TOKassign,      TOKnot,         TOKtilde,
        TOKplusplus,    TOKminusminus,  TOKconstruct,   TOKblit,
        TOKdot,         TOKarrow,       TOKcomma,
        TOKquestion,    TOKandand,      TOKoror,
        TOKpreplusplus, TOKpreminusminus,

// 106
        // Numeric literals
        TOKint32v, TOKuns32v,
        TOKint64v, TOKuns64v,
        TOKfloat32v, TOKfloat64v, TOKfloat80v,
        TOKimaginary32v, TOKimaginary64v, TOKimaginary80v,

        // Char constants
        TOKcharv, TOKwcharv, TOKdcharv,

        // Leaf operators
        TOKidentifier,  TOKstring,
        TOKthis,        TOKsuper,
        TOKhalt,        TOKtuple,
        TOKerror,

        // Basic types
        TOKvoid,
        TOKint8, TOKuns8,
        TOKint16, TOKuns16,
        TOKint32, TOKuns32,
        TOKint64, TOKuns64,
        TOKfloat32, TOKfloat64, TOKfloat80,
        TOKimaginary32, TOKimaginary64, TOKimaginary80,
        TOKcomplex32, TOKcomplex64, TOKcomplex80,
        TOKchar, TOKwchar, TOKdchar, TOKbit, TOKbool,
        TOKcent, TOKucent,

// 152
        // Aggregates
        TOKstruct, TOKclass, TOKinterface, TOKunion, TOKenum, TOKimport,
        TOKtypedef, TOKalias, TOKoverride, TOKdelegate, TOKfunction,
        TOKmixin,

        TOKalign, TOKextern, TOKprivate, TOKprotected, TOKpublic, TOKexport,
        TOKstatic, /*TOKvirtual,*/ TOKfinal, TOKconst, TOKabstract, TOKvolatile,
        TOKdebug, TOKdeprecated, TOKin, TOKout, TOKinout, TOKlazy,
        TOKauto, TOKpackage, TOKmanifest, TOKimmutable,

        // Statements
        TOKif, TOKelse, TOKwhile, TOKfor, TOKdo, TOKswitch,
        TOKcase, TOKdefault, TOKbreak, TOKcontinue, TOKwith,
        TOKsynchronized, TOKreturn, TOKgoto, TOKtry, TOKcatch, TOKfinally,
        TOKasm, TOKforeach, TOKforeach_reverse,
        TOKscope,
        TOKon_scope_exit, TOKon_scope_failure, TOKon_scope_success,

        // Contracts
        TOKbody, TOKinvariant,

        // Testing
        TOKunittest,

        // Added after 1.0
        TOKargTypes,
        TOKref,
        TOKmacro,
#if DMDV2
        TOKtraits,
        TOKoverloadset,
        TOKpure,
        TOKnothrow,
        TOKtls,
        TOKgshared,
        TOKline,
        TOKfile,
        TOKshared,
        TOKat,
        TOKpow,
        TOKpowass,
#endif

        TOKMAX
};

#define TOKwild TOKinout

#define BASIC_TYPES                     \
        TOKwchar: case TOKdchar:                \
        case TOKbit: case TOKbool: case TOKchar:        \
        case TOKint8: case TOKuns8:             \
        case TOKint16: case TOKuns16:           \
        case TOKint32: case TOKuns32:           \
        case TOKint64: case TOKuns64:           \
        case TOKfloat32: case TOKfloat64: case TOKfloat80:              \
        case TOKimaginary32: case TOKimaginary64: case TOKimaginary80:  \
        case TOKcomplex32: case TOKcomplex64: case TOKcomplex80:        \
        case TOKvoid

#define BASIC_TYPES_X(t)                                        \
        TOKvoid:         t = Type::tvoid;  goto LabelX;         \
        case TOKint8:    t = Type::tint8;  goto LabelX;         \
        case TOKuns8:    t = Type::tuns8;  goto LabelX;         \
        case TOKint16:   t = Type::tint16; goto LabelX;         \
        case TOKuns16:   t = Type::tuns16; goto LabelX;         \
        case TOKint32:   t = Type::tint32; goto LabelX;         \
        case TOKuns32:   t = Type::tuns32; goto LabelX;         \
        case TOKint64:   t = Type::tint64; goto LabelX;         \
        case TOKuns64:   t = Type::tuns64; goto LabelX;         \
        case TOKfloat32: t = Type::tfloat32; goto LabelX;       \
        case TOKfloat64: t = Type::tfloat64; goto LabelX;       \
        case TOKfloat80: t = Type::tfloat80; goto LabelX;       \
        case TOKimaginary32: t = Type::timaginary32; goto LabelX;       \
        case TOKimaginary64: t = Type::timaginary64; goto LabelX;       \
        case TOKimaginary80: t = Type::timaginary80; goto LabelX;       \
        case TOKcomplex32: t = Type::tcomplex32; goto LabelX;   \
        case TOKcomplex64: t = Type::tcomplex64; goto LabelX;   \
        case TOKcomplex80: t = Type::tcomplex80; goto LabelX;   \
        case TOKbool:    t = Type::tbool;    goto LabelX;       \
        case TOKchar:    t = Type::tchar;    goto LabelX;       \
        case TOKwchar:   t = Type::twchar; goto LabelX; \
        case TOKdchar:   t = Type::tdchar; goto LabelX; \
        LabelX

struct Token
{
    Token *next;
    unsigned char *ptr;         // pointer to first character of this token within buffer
    enum TOK value;
    unsigned char *blockComment; // doc comment string prior to this token
    unsigned char *lineComment;  // doc comment for previous token
    union
    {
        // Integers
        d_int32 int32value;
        d_uns32 uns32value;
        d_int64 int64value;
        d_uns64 uns64value;

        // Floats
#ifdef IN_GCC
        // real_t float80value; // can't use this in a union!
#else
        d_float80 float80value;
#endif

        struct
        {   unsigned char *ustring;     // UTF8 string
            unsigned len;
            unsigned char postfix;      // 'c', 'w', 'd'
        };

        Identifier *ident;
    };
#ifdef IN_GCC
    real_t float80value; // can't use this in a union!
#endif

    static const char *tochars[TOKMAX];
    static void *operator new(size_t sz);

    int isKeyword();
    void print();
    const char *toChars();
    static const char *toChars(enum TOK);
};

struct Lexer
{
    static StringTable stringtable;
    static OutBuffer stringbuffer;
    static Token *freelist;

    Loc loc;                    // for error messages

    unsigned char *base;        // pointer to start of buffer
    unsigned char *end;         // past end of buffer
    unsigned char *p;           // current character
    Token token;
    Module *mod;
    int doDocComment;           // collect doc comment information
    int anyToken;               // !=0 means seen at least one token
    int commentToken;           // !=0 means comments are TOKcomment's

    Lexer(Module *mod,
        unsigned char *base, unsigned begoffset, unsigned endoffset,
        int doDocComment, int commentToken);

    static void initKeywords();
    static Identifier *idPool(const char *s);
    static Identifier *uniqueId(const char *s);
    static Identifier *uniqueId(const char *s, int num);

    TOK nextToken();
    TOK peekNext();
    TOK peekNext2();
    void scan(Token *t);
    Token *peek(Token *t);
    Token *peekPastParen(Token *t);
    unsigned escapeSequence();
    TOK wysiwygStringConstant(Token *t, int tc);
    TOK hexStringConstant(Token *t);
#if DMDV2
    TOK delimitedStringConstant(Token *t);
    TOK tokenStringConstant(Token *t);
#endif
    TOK escapeStringConstant(Token *t, int wide);
    TOK charConstant(Token *t, int wide);
    void stringPostfix(Token *t);
    unsigned wchar(unsigned u);
    TOK number(Token *t);
    TOK inreal(Token *t);
    void error(const char *format, ...);
    void error(Loc loc, const char *format, ...);
    void pragma();
    unsigned decodeUTF();
    void getDocComment(Token *t, unsigned lineComment);

    static int isValidIdentifier(char *p);
    static unsigned char *combineComments(unsigned char *c1, unsigned char *c2);
};

#endif /* DMD_LEXER_H */
