
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/* Lexical Analyzer */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <errno.h>
#include <wchar.h>

#include "..\root\mem.h"
#include "lexer.h"

#if _WIN32 && __DMC__
// from \dm\src\include\setlocal.h
extern "C" char * __cdecl __locale_decpoint;
#endif

#define isoctal(c)	('0' <= (c) && (c) <= '7')
#define ishex(c)	(isdigit(c) || ('a' <= (c) && (c) <= 'f') || ('A' <= (c) && (c) <= 'F'))


/******************************************************/

char *Token::tochars[TOKMAX];

void *Token::operator new(size_t size)
{   Token *t;

    if (Lexer::freelist)
    {
	t = Lexer::freelist;
	Lexer::freelist = t->next;
	return t;
    }

    return ::operator new(size);
}

void Token::print()
{
    printf("%s\n", toChars());
}

char *Token::toChars()
{   char *p;
    static char buffer[3 + 3 * sizeof(value) + 1];

    p = buffer;
    switch (value)
    {
	case TOKint32v:
	    sprintf(buffer,"%ld",int32value);
	    break;

	case TOKuns32v:
	    sprintf(buffer,"%luU",uns32value);
	    break;

	case TOKint64v:
	    sprintf(buffer,"%lldL",int64value);
	    break;

	case TOKuns64v:
	    sprintf(buffer,"%lluUL",uns64value);
	    break;

	case TOKfloat32v:
	    sprintf(buffer,"%Lgf", float80value);
	    break;

	case TOKfloat64v:
	    sprintf(buffer,"%Lg", float80value);
	    break;

	case TOKfloat80v:
	    sprintf(buffer,"%gL", float80value);
	    break;

	case TOKimaginaryv:
	    sprintf(buffer,"%gLi", float80value);
	    break;

	case TOKstring:
#if CSTRINGS
	    p = string;
#else
	    // Convert wchar string to ascii
	    p = wchar2ascii(ustring, len);
#endif
	    break;

	case TOKidentifier:
	case TOKenum:
	case TOKstruct:
	case TOKimport:
	CASE_BASIC_TYPES:
	    p = ident->toChars();
	    break;

	default:
	    p = toChars(value);
	    break;
    }
    return p;
}

char *Token::toChars(enum TOK value)
{   char *p;
    static char buffer[3 + 3 * sizeof(value) + 1];

    p = tochars[value];
    if (!p)
    {	sprintf(buffer,"TOK%d",value);
	p = buffer;
    }
    return p;
}

/******************************************************/

Token *Lexer::freelist = NULL;
StringTable Lexer::stringtable;
OutBuffer Lexer::stringbuffer;

Lexer::Lexer(Module *mod, unsigned char *base, unsigned length)
    : loc(mod, 1)
{
    //printf("Lexer::Lexer(%p,%d)\n",base,length);
    //printf("lexer.mod = %p, %p\n", mod, this->loc.mod);
    memset(&token,0,sizeof(token));
    this->base = base;
    this->end  = base + length;
    p = base;
    //initKeywords();
}

#if 0
unsigned Lexer::locToLine(Loc loc)
{
    unsigned linnum = 1;
    unsigned char *s;
    unsigned char *p = base + loc;

    for (s = base; s != p; s++)
    {
	if (*s == '\n')
	    linnum++;
    }
    return linnum;
}
#endif

void Lexer::error(const char *format, ...)
{
    char *p = loc.toChars();
    if (*p)
	printf("%s: ", p);
    mem.free(p);

    va_list ap;
    va_start(ap, format);
    vprintf(format, ap);
    va_end(ap);

    printf("\n");
    fflush(stdout);

    global.errors++;
    if (global.errors > 10)	// moderate blizzard of cascading messages
	fatal();
}

TOK Lexer::nextToken()
{   Token *t;

    if (token.next)
    {
	t = token.next;
	memcpy(&token,t,sizeof(Token));
	t->next = freelist;
	freelist = t;
    }
    else
    {
	scan(&token);
    }
    //token.print();
    return token.value;
}

Token *Lexer::peek(Token *ct)
{   Token *t;

    if (ct->next)
	t = ct->next;
    else
    {
	t = new Token();
	scan(t);
	t->next = NULL;
	ct->next = t;
    }
    return t;
}

/****************************
 * Turn next token in buffer into a token.
 */

void Lexer::scan(Token *t)
{
    while (1)
    {
	t->ptr = p;
	//printf("p = %p, *p = '%c'\n",p,*p);
	switch (*p)
	{
	    case 0:
	    case 0x1A:
		t->value = TOKeof;			// end of file
		return;

	    case ' ':
	    case '\t':
	    case '\v':
	    case '\f':
	    case '\r':
		p++;
		continue;			// skip white space

	    case '\n':
		p++;
		loc.linnum++;
		continue;			// skip white space

	    case '0':  	case '1':   case '2':   case '3':   case '4':
	    case '5':  	case '6':   case '7':   case '8':   case '9':
		t->value = number(t);
		return;

#if CSTRINGS
	    case '\'':
		t->value = charConstant(t, 0);
		return;

	    case '"':
		t->value = stringConstant(t,0);
		return;

	    case 'l':
	    case 'L':
		if (p[1] == '\'')
		{
		    p++;
		    t->value = charConstant(t, 1);
		    return;
		}
		else if (p[1] == '"')
		{
		    p++;
		    t->value = stringConstant(t, 1);
		    return;
		}
#else
	    case '\'':
		t->value = wysiwygStringConstant(t,1);
		return;

	    case '"':
		t->value = escapeStringConstant(t,1);
		return;

	    case '\\':			// escaped string literal
	    {	unsigned c;

		stringbuffer.reset();
		do
		{
		    p++;
		    if (*p == 'u')
			c = wchar();
		    else
			c = escapeSequence();
		    stringbuffer.writewchar(c);
		} while (*p == '\\');
		t->len = stringbuffer.offset / sizeof(d_wchar);
		stringbuffer.writewchar(0);
		t->ustring = (wchar_t *)mem.malloc(stringbuffer.offset);
		memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
		t->value = TOKstring;
		return;
	    }

	    case 'l':
	    case 'L':
#endif
	    case 'a':  	case 'b':   case 'c':   case 'd':   case 'e':
	    case 'f':  	case 'g':   case 'h':   case 'i':   case 'j':
	    case 'k':  	            case 'm':   case 'n':   case 'o':
	    case 'p':  	case 'q':   case 'r':   case 's':   case 't':
	    case 'u':  	case 'v':   case 'w':   case 'x':   case 'y':
	    case 'z':
	    case 'A':  	case 'B':   case 'C':   case 'D':   case 'E':
	    case 'F':  	case 'G':   case 'H':   case 'I':   case 'J':
	    case 'K':  	            case 'M':   case 'N':   case 'O':
	    case 'P':  	case 'Q':   case 'R':   case 'S':   case 'T':
	    case 'U':  	case 'V':   case 'W':   case 'X':   case 'Y':
	    case 'Z':
	    case '_':
	    {   unsigned char c;
		StringValue *sv;
		Identifier *id;

		do
		{
		    c = *++p;
		} while (isalnum(c) || c == '_');
		sv = stringtable.update((char *)t->ptr, p - t->ptr);
		id = (Identifier *) sv->ptrvalue;
		if (!id)
		{   id = new Identifier(sv->lstring.string,TOKidentifier);
		    sv->ptrvalue = id;
		}
		t->ident = id;
		t->value = (enum TOK) id->value;
		//printf("t->value = %d\n",t->value);
		return;
	    }

	    case '/':
		p++;
		switch (*p)
		{
		    case '=':
			p++;
			t->value = TOKdivass;
			return;

		    case '*':
			p++;
			while (1)
			{
			    while (1)
			    {
				switch (*p)
				{
				    case '/':
					break;

				    case '\n':
					loc.linnum++;
					p++;
					continue;

				    case 0:
				    case 0x1A:
					error("unterminated /* */ comment");
					p = end;
					t->value = TOKeof;
					return;

				    default:
					p++;
					continue;
				}
				break;
			    }
			    p++;
			    if (p[-2] == '*' && p - 3 != t->ptr)
				break;
			}
			continue;

		    case '/':
			p++;
			p = memchr(p, '\n', end - p);
			if (p == NULL)
			{
			    error("// comment does not end in newline");
			    p = end;
			    t->value = TOKeof;
			    return;
			}
			p++;
			loc.linnum++;
			continue;

		    case '+':
		    {	int nest;

			p++;
			nest = 1;
			while (1)
			{
			    switch (*p)
			    {
				case '/':
				    p++;
				    if (*p == '+')
				    {
					p++;
					nest++;
				    }
				    continue;

				case '+':
				    p++;
				    if (*p == '/')
				    {
					p++;
					if (--nest == 0)
					    break;
				    }
				    continue;

				case '\n':
				    loc.linnum++;
				    p++;
				    continue;

				case 0:
				case 0x1A:
				    error("unterminated /+ +/ comment");
				    p = end;
				    t->value = TOKeof;
				    return;

				default:
				    p++;
				    continue;
			    }
			    break;
			}
			continue;
		    }
		}
		t->value = TOKdiv;
		return;

	    case '.':
		p++;
		if (isdigit(*p))
		{
		    p--;
		    t->value = inreal(t);
		}
		else if (p[0] == '.')
		{
		    if (p[1] == '.')
		    {   p += 2;
			t->value = TOKdotdotdot;
		    }
		    else
		    {   p++;
			t->value = TOKrange;
		    }
		}
		else
		    t->value = TOKdot;
		return;

	    case '&':
		p++;
		if (*p == '=')
		{   p++;
		    t->value = TOKandass;
		}
		else if (*p == '&')
		{   p++;
		    t->value = TOKandand;
		}
		else
		    t->value = TOKand;
		return;

	    case '|':
		p++;
		if (*p == '=')
		{   p++;
		    t->value = TOKorass;
		}
		else if (*p == '|')
		{   p++;
		    t->value = TOKoror;
		}
		else
		    t->value = TOKor;
		return;

	    case '-':
		p++;
		if (*p == '=')
		{   p++;
		    t->value = TOKminass;
		}
#if 0
		else if (*p == '>')
		{   p++;
		    t->value = TOKarrow;
		}
#endif
		else if (*p == '-')
		{   p++;
		    t->value = TOKminusminus;
		}
		else
		    t->value = TOKmin;
		return;

	    case '+':
		p++;
		if (*p == '=')
		{   p++;
		    t->value = TOKaddass;
		}
		else if (*p == '+')
		{   p++;
		    t->value = TOKplusplus;
		}
		else
		    t->value = TOKadd;
		return;

	    case '<':
		p++;
		if (*p == '=')
		{   p++;
		    t->value = TOKle;			// <=
		}
		else if (*p == '<')
		{   p++;
		    if (*p == '=')
		    {   p++;
			t->value = TOKshlass;		// <<=
		    }
		    else
			t->value = TOKshl;		// <<
		}
		else if (*p == '>')
		{   p++;
		    if (*p == '=')
		    {   p++;
			t->value = TOKleg;		// <>=
		    }
		    else
			t->value = TOKlg;		// <>
		}
		else
		    t->value = TOKlt;			// <
		return;

	    case '>':
		p++;
		if (*p == '=')
		{   p++;
		    t->value = TOKge;			// >=
		}
		else if (*p == '>')
		{   p++;
		    if (*p == '=')
		    {   p++;
			t->value = TOKshrass;		// >>=
		    }
		    else if (*p == '>')
		    {	p++;
			if (*p == '=')
			{   p++;
			    t->value = TOKushrass;	// >>>=
			}
			else
			    t->value = TOKushr;		// >>>
		    }
		    else
			t->value = TOKshr;		// >>
		}
		else
		    t->value = TOKgt;			// >
		return;

	    case '!':
		p++;
		if (*p == '=')
		{   p++;
		    if (*p == '=')
		    {	p++;
			t->value = TOKnotidentity;	// !==
		    }
		    else
			t->value = TOKnotequal;		// !=
		}
		else if (*p == '<')
		{   p++;
		    if (*p == '>')
		    {	p++;
			if (*p == '=')
			{   p++;
			    t->value = TOKunord; // !<>=
			}
			else
			    t->value = TOKue;	// !<>
		    }
		    else if (*p == '=')
		    {	p++;
			t->value = TOKug;	// !<=
		    }
		    else
			t->value = TOKuge;	// !<
		}
		else if (*p == '>')
		{   p++;
		    if (*p == '=')
		    {	p++;
			t->value = TOKul;	// !>=
		    }
		    else
			t->value = TOKule;	// !>
		}
		else
		    t->value = TOKnot;		// !
		return;

	    case '=':
		p++;
		if (*p == '=')
		{   p++;
		    if (*p == '=')
		    {	p++;
			t->value = TOKidentity;		// ===
		    }
		    else
			t->value = TOKequal;		// ==
		}
		else
		    t->value = TOKassign;		// =
		return;

#define SINGLE(c,tok) case c: p++; t->value = tok; return;

	    SINGLE('(',	TOKlparen)
	    SINGLE(')', TOKrparen)
	    SINGLE('[', TOKlbracket)
	    SINGLE(']', TOKrbracket)
	    SINGLE('{', TOKlcurly)
	    SINGLE('}', TOKrcurly)
	    SINGLE('?', TOKquestion)
	    SINGLE(',', TOKcomma)
	    SINGLE(';', TOKsemicolon)
	    SINGLE(':', TOKcolon)
	    SINGLE('$', TOKdollar)

#undef SINGLE

#define DOUBLE(c1,tok1,c2,tok2)		\
	    case c1:			\
		p++;			\
		if (*p == c2)		\
		{   p++;		\
		    t->value = tok2;	\
		}			\
		else			\
		    t->value = tok1;	\
		return;

	    DOUBLE('*', TOKmul, '=', TOKmulass)
	    DOUBLE('%', TOKmod, '=', TOKmodass)
	    DOUBLE('^', TOKxor, '=', TOKxorass)
	    DOUBLE('~', TOKtilde, '=', TOKcatass)

#undef DOUBLE

	    default:
		if (isprint(*p))
		    error("unsupported char '%c'", *p);
		else
		    error("unsupported char 0x%02x", *p);
		p++;
		continue;
	}
    }
}

/*******************************************
 * Parse escape sequence.
 */

unsigned Lexer::escapeSequence()
{   unsigned c;
    int n;
    int ndigits;

    c = *p;
    switch (c)
    {
	case '\'':
	case '"':
	case '?':
	case '\\':
	Lconsume:
		p++;
		break;

	case 'a':	c = 7;		goto Lconsume;
	case 'b':	c = 8;		goto Lconsume;
	case 'f':	c = 12;		goto Lconsume;
	case 'n':	c = 10;		goto Lconsume;
	case 'r':	c = 13;		goto Lconsume;
	case 't':	c = 9;		goto Lconsume;
	case 'v':	c = 11;		goto Lconsume;

	case 'u':
		ndigits = 4;
		goto Lhex;
	case 'x':
		ndigits = 2;
	Lhex:
		p++;
		c = *p;
		if (ishex(c))
		{   unsigned v;

		    n = 0;
		    v = 0;
		    while (1)
		    {
			if (isdigit(c))
			    c -= '0';
			else if (islower(c))
			    c -= 'a' - 10;
			else
			    c -= 'A' - 10;
			v = v * 16 + c;
			c = *++p;
			if (++n == ndigits)
			    break;
			if (!ishex(c))
			{   error("escape hex sequence has %d hex digits instead of %d", n, ndigits);
			    break;
			}
		    }
		    c = v;
		}
		else
		    error("undefined escape hex sequence \\%c\n",c);
		break;

	case 0:
	case 0x1A:			// end of file
		c = '\\';
		break;

	default:
		if (isoctal(c))
		{   unsigned char v;

		    n = 0;
		    v = 0;
		    do
		    {
			v = v * 8 + (c - '0');
			c = *++p;
		    } while (++n < 3 && isoctal(c));
		    c = v;
		}
		else
		    error("undefined escape sequence \\%c\n",c);
		break;
    }
    return c;
}

/**************************************
 */

TOK Lexer::wysiwygStringConstant(Token *t, int wide)
{   unsigned c;
    Loc start = loc;

    p++;
    stringbuffer.reset();
    while (1)
    {
	c = *p++;
	switch (c)
	{
	    case '\n':
		loc.linnum++;
		break;

	    case '\r':
		if (*p == '\n')
		    continue;	// ignore
		c = '\n';	// treat EndOfLine as \n character
		loc.linnum++;
		break;

	    case 0:
	    case 0x1A:
		error("unterminated string constant starting at %s", start.toChars());
		t->ustring = L"";
		t->len = 0;
		return TOKstring;

	    case '\'':
		t->len = stringbuffer.offset / sizeof(d_wchar);
		stringbuffer.writewchar(0);
		t->ustring = (wchar_t *)mem.malloc(stringbuffer.offset);
		memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
		return TOKstring;
	}
	if (wide)
	    stringbuffer.writewchar(c);
	else
	    stringbuffer.writeByte(c);
    }
}

/**************************************
 */

TOK Lexer::escapeStringConstant(Token *t, int wide)
{   unsigned c;
    Loc start = loc;

    p++;
    stringbuffer.reset();
    while (1)
    {
	c = *p++;
	switch (c)
	{
	    case '\\':
		if (*p == 'u' && wide)
		    c = wchar();
		else
		    c = escapeSequence();
		break;

	    case '\n':
		loc.linnum++;
		break;

	    case '\r':
		if (*p == '\n')
		    continue;	// ignore
		c = '\n';	// treat EndOfLine as \n character
		loc.linnum++;
		break;

	    case '"':
		t->len = stringbuffer.offset / sizeof(d_wchar);
		stringbuffer.writewchar(0);
		t->ustring = (wchar_t *)mem.malloc(stringbuffer.offset);
		memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
		return TOKstring;

	    case 0:
	    case 0x1A:
		p--;
		error("unterminated string constant starting at %s", start.toChars());
		t->ustring = L"";
		t->len = 0;
		return TOKstring;
	}
	if (wide)
	    stringbuffer.writewchar(c);
	else
	    stringbuffer.writeByte(c);
    }
}

/**************************************
 */

TOK Lexer::charConstant(Token *t, int wide)
{   integer_t n;
    unsigned c;
    unsigned ndigits;

    p++;
    n = 0;
    ndigits = 0;
    while (1)
    {
	c = *p++;
	switch (c)
	{
	    case '\'':
		t->uns64value = n;
		if (ndigits > 8)
		    error("More than 8 bytes in character constant");
		return (ndigits <= 4) ? TOKuns32 : TOKuns64;

	    case '\\':
		if (*p == 'u' && wide)
		    c = wchar();
		else
		    c = escapeSequence();
		break;

	    case '\n':
		loc.linnum++;
	    case '\r':
	    case 0:
	    case 0x1A:
		error("unterminated character constant");
		return TOKuns32;
	}
	if (wide)
	{
	    ndigits += sizeof(d_wchar);
	    n <<= sizeof(d_wchar) * 8;
	}
	else
	{
	    ndigits++;
	    n <<= 8;
	}
	n |= c;
    }
}

/***************************************
 */

unsigned Lexer::wchar()
{
    unsigned value;
    unsigned n;
    unsigned char c;

    value = 0;
    for (n = 0; 1; n++)
    {
	++p;
	if (n == 4)
	    break;
	c = *p;
	if (!ishex(c))
	{   error("\\u sequence must be followed by 4 hex characters");
	    break;
	}
	if (isdigit(c))
	    c -= '0';
	else if (islower(c))
	    c -= 'a' - 10;
	else
	    c -= 'A' - 10;
	value <<= 4;
	value |= c;
    }
    return value;
}

/**************************************
 * Read in a number.
 * If it's an integer, store it in tok.TKutok.Vlong.
 *	integers can be decimal, octal or hex
 *	Handle the suffixes U, UL, LU, L, etc.
 * If it's double, store it in tok.TKutok.Vdouble.
 * Returns:
 *	TKnum
 *	TKdouble,...
 */

TOK Lexer::number(Token *t)
{
    // We use a state machine to collect numbers
    enum STATE { STATE_initial, STATE_0, STATE_decimal, STATE_octal, STATE_octale,
	STATE_hex, STATE_binary, STATE_hex0, STATE_binary0,
	STATE_hexh, STATE_error };
    enum STATE state;

    enum FLAGS
    {	FLAGS_decimal  = 1,		// decimal
	FLAGS_unsigned = 2,		// u or U suffix
	FLAGS_long     = 4,		// l or L suffix
    };
    enum FLAGS flags = FLAGS_decimal;

    int i;
    int base;
    unsigned c;
    unsigned char *start;
    integer_t n;
    TOK result;

    state = STATE_initial;
    base = 0;
    stringbuffer.reset();
    start = p;
    while (1)
    {
	c = *p;
	switch (state)
	{
	    case STATE_initial:		// opening state
		if (c == '0')
		    state = STATE_0;
		else
		    state = STATE_decimal;
		break;

	    case STATE_0:
		flags &= ~FLAGS_decimal;
		switch (c)
		{
		    case 'H':			// 0h
		    case 'h':
			goto hexh;
		    case 'X':
		    case 'x':
			state = STATE_hex0;
			break;
		    case '.':
			if (p[1] == '.')	// .. is a separate token
			    goto done;
		    case 'i':
			goto real;
		    case 'E':
		    case 'e':
			goto case_hex;

		    case 'B':
		    case 'b':
			state = STATE_binary0;
			break;

		    case '0': case '1': case '2': case '3':
		    case '4': case '5': case '6': case '7':
			state = STATE_octal;
			break;

		    case '8': case '9': case 'A':
		    case 'C': case 'D': case 'F':
		    case 'a': case 'c': case 'd': case 'f':
		    case_hex:
			state = STATE_hexh;
			break;
		    default:
			goto done;
		}
		break;

	    case STATE_decimal:		// reading decimal number
		if (!isdigit(c))
		{
		    if (ishex(c) || c == 'H' || c == 'h')
			goto hexh;
		    if (c == '.' && p[1] != '.')
			goto real;
		    if (c == 'i')
		    {
	    real:	// It's a real number. Back up and rescan as a real
			p = start;
			return inreal(t);
		    }
		    goto done;
		}
		break;

	    case STATE_hex0:		// reading hex number
	    case STATE_hex:
		if (!ishex(c))
		{
		    if (c == '.' && p[1] != '.')
			goto real;
		    if (c == 'P' || c == 'p' || c == 'i')
			goto real;
		    if (state == STATE_hex0)
			error("Hex digit expected, not '%c'", c);
		    goto done;
		}
		state = STATE_hex;
		break;

	    hexh:
		state = STATE_hexh;
	    case STATE_hexh:		// parse numbers like 0FFh
		if (!ishex(c))
		{
		    if (c == 'H' || c == 'h')
		    {
			p++;
			base = 16;
			goto done;
		    }
		    else
		    {
			// Check for something like 1E3 or 0E24
			if (memchr((char *)stringbuffer.data, 'E', stringbuffer.offset) ||
			    memchr((char *)stringbuffer.data, 'e', stringbuffer.offset))
			    goto real;
			error("Hex digit expected, not '%c'", c);
			goto done;
		    }
		}
		break;

	    case STATE_octal:		// reading octal number
	    case STATE_octale:		// reading octal number with non-octal digits
		if (!isoctal(c))
		{   if (ishex(c) || c == 'H' || c == 'h')
			goto hexh;
		    if (c == '.' && p[1] != '.')
			goto real;
		    if (c == 'i')
			goto real;
		    if (isdigit(c))
		    {
			state = STATE_octale;
		    }
		    else
			goto done;
		}
		break;

	    case STATE_binary0:		// starting binary number
	    case STATE_binary:		// reading binary number
		if (c != '0' && c != '1')
		{   if (ishex(c) || c == 'H' || c == 'h')
			goto hexh;
		    if (state == STATE_binary0)
		    {	error("binary digit expected");
			state = STATE_error;
			break;
		    }
		    else
			goto done;
		}
		state = STATE_binary;
		break;

	    case STATE_error:		// for error recovery
		if (!isdigit(c))	// scan until non-digit
		    goto done;
		break;

	    default:
		assert(0);
	}
	stringbuffer.writeByte(c);
	p++;
    }
done:
    stringbuffer.writeByte(0);		// terminate string
    if (state == STATE_octale)
	error("Octal digit expected");

    errno = 0;
    if (stringbuffer.offset == 1 && (state == STATE_decimal || state == STATE_0))
	n = stringbuffer.data[0] - '0';
    else
    {
	// convert string to integer
#if __DMC__
	n = strtoull((char *)stringbuffer.data,NULL,base);
#else
	n = strtoul((char *)stringbuffer.data,NULL,base);
#endif
    }
    if (errno == ERANGE)		// if overflow
	error("integer overflow");

    // Parse trailing 'u', 'U', 'l' or 'L' in any combination
    while (1)
    {   unsigned char f;

	switch (*p)
	{   case 'U':
	    case 'u':
		f = FLAGS_unsigned;
		goto L1;
	    case 'L':
	    case 'l':
		f = FLAGS_long;
	    L1:
		p++;
		if (flags & f)
		    error("unrecognized token");
		flags |= f;
		continue;
	    default:
		break;
	}
	break;
    }

    assert(sizeof(long) == 4);	// some dependencies
    switch (flags)
    {
	case 0:
	    if (n & 0x8000000000000000)
		    result = TOKuns64v;
	    else if (n & 0xFFFFFFFF00000000)
		    result = TOKint64v;
	    else if (n & 0x80000000)
		    result = TOKuns32v;
	    else
		    result = TOKint32v;
	    break;

	case FLAGS_decimal:
	    if (n & 0x8000000000000000)
		    result = TOKuns64v;
	    else if (n & 0xFFFFFFFF80000000)
		    result = TOKint64v;
	    else
		    result = TOKint32v;
	    break;

	case FLAGS_unsigned:
	case FLAGS_decimal | FLAGS_unsigned:
	    if (n & 0xFFFFFFFF00000000)
		    result = TOKuns64v;
	    else
		    result = TOKuns32v;
	    break;

	case FLAGS_long:
	case FLAGS_decimal | FLAGS_long:
	    if (n & 0x8000000000000000)
		    result = TOKuns64v;
	    else
		    result = TOKint64v;
	    break;

	case FLAGS_unsigned | FLAGS_long:
	case FLAGS_decimal | FLAGS_unsigned | FLAGS_long:
	    result = TOKuns64v;
	    break;

	default:
	    #ifdef DEBUG
		printf("%x\n",flags);
	    #endif
	    assert(0);
    }
    t->uns64value = n;
    return result;
}

/**************************************
 * Read in characters, converting them to real.
 * Bugs:
 *	Exponent overflow not detected.
 *	Too much requested precision is not detected.
 */

TOK Lexer::inreal(Token *t)
__in
{
    assert(*p == '.' || isdigit(*p));
}
__out (result)
{
    assert(result == TOKfloat32v || result == TOKfloat64v || result == TOKfloat80v || result == TOKimaginaryv);
}
__body
{   int dblstate;
    unsigned c;
    char hex;			// is this a hexadecimal-floating-constant?
    TOK result;

    stringbuffer.reset();
    dblstate = 0;
    hex = 0;
    while (1)
    {
	// Get next char from input
	c = *p++;
	while (1)
	{
	    switch (dblstate)
	    {
		case 0:			// opening state
		    if (c == '0')
			dblstate = 9;
		    else
			dblstate = 1;
		    break;

		case 9:
		    dblstate = 1;
		    if (c == 'X' || c == 'x')
		    {	hex++;
			break;
		    }
		case 1:			// digits to left of .
		case 3:			// digits to right of .
		case 7:			// continuing exponent digits
		    if (!isdigit(c) && !(hex && isxdigit(c)))
		    {   dblstate++;
			continue;
		    }
		    break;

		case 2:			// no more digits to left of .
		    if (c == '.')
		    {   dblstate++;
			break;
		    }
		case 4:			// no more digits to right of .
		    if ((c == 'E' || c == 'e') ||
			hex && (c == 'P' || c == 'p'))
		    {   dblstate = 5;
			hex = 0;	// exponent is always decimal
			break;
		    }
		    if (hex)
			error("binary-exponent-part required");
		    goto done;

		case 5:			// looking immediately to right of E
		    dblstate++;
		    if (c == '-' || c == '+')
			break;
		case 6:			// 1st exponent digit expected
		    if (!isdigit(c))
			error("exponent expected");
		    dblstate++;
		    break;

		case 8:			// past end of exponent digits
		    goto done;
	    }
	    break;
	}
	stringbuffer.writeByte(c);
    }
done:
    p--;

    stringbuffer.writeByte(0);
    errno = 0;

#if _WIN32 && __DMC__
    char *save = __locale_decpoint;
    __locale_decpoint = ".";
#endif
    switch (*p)
    {
	case 'F':
	case 'f':
	    t->float80value = strtof((char *)stringbuffer.data, NULL);
	    result = TOKfloat32v;
	    p++;
	    break;

	default:
	    t->float80value = strtod((char *)stringbuffer.data, NULL);
	    result = TOKfloat64v;
	    break;

	case 'L':
	case 'l':
	    t->float80value = strtold((char *)stringbuffer.data, NULL);
	    result = TOKfloat80v;
	    p++;
	    break;
    }
    if (*p == 'i' || *p == 'I')
    {
	p++;
	result = TOKimaginaryv;
    }
#if _WIN32 && __DMC__
    __locale_decpoint = save;
#endif
    if (errno == ERANGE)
	error("number is not representable");
    return result;
}

/********************************************
 * Create an identifier in the string table.
 */

Identifier *Lexer::idPool(const char *s)
{   unsigned len;
    Identifier *id;
    StringValue *sv;

    len = strlen(s);
    sv = stringtable.update(s, len);
    id = (Identifier *) sv->ptrvalue;
    if (!id)
    {
	id = new Identifier(sv->lstring.string, TOKidentifier);
	sv->ptrvalue = id;
    }
    return id;
}

/****************************************
 */

struct Keyword
{   char *name;
    enum TOK value;
};

static Keyword keywords[] =
{
//    {	"",		TOK	},

    {	"this",		TOKthis		},
    {	"super",	TOKsuper	},
    {	"assert",	TOKassert	},
    {	"null",		TOKnull		},
    {	"true",		TOKtrue		},
    {	"false",	TOKfalse	},
    {	"cast",		TOKcast		},
    {	"new",		TOKnew		},
    {	"delete",	TOKdelete	},
    {	"throw",	TOKthrow	},
    {	"module",	TOKmodule	},

    {	"template",	TOKtemplate	},
    {	"instance",	TOKinstance	},

    {	"void",		TOKvoid		},
    {	"byte",		TOKint8		},
    {	"ubyte",	TOKuns8		},
    {	"short",	TOKint16	},
    {	"ushort",	TOKuns16	},
    {	"int",		TOKint32	},
    {	"uint",		TOKuns32	},
    {	"long",		TOKint64	},
    {	"ulong",	TOKuns64	},
    {	"float",	TOKfloat32	},
    {	"double",	TOKfloat64	},
    {	"extended",	TOKfloat80	},

    {	"bit",		TOKbit		},
    {	"char",		TOKascii	},	// obsolete
    {	"wchar",	TOKwchar	},

    {	"imaginary",	TOKimaginary	},
    {	"complex",	TOKcomplex	},
    {	"delegate",	TOKdelegate	},

    {	"if",		TOKif		},
    {	"else",		TOKelse		},
    {	"while",	TOKwhile	},
    {	"for",		TOKfor		},
    {	"do",		TOKdo		},
    {	"switch",	TOKswitch	},
    {	"case",		TOKcase		},
    {	"default",	TOKdefault	},
    {	"break",	TOKbreak	},
    {	"continue",	TOKcontinue	},
    {	"synchronized",	TOKsynchronized	},
    {	"return",	TOKreturn	},
    {	"goto",		TOKgoto		},
    {	"try",		TOKtry		},
    {	"catch",	TOKcatch	},
    {	"finally",	TOKfinally	},
    {	"with",		TOKwith		},
    {	"asm",		TOKasm		},

    {	"struct",	TOKstruct	},
    {	"class",	TOKclass	},
    {	"interface",	TOKinterface	},
    {	"union",	TOKunion	},
    {	"enum",		TOKenum		},
    {	"import",	TOKimport	},
    {	"static",	TOKstatic	},
    /*{	"virtual",	TOKvirtual	},*/
    {	"final",	TOKfinal	},
    {	"const",	TOKconst	},
    {	"typedef",	TOKtypedef	},
    {	"alias",	TOKalias	},
    {	"override",	TOKoverride	},
    {	"abstract",	TOKabstract	},
    {	"volatile",	TOKvolatile	},
    {	"debug",	TOKdebug	},
    {	"deprecated",	TOKdeprecated	},
    {	"in",		TOKin		},
    {	"out",		TOKout		},
    {	"inout",	TOKinout	},
    {	"auto",		TOKauto		},

    {	"align",	TOKalign	},
    {	"extern",	TOKextern	},
    {	"private",	TOKprivate	},
    {	"protected",	TOKprotected	},
    {	"public",	TOKpublic	},
    {	"export",	TOKexport	},

    {	"body",		TOKbody		},
    {	"invariant",	TOKinvariant	},
    {	"unittest",	TOKunittest	},
    {	"version",	TOKversion	},
};

void Lexer::initKeywords()
{   StringValue *sv;
    unsigned u;
    enum TOK v;

    for (u = 0; u < sizeof(keywords) / sizeof(keywords[0]); u++)
    {	char *s;

	//printf("keyword[%d] = '%s'\n",u, keywords[u].name);
	s = keywords[u].name;
	v = keywords[u].value;
	sv = stringtable.insert(s, strlen(s));
	sv->ptrvalue = (void *) new Identifier(sv->lstring.string,v);

	//printf("tochars[%d] = '%s'\n",v, s);
	Token::tochars[v] = s;
    }

    Token::tochars[TOKeof]		= "EOF";
    Token::tochars[TOKlcurly]		= "{";
    Token::tochars[TOKrcurly]		= "}";
    Token::tochars[TOKlparen]		= "(";
    Token::tochars[TOKrparen]		= ")";
    Token::tochars[TOKlbracket]		= "[";
    Token::tochars[TOKrbracket]		= "]";
    Token::tochars[TOKsemicolon]	= ";";
    Token::tochars[TOKcolon]		= ":";
    Token::tochars[TOKcomma]		= ",";
    Token::tochars[TOKdot]		= ".";
    Token::tochars[TOKxor]		= "^";
    Token::tochars[TOKxorass]		= "^=";
    Token::tochars[TOKassign]		= "=";
    Token::tochars[TOKlt]		= "<";
    Token::tochars[TOKgt]		= ">";
    Token::tochars[TOKle]		= "<=";
    Token::tochars[TOKge]		= ">=";
    Token::tochars[TOKequal]		= "==";
    Token::tochars[TOKnotequal]		= "!=";
    Token::tochars[TOKidentity]		= "===";
    Token::tochars[TOKnotidentity]	= "!==";

    Token::tochars[TOKunord]		= "!<>=";
    Token::tochars[TOKue]		= "!<>";
    Token::tochars[TOKlg]		= "<>";
    Token::tochars[TOKleg]		= "<>=";
    Token::tochars[TOKule]		= "!>";
    Token::tochars[TOKul]		= "!>=";
    Token::tochars[TOKuge]		= "!<";
    Token::tochars[TOKug]		= "!<=";

    Token::tochars[TOKnot]		= "!";
    Token::tochars[TOKshl]		= "<<";
    Token::tochars[TOKshr]		= ">>";
    Token::tochars[TOKushr]		= ">>>";
    Token::tochars[TOKadd]		= "+";
    Token::tochars[TOKmin]		= "-";
    Token::tochars[TOKmul]		= "*";
    Token::tochars[TOKdiv]		= "/";
    Token::tochars[TOKmod]		= "%";
    Token::tochars[TOKrange]		= "..";
    Token::tochars[TOKdotdotdot]	= "...";
    Token::tochars[TOKand]		= "&";
    Token::tochars[TOKandand]		= "&&";
    Token::tochars[TOKor]		= "|";
    Token::tochars[TOKoror]		= "||";
    Token::tochars[TOKarray]		= "[]";
    Token::tochars[TOKaddress]		= "#";
    Token::tochars[TOKstar]		= "*";
    Token::tochars[TOKcast]		= "cast";
    Token::tochars[TOKplusplus]		= "++";
    Token::tochars[TOKminusminus]	= "--";
    Token::tochars[TOKtype]		= "type";
    Token::tochars[TOKquestion]		= "?";
    Token::tochars[TOKneg]		= "neg";
    Token::tochars[TOKvar]		= "var";
    Token::tochars[TOKaddass]		= "+=";
    Token::tochars[TOKcat]		= "~";
    Token::tochars[TOKcatass]		= "~=";
    Token::tochars[TOKcall]		= "call";

     // For debugging
    Token::tochars[TOKdotvar]		= "dotvar";
}
