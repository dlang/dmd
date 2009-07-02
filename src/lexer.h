

// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
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
	(	)
	[	]
	{	}
	<	>	<=	>=	==	!=	===	!==
	<<	>>	<<=	>>=	>>>	>>>=
	+	-	+=	-=
	*	/	%	*=	/=	%=
	&	| 	^	&=	|=	^=
	=	!	~
	++	--
	.	->	:	,
	?	&&	||
 */

enum TOK
{
	TOKreserved,

	// Other
	TOKlparen,	TOKrparen,
	TOKlbracket,	TOKrbracket,
	TOKlcurly,	TOKrcurly,
	TOKcolon,	TOKneg,
	TOKsemicolon,	TOKdotdotdot,
	TOKeof,		TOKcast,
	TOKnull,	TOKassert,
	TOKtrue,	TOKfalse,
	TOKarray,	TOKcall,
	TOKaddress,	TOKtypedot,
	TOKtype,	TOKthrow,
	TOKnew,		TOKdelete,
	TOKstar,	TOKsymoff,
	TOKvar,		TOKdotvar,
	TOKdottype,	TOKrange,
	TOKarraylength,	TOKversion,
	TOKmodule,	TOKdollar,
	TOKtemplate,	TOKinstance,
	TOKdeclaration,

	// Operators
	TOKlt,		TOKgt,
	TOKle,		TOKge,
	TOKequal,	TOKnotequal,
	TOKidentity,	TOKnotidentity,

	// NCEG floating point compares
	// !<>=     <>    <>=    !>     !>=   !<     !<=   !<>
	TOKunord,TOKlg,TOKleg,TOKule,TOKul,TOKuge,TOKug,TOKue,

	TOKshl,		TOKshr,
	TOKshlass,	TOKshrass,
	TOKushr,	TOKushrass,
	TOKcat,		TOKcatass,	// ~ ~=
	TOKadd,		TOKmin,		TOKaddass,	TOKminass,
	TOKmul,		TOKdiv,		TOKmod,
	TOKmulass,	TOKdivass,	TOKmodass,
	TOKand,		TOKor,		TOKxor,
	TOKandass,	TOKorass,	TOKxorass,
	TOKassign,	TOKnot,		TOKtilde,
	TOKplusplus,	TOKminusminus,
	TOKdot,		TOKarrow,	TOKcomma,
	TOKquestion,	TOKandand,	TOKoror,

	// Numeric literals
	TOKint32v, TOKuns32v,
	TOKint64v, TOKuns64v,
	TOKfloat32v, TOKfloat64v, TOKfloat80v,
	TOKimaginary32v, TOKimaginary64v, TOKimaginary80v,

	// Leaf operators
	TOKidentifier,	TOKstring,
	TOKthis,	TOKsuper,

	// Basic types
	TOKvoid,
	TOKint8, TOKuns8,
	TOKint16, TOKuns16,
	TOKint32, TOKuns32,
	TOKint64, TOKuns64,
	TOKfloat32, TOKfloat64, TOKfloat80,
	TOKimaginary32, TOKimaginary64, TOKimaginary80,
	TOKcomplex32, TOKcomplex64, TOKcomplex80,
	TOKascii, TOKwchar, TOKbit,

	// Aggregates
	TOKstruct, TOKclass, TOKinterface, TOKunion, TOKenum, TOKimport,
	TOKtypedef, TOKalias, TOKoverride, TOKdelegate, TOKfunction,

	TOKalign, TOKextern, TOKprivate, TOKprotected, TOKpublic, TOKexport,
	TOKstatic, /*TOKvirtual,*/ TOKfinal, TOKconst, TOKabstract, TOKvolatile,
	TOKdebug, TOKdeprecated, TOKin, TOKout, TOKinout,
	TOKauto,

	// Statements
	TOKif, TOKelse, TOKwhile, TOKfor, TOKdo, TOKswitch,
	TOKcase, TOKdefault, TOKbreak, TOKcontinue, TOKwith,
	TOKsynchronized, TOKreturn, TOKgoto, TOKtry, TOKcatch, TOKfinally,
	TOKasm,

	// Contracts
	TOKbody, TOKinvariant,

	// Testing
	TOKunittest,

	TOKMAX
};

#define CASE_BASIC_TYPES			\
	case TOKwchar:				\
	case TOKbit: case TOKascii:		\
	case TOKint8: case TOKuns8:		\
	case TOKint16: case TOKuns16:		\
	case TOKint32: case TOKuns32:		\
	case TOKint64: case TOKuns64:		\
	case TOKfloat32: case TOKfloat64: case TOKfloat80:		\
	case TOKimaginary32: case TOKimaginary64: case TOKimaginary80:	\
	case TOKcomplex32: case TOKcomplex64: case TOKcomplex80:	\
	case TOKvoid

#define CASE_BASIC_TYPES_X(t)					\
	case TOKvoid:	 t = Type::tvoid;  goto LabelX;		\
	case TOKint8:	 t = Type::tint8;  goto LabelX;		\
	case TOKuns8:	 t = Type::tuns8;  goto LabelX;		\
	case TOKint16:	 t = Type::tint16; goto LabelX;		\
	case TOKuns16:	 t = Type::tuns16; goto LabelX;		\
	case TOKint32:	 t = Type::tint32; goto LabelX;		\
	case TOKuns32:	 t = Type::tuns32; goto LabelX;		\
	case TOKint64:	 t = Type::tint64; goto LabelX;		\
	case TOKuns64:	 t = Type::tuns64; goto LabelX;		\
	case TOKfloat32: t = Type::tfloat32; goto LabelX;	\
	case TOKfloat64: t = Type::tfloat64; goto LabelX;	\
	case TOKfloat80: t = Type::tfloat80; goto LabelX;	\
	case TOKimaginary32: t = Type::timaginary32; goto LabelX;	\
	case TOKimaginary64: t = Type::timaginary64; goto LabelX;	\
	case TOKimaginary80: t = Type::timaginary80; goto LabelX;	\
	case TOKcomplex32: t = Type::tcomplex32; goto LabelX;	\
	case TOKcomplex64: t = Type::tcomplex64; goto LabelX;	\
	case TOKcomplex80: t = Type::tcomplex80; goto LabelX;	\
	case TOKbit:	 t = Type::tbit;     goto LabelX;	\
	case TOKascii:	 t = Type::tascii;    goto LabelX;	\
	case TOKwchar:	 t = Type::twchar; goto LabelX;	\
	LabelX

struct Token
{
    Token *next;
    unsigned char *ptr;		// pointer to first character of this token within buffer
    enum TOK value;
    union
    {
	// Integers
	d_int32 int32value;
	d_uns32	uns32value;
	d_int64	int64value;
	d_uns64	uns64value;

	// Floats
	d_float80 float80value;

	//char *string;		// ascii string
	struct
	{   wchar_t *ustring;	// wchar string
	    unsigned len;
	};
	Identifier *ident;
    };

    static char *tochars[TOKMAX];
    static void *operator new(size_t sz);

    void print();
    char *toChars();
    static char *toChars(enum TOK);
};

struct Lexer
{
    static StringTable stringtable;
    static OutBuffer stringbuffer;
    static Token *freelist;

    Loc loc;			// for error messages

    unsigned char *base;	// pointer to start of buffer
    unsigned char *end;		// past end of buffer
    unsigned char *p;		// current character
    Token token;

    Lexer(Module *mod, unsigned char *base, unsigned length);

    static void initKeywords();
    static Identifier *idPool(const char *s);

    TOK nextToken();
    void scan(Token *t);
    Token *peek(Token *t);
    unsigned escapeSequence();
    TOK wysiwygStringConstant(Token *t, int wide);
    TOK escapeStringConstant(Token *t, int wide);
    TOK charConstant(Token *t, int wide);
    unsigned wchar(unsigned u);
    TOK number(Token *t);
    TOK inreal(Token *t);
    void error(const char *format, ...);
    void pragma();
};

#endif /* DMD_LEXER_H */
