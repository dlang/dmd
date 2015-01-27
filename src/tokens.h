
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/lexer.h
 */

#ifndef DMD_TOKENS_H
#define DMD_TOKENS_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "port.h"
#include "mars.h"

class Identifier;

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
        .       ->      :       ,       =>
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
        TOKclassreference,
        TOKthrownexception,
        TOKdelegateptr,
        TOKdelegatefuncptr,

// 54
        // Operators
        TOKlt,          TOKgt,
        TOKle,          TOKge,
        TOKequal,       TOKnotequal,
        TOKidentity,    TOKnotidentity,
        TOKindex,       TOKis,
        TOKtobool,

// 65
        // NCEG floating point compares
        // !<>=     <>    <>=    !>     !>=   !<     !<=   !<>
        TOKunord,TOKlg,TOKleg,TOKule,TOKul,TOKuge,TOKug,TOKue,

// 73
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

// 112
        // Numeric literals
        TOKint32v, TOKuns32v,
        TOKint64v, TOKuns64v,
        TOKfloat32v, TOKfloat64v, TOKfloat80v,
        TOKimaginary32v, TOKimaginary64v, TOKimaginary80v,

        // Char constants
        TOKcharv, TOKwcharv, TOKdcharv,

        // Leaf operators
        TOKidentifier,  TOKstring, TOKxstring,
        TOKthis,        TOKsuper,
        TOKhalt,        TOKtuple,
        TOKerror,

        // Basic types
        TOKvoid,
        TOKint8, TOKuns8,
        TOKint16, TOKuns16,
        TOKint32, TOKuns32,
        TOKint64, TOKuns64,
        TOKint128, TOKuns128,
        TOKfloat32, TOKfloat64, TOKfloat80,
        TOKimaginary32, TOKimaginary64, TOKimaginary80,
        TOKcomplex32, TOKcomplex64, TOKcomplex80,
        TOKchar, TOKwchar, TOKdchar, TOKbool,

// 157
        // Aggregates
        TOKstruct, TOKclass, TOKinterface, TOKunion, TOKenum, TOKimport,
        TOKtypedef, TOKalias, TOKoverride, TOKdelegate, TOKfunction,
        TOKmixin,

        TOKalign, TOKextern, TOKprivate, TOKprotected, TOKpublic, TOKexport,
        TOKstatic, TOKfinal, TOKconst, TOKabstract, TOKvolatile,
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

        TOKMAX
};

#define TOKwild TOKinout

struct Token
{
    Token *next;
    Loc loc;
    const utf8_t *ptr;         // pointer to first character of this token within buffer
    TOK value;
    const utf8_t *blockComment; // doc comment string prior to this token
    const utf8_t *lineComment;  // doc comment for previous token
    union
    {
        // Integers
        d_int32 int32value;
        d_uns32 uns32value;
        d_int64 int64value;
        d_uns64 uns64value;

        // Floats
        d_float80 float80value;

        struct
        {   utf8_t *ustring;     // UTF8 string
            unsigned len;
            unsigned char postfix;      // 'c', 'w', 'd'
        };

        Identifier *ident;
    };

    static const char *tochars[TOKMAX];
    static void initTokens();

    static Token *freelist;
    static Token *alloc();
    void free();

    Token() : next(NULL) {}
    int isKeyword();
#ifdef DEBUG
    void print();
#endif
    const char *toChars();
    static const char *toChars(TOK);
};

#endif /* DMD_TOKENS_H */
