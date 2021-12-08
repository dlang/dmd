
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/tokens.h
 */

#pragma once

#include "root/dcompat.h"
#include "root/port.h"
#include "globals.h"

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

typedef unsigned short TOK;
enum
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
        TOKdotid,       TOKdotti,
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

// 64
        TOKshl,         TOKshr,
        TOKshlass,      TOKshrass,
        TOKushr,        TOKushrass,
        TOKcat,         TOKcatass,      TOKcatelemass,  TOKcatdcharass,     // ~ ~=
        TOKadd,         TOKmin,         TOKaddass,      TOKminass,
        TOKmul,         TOKdiv,         TOKmod,
        TOKmulass,      TOKdivass,      TOKmodass,
        TOKand,         TOKor,          TOKxor,
        TOKandass,      TOKorass,       TOKxorass,
        TOKassign,      TOKnot,         TOKtilde,
        TOKplusplus,    TOKminusminus,  TOKconstruct,   TOKblit,
        TOKdot,         TOKcomma,
        TOKquestion,    TOKandand,      TOKoror,
        TOKpreplusplus, TOKpreminusminus,

// 105
        // Numeric literals
        TOKint32v, TOKuns32v,
        TOKint64v, TOKuns64v,
        TOKint128v, TOKuns128v,
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

// 152
        // Aggregates
        TOKstruct, TOKclass, TOKinterface, TOKunion, TOKenum, TOKimport,
        TOKalias, TOKoverride, TOKdelegate, TOKfunction,
        TOKmixin,

        TOKalign, TOKextern, TOKprivate, TOKprotected, TOKpublic, TOKexport,
        TOKstatic, TOKfinal, TOKconst, TOKabstract,
        TOKdebug, TOKdeprecated, TOKin, TOKout, TOKinout, TOKlazy,
        TOKauto, TOKpackage, TOKimmutable,

// 182
        // Statements
        TOKif, TOKelse, TOKwhile, TOKfor, TOKdo, TOKswitch,
        TOKcase, TOKdefault, TOKbreak, TOKcontinue, TOKwith,
        TOKsynchronized, TOKreturn, TOKgoto, TOKtry, TOKcatch, TOKfinally,
        TOKasm, TOKforeach, TOKforeach_reverse,
        TOKscope,
        TOKon_scope_exit, TOKon_scope_failure, TOKon_scope_success,

// 206
        // Contracts
        TOKinvariant,

        // Testing
        TOKunittest,

        // Added after 1.0
        TOKargTypes,
        TOKref,
        TOKmacro,

// 211
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

// 230
        TOKinterval,
        TOKvoidexp,
        TOKcantexp,
        TOKshowctfecontext,

        TOKobjc_class_reference,
        TOKvectorarray,

        TOKarrow,
        TOKcolonColon,
        TOKwchar_tLiteral,
        TOKcompoundLiteral,

        TOKinline,
        TOKregister,
        TOKrestrict,
        TOKsigned,
        TOKsizeof_,
        TOKtypedef_,
        TOKunsigned,
        TOKvolatile,
        TOK_Alignas,
        TOK_Alignof,
        TOK_Atomic,
        TOK_Bool,
        TOK_Complex,
        TOK_Generic,
        TOK_Imaginary,
        TOK_Noreturn,
        TOK_Static_assert,
        TOK_Thread_local,

        TOK__cdecl,
        TOK__declspec,
        TOK__attribute__,

        TOKMAX
};

typedef unsigned short EXP;
enum
{
        EXPreserved,

        // Other
        EXPlparen,      EXPrparen,
        EXPlbracket,    EXPrbracket,
        EXPlcurly,      EXPrcurly,
        EXPcolon,       EXPneg,
        EXPsemicolon,   EXPdotdotdot,
        EXPeof,         EXPcast,
        EXPnull,        EXPassert,
        EXPtrue,        EXPfalse,
        EXParray,       EXPcall,
        EXPaddress,
        EXPtype,        EXPthrow,
        EXPnew,         EXPdelete,
        EXPstar,        EXPsymoff,
        EXPvar,         EXPdotvar,
        EXPdotid,       EXPdotti,
        EXPdottype,     EXPslice,
        EXParraylength, EXPversion,
        EXPmodule,      EXPdollar,
        EXPtemplate,    EXPdottd,
        EXPdeclaration, EXPtypeof,
        EXPpragma,      EXPdsymbol,
        EXPtypeid,      EXPuadd,
        EXPremove,
        EXPnewanonclass, EXPcomment,
        EXParrayliteral, EXPassocarrayliteral,
        EXPstructliteral,
        EXPclassreference,
        EXPthrownexception,
        EXPdelegateptr,
        EXPdelegatefuncptr,

// 54
        // Operators
        EXPlt,          EXPgt,
        EXPle,          EXPge,
        EXPequal,       EXPnotequal,
        EXPidentity,    EXPnotidentity,
        EXPindex,       EXPis,

// 64
        EXPshl,         EXPshr,
        EXPshlass,      EXPshrass,
        EXPushr,        EXPushrass,
        EXPcat,         EXPcatass,      EXPcatelemass,  EXPcatdcharass,     // ~ ~=
        EXPadd,         EXPmin,         EXPaddass,      EXPminass,
        EXPmul,         EXPdiv,         EXPmod,
        EXPmulass,      EXPdivass,      EXPmodass,
        EXPand,         EXPor,          EXPxor,
        EXPandass,      EXPorass,       EXPxorass,
        EXPassign,      EXPnot,         EXPtilde,
        EXPplusplus,    EXPminusminus,  EXPconstruct,   EXPblit,
        EXPdot,         EXPcomma,
        EXPquestion,    EXPandand,      EXPoror,
        EXPpreplusplus, EXPpreminusminus,

// 105
        // Numeric literals
        EXPint32v, EXPuns32v,
        EXPint64v, EXPuns64v,
        EXPint128v, EXPuns128v,
        EXPfloat32v, EXPfloat64v, EXPfloat80v,
        EXPimaginary32v, EXPimaginary64v, EXPimaginary80v,

        // Char constants
        EXPcharv, EXPwcharv, EXPdcharv,

        // Leaf operators
        EXPidentifier,  EXPstring, EXPxstring,
        EXPthis,        EXPsuper,
        EXPhalt,        EXPtuple,
        EXPerror,

        // Basic types
        EXPvoid,
        EXPint8, EXPuns8,
        EXPint16, EXPuns16,
        EXPint32, EXPuns32,
        EXPint64, EXPuns64,
        EXPint128, EXPuns128,
        EXPfloat32, EXPfloat64, EXPfloat80,
        EXPimaginary32, EXPimaginary64, EXPimaginary80,
        EXPcomplex32, EXPcomplex64, EXPcomplex80,
        EXPchar, EXPwchar, EXPdchar, EXPbool,

// 152
        // Aggregates
        EXPstruct, EXPclass, EXPinterface, EXPunion, EXPenum, EXPimport,
        EXPalias, EXPoverride, EXPdelegate, EXPfunction,
        EXPmixin,

        EXPalign, EXPextern, EXPprivate, EXPprotected, EXPpublic, EXPexport,
        EXPstatic, EXPfinal, EXPconst, EXPabstract,
        EXPdebug, EXPdeprecated, EXPin, EXPout, EXPinout, EXPlazy,
        EXPauto, EXPpackage, EXPimmutable,

// 182
        // Statements
        EXPif, EXPelse, EXPwhile, EXPfor, EXPdo, EXPswitch,
        EXPcase, EXPdefault, EXPbreak, EXPcontinue, EXPwith,
        EXPsynchronized, EXPreturn, EXPgoto, EXPtry, EXPcatch, EXPfinally,
        EXPasm, EXPforeach, EXPforeach_reverse,
        EXPscope,
        EXPon_scope_exit, EXPon_scope_failure, EXPon_scope_success,

// 206
        // Contracts
        EXPinvariant,

        // Testing
        EXPunittest,

        // Added after 1.0
        EXPargTypes,
        EXPref,
        EXPmacro,

// 211
        EXPtraits,
        EXPoverloadset,
        EXPline,
        EXPfile,
        EXPfilefullpath,
        EXPmodulestring,
        EXPfuncstring,
        EXPprettyfunc,
        EXPshared,
        EXPpow,
        EXPpowass,
        EXPvector,

        EXPvoidexp,
        EXPcantexp,
        EXPshowctfecontext,
        EXPobjc_class_reference,
        EXPvectorarray,
        EXParrow,
        EXPcompoundLiteral,
        EXP_Generic,
        EXPinterval,

        EXPMAX
};

#define TOKwild TOKinout

// Token has an anonymous struct, which is not strict ISO C++.
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"
#endif

struct Token
{
    Token *next;
    Loc loc;
    const utf8_t *ptr;    // pointer to first character of this token within buffer
    TOK value;
    DString blockComment; // doc comment string prior to this token
    DString lineComment;  // doc comment for previous token
    union
    {
        // Integers
        sinteger_t intvalue;
        uinteger_t unsvalue;

        // Floats
        real_t floatvalue;

        struct
        {   utf8_t *ustring;     // UTF8 string
            unsigned len;
            unsigned char postfix;      // 'c', 'w', 'd'
        };

        Identifier *ident;
    };

    void free();

    Token() : next(NULL) {}
    int isKeyword();
    const char *toChars() const;

    static const char *toChars(TOK value);
};

#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif
