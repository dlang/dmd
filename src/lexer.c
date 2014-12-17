
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
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
#include <stdlib.h>
#include <assert.h>
#include <time.h>       // for time() and ctime()

#include "rmem.h"

#include "stringtable.h"

#include "lexer.h"
#include "utf.h"
#include "identifier.h"
#include "id.h"
#include "module.h"

#if _WIN32 && __DMC__
// from \dm\src\include\setlocal.h
extern "C" const char * __cdecl __locale_decpoint;
#endif

extern int HtmlNamedEntity(unsigned char *p, int length);

#define LS 0x2028       // UTF line separator
#define PS 0x2029       // UTF paragraph separator

void unittest_lexer();

/********************************************
 * Do our own char maps
 */

static unsigned char cmtable[256];

const int CMoctal =     0x1;
const int CMhex =       0x2;
const int CMidchar =    0x4;

inline unsigned char isoctal (unsigned char c) { return cmtable[c] & CMoctal; }
inline unsigned char ishex   (unsigned char c) { return cmtable[c] & CMhex; }
inline unsigned char isidchar(unsigned char c) { return cmtable[c] & CMidchar; }

static void cmtable_init()
{
    for (unsigned c = 0; c < sizeof(cmtable) / sizeof(cmtable[0]); c++)
    {
        if ('0' <= c && c <= '7')
            cmtable[c] |= CMoctal;
        if (isdigit(c) || ('a' <= c && c <= 'f') || ('A' <= c && c <= 'F'))
            cmtable[c] |= CMhex;
        if (isalnum(c) || c == '_')
            cmtable[c] |= CMidchar;
    }
}


/************************* Token **********************************************/

const char *Token::tochars[TOKMAX];

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

#ifdef DEBUG
void Token::print()
{
    fprintf(stdmsg, "%s\n", toChars());
}
#endif

const char *Token::toChars()
{   const char *p;
    static char buffer[3 + 3 * sizeof(float80value) + 1];

    p = buffer;
    switch (value)
    {
        case TOKint32v:
#if IN_GCC
            sprintf(buffer,"%d",(d_int32)int64value);
#else
            sprintf(buffer,"%d",int32value);
#endif
            break;

        case TOKuns32v:
        case TOKcharv:
        case TOKwcharv:
        case TOKdcharv:
#if IN_GCC
            sprintf(buffer,"%uU",(d_uns32)uns64value);
#else
            sprintf(buffer,"%uU",uns32value);
#endif
            break;

        case TOKint64v:
            sprintf(buffer,"%jdL",(intmax_t)int64value);
            break;

        case TOKuns64v:
            sprintf(buffer,"%juUL",(uintmax_t)uns64value);
            break;

#if IN_GCC
        case TOKfloat32v:
        case TOKfloat64v:
        case TOKfloat80v:
            float80value.format(buffer, sizeof(buffer));
            break;
        case TOKimaginary32v:
        case TOKimaginary64v:
        case TOKimaginary80v:
            float80value.format(buffer, sizeof(buffer));
            // %% buffer
            strcat(buffer, "i");
            break;
#else
        case TOKfloat32v:
            sprintf(buffer,"%Lgf", float80value);
            break;

        case TOKfloat64v:
            sprintf(buffer,"%Lg", float80value);
            break;

        case TOKfloat80v:
            sprintf(buffer,"%LgL", float80value);
            break;

        case TOKimaginary32v:
            sprintf(buffer,"%Lgfi", float80value);
            break;

        case TOKimaginary64v:
            sprintf(buffer,"%Lgi", float80value);
            break;

        case TOKimaginary80v:
            sprintf(buffer,"%LgLi", float80value);
            break;
#endif

        case TOKstring:
#if CSTRINGS
            p = string;
#else
        {   OutBuffer buf;

            buf.writeByte('"');
            for (size_t i = 0; i < len; )
            {   unsigned c;

                utf_decodeChar((unsigned char *)ustring, len, &i, &c);
                switch (c)
                {
                    case 0:
                        break;

                    case '"':
                    case '\\':
                        buf.writeByte('\\');
                    default:
                        if (isprint(c))
                            buf.writeByte(c);
                        else if (c <= 0x7F)
                            buf.printf("\\x%02x", c);
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
                buf.writeByte('"');
            buf.writeByte(0);
            p = (char *)buf.extractData();
        }
#endif
            break;

        case TOKidentifier:
        case TOKenum:
        case TOKstruct:
        case TOKimport:
        case BASIC_TYPES:
            p = ident->toChars();
            break;

        default:
            p = toChars(value);
            break;
    }
    return p;
}

const char *Token::toChars(enum TOK value)
{   const char *p;
    static char buffer[3 + 3 * sizeof(value) + 1];

    p = tochars[value];
    if (!p)
    {   sprintf(buffer,"TOK%d",value);
        p = buffer;
    }
    return p;
}

/*************************** Lexer ********************************************/

Token *Lexer::freelist = NULL;
StringTable Lexer::stringtable;
OutBuffer Lexer::stringbuffer;

Lexer::Lexer(Module *mod,
        unsigned char *base, unsigned begoffset, unsigned endoffset,
        int doDocComment, int commentToken)
    : loc(mod, 1)
{
    //printf("Lexer::Lexer(%p,%d)\n",base,length);
    //printf("lexer.mod = %p, %p\n", mod, this->loc.mod);
    memset(&token,0,sizeof(token));
    this->base = base;
    this->end  = base + endoffset;
    p = base + begoffset;
    this->mod = mod;
    this->doDocComment = doDocComment;
    this->anyToken = 0;
    this->commentToken = commentToken;
    //initKeywords();

    /* If first line starts with '#!', ignore the line
     */

    if (p[0] == '#' && p[1] =='!')
    {
        p += 2;
        while (1)
        {   unsigned char c = *p;
            switch (c)
            {
                case '\n':
                    p++;
                    break;

                case '\r':
                    p++;
                    if (*p == '\n')
                        p++;
                    break;

                case 0:
                case 0x1A:
                    break;

                default:
                    if (c & 0x80)
                    {   unsigned u = decodeUTF();
                        if (u == PS || u == LS)
                            break;
                    }
                    p++;
                    continue;
            }
            break;
        }
        loc.linnum = 2;
    }
}


void Lexer::error(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::verror(tokenLoc(), format, ap);
    va_end(ap);
}

void Lexer::error(Loc loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::verror(loc, format, ap);
    va_end(ap);
}

void Lexer::deprecation(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::vdeprecation(tokenLoc(), format, ap);
    va_end(ap);
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

/***********************
 * Look ahead at next token's value.
 */

TOK Lexer::peekNext()
{
    return peek(&token)->value;
}

/***********************
 * Look 2 tokens ahead at value.
 */

TOK Lexer::peekNext2()
{
    Token *t = peek(&token);
    return peek(t)->value;
}

/*********************************
 * tk is on the opening (.
 * Look ahead and return token that is past the closing ).
 */

Token *Lexer::peekPastParen(Token *tk)
{
    //printf("peekPastParen()\n");
    int parens = 1;
    int curlynest = 0;
    while (1)
    {
        tk = peek(tk);
        //tk->print();
        switch (tk->value)
        {
            case TOKlparen:
                parens++;
                continue;

            case TOKrparen:
                --parens;
                if (parens)
                    continue;
                tk = peek(tk);
                break;

            case TOKlcurly:
                curlynest++;
                continue;

            case TOKrcurly:
                if (--curlynest >= 0)
                    continue;
                break;

            case TOKsemicolon:
                if (curlynest)
                    continue;
                break;

            case TOKeof:
                break;

            default:
                continue;
        }
        return tk;
    }
}

/**********************************
 * Determine if string is a valid Identifier.
 * Placed here because of commonality with Lexer functionality.
 * Returns:
 *      0       invalid
 */

int Lexer::isValidIdentifier(char *p)
{
    size_t len;
    size_t idx;

    if (!p || !*p)
        goto Linvalid;

    if (*p >= '0' && *p <= '9')         // beware of isdigit() on signed chars
        goto Linvalid;

    len = strlen(p);
    idx = 0;
    while (p[idx])
    {   dchar_t dc;

        const char *q = utf_decodeChar((unsigned char *)p, len, &idx, &dc);
        if (q)
            goto Linvalid;

        if (!((dc >= 0x80 && isUniAlpha(dc)) || isalnum(dc) || dc == '_'))
            goto Linvalid;
    }
    return 1;

Linvalid:
    return 0;
}

/****************************
 * Turn next token in buffer into a token.
 */

void Lexer::scan(Token *t)
{
    unsigned lastLine = loc.linnum;
    unsigned linnum;

    t->blockComment = NULL;
    t->lineComment = NULL;
    while (1)
    {
        t->ptr = p;
        //printf("p = %p, *p = '%c'\n",p,*p);
        switch (*p)
        {
            case 0:
            case 0x1A:
                t->value = TOKeof;                      // end of file
                return;

            case ' ':
            case '\t':
            case '\v':
            case '\f':
                p++;
                continue;                       // skip white space

            case '\r':
                p++;
                if (*p != '\n')                 // if CR stands by itself
                    loc.linnum++;
                continue;                       // skip white space

            case '\n':
                p++;
                loc.linnum++;
                continue;                       // skip white space

            case '0':   case '1':   case '2':   case '3':   case '4':
            case '5':   case '6':   case '7':   case '8':   case '9':
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
                t->value = charConstant(t,0);
                return;

            case 'r':
                if (p[1] != '"')
                    goto case_ident;
                p++;
            case '`':
                t->value = wysiwygStringConstant(t, *p);
                return;

            case 'x':
                if (p[1] != '"')
                    goto case_ident;
                p++;
                t->value = hexStringConstant(t);
                return;

#if DMDV2
            case 'q':
                if (p[1] == '"')
                {
                    p++;
                    t->value = delimitedStringConstant(t);
                    return;
                }
                else if (p[1] == '{')
                {
                    p++;
                    t->value = tokenStringConstant(t);
                    return;
                }
                else
                    goto case_ident;
#endif

            case '"':
                t->value = escapeStringConstant(t,0);
                return;

#if ! TEXTUAL_ASSEMBLY_OUT
            case '\\':                  // escaped string literal
            {   unsigned c;
                unsigned char *pstart = p;

                stringbuffer.reset();
                do
                {
                    p++;
                    switch (*p)
                    {
                        case 'u':
                        case 'U':
                        case '&':
                            c = escapeSequence();
                            stringbuffer.writeUTF8(c);
                            break;

                        default:
                            c = escapeSequence();
                            stringbuffer.writeByte(c);
                            break;
                    }
                } while (*p == '\\');
                t->len = stringbuffer.offset;
                stringbuffer.writeByte(0);
                t->ustring = (unsigned char *)mem.malloc(stringbuffer.offset);
                memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
                t->postfix = 0;
                t->value = TOKstring;
#if DMDV2
                deprecation("Escape String literal %.*s is deprecated, use double quoted string literal \"%.*s\" instead", p - pstart, pstart, p - pstart, pstart);
#endif
                return;
            }
#endif

            case 'l':
            case 'L':
#endif
            case 'a':   case 'b':   case 'c':   case 'd':   case 'e':
            case 'f':   case 'g':   case 'h':   case 'i':   case 'j':
            case 'k':               case 'm':   case 'n':   case 'o':
#if DMDV2
            case 'p':   /*case 'q': case 'r':*/ case 's':   case 't':
#else
            case 'p':   case 'q': /*case 'r':*/ case 's':   case 't':
#endif
            case 'u':   case 'v':   case 'w': /*case 'x':*/ case 'y':
            case 'z':
            case 'A':   case 'B':   case 'C':   case 'D':   case 'E':
            case 'F':   case 'G':   case 'H':   case 'I':   case 'J':
            case 'K':               case 'M':   case 'N':   case 'O':
            case 'P':   case 'Q':   case 'R':   case 'S':   case 'T':
            case 'U':   case 'V':   case 'W':   case 'X':   case 'Y':
            case 'Z':
            case '_':
            case_ident:
            {   unsigned char c;

                while (1)
                {
                    c = *++p;
                    if (isidchar(c))
                        continue;
                    else if (c & 0x80)
                    {   unsigned char *s = p;
                        unsigned u = decodeUTF();
                        if (isUniAlpha(u))
                            continue;
                        error("char 0x%04x not allowed in identifier", u);
                        p = s;
                    }
                    break;
                }

                StringValue *sv = stringtable.update((char *)t->ptr, p - t->ptr);
                Identifier *id = (Identifier *) sv->ptrvalue;
                if (!id)
                {   id = new Identifier(sv->toDchars(),TOKidentifier);
                    sv->ptrvalue = id;
                }
                t->ident = id;
                t->value = (enum TOK) id->value;
                if (t->value == TOKD2kwd)
                {
                    if ((global.params.enabledV2hints & V2MODEsyntax) && mod && mod->isRoot())
                        warning(loc, "%s is a D2 keyword [-v2=%s]", id->toChars(),
                                V2MODE_name(V2MODEsyntax));
                    t->value = TOKidentifier;
                }
                anyToken = 1;
                if (*t->ptr == '_')     // if special identifier token
                {
                    static char date[11+1];
                    static char time[8+1];
                    static char timestamp[24+1];

                    if (!date[0])       // lazy evaluation
                    {   time_t t;
                        char *p;

                        ::time(&t);
                        p = ctime(&t);
                        assert(p);
                        sprintf(date, "%.6s %.4s", p + 4, p + 20);
                        sprintf(time, "%.8s", p + 11);
                        sprintf(timestamp, "%.24s", p);
                    }

                    if (id == Id::DATE)
                    {
                        t->ustring = (unsigned char *)date;
                        goto Lstr;
                    }
                    else if (id == Id::TIME)
                    {
                        t->ustring = (unsigned char *)time;
                        goto Lstr;
                    }
                    else if (id == Id::VENDOR)
                    {
                        t->ustring = (unsigned char *)"Digital Mars D";
                        goto Lstr;
                    }
                    else if (id == Id::TIMESTAMP)
                    {
                        t->ustring = (unsigned char *)timestamp;
                     Lstr:
                        t->value = TOKstring;
                        t->postfix = 0;
                        t->len = strlen((char *)t->ustring);
                    }
                    else if (id == Id::VERSIONX)
                    {   unsigned major = 0;
                        unsigned minor = 0;
                        bool point = false;

                        for (const char *p = global.version + 1; 1; p++)
                        {
                            char c = *p;
                            if (isdigit((unsigned char)c))
                                minor = minor * 10 + c - '0';
                            else if (c == '.')
                            {
                                if (point)
                                    break;      // ignore everything after second '.'
                                point = true;
                                major = minor;
                                minor = 0;
                            }
                            else
                                break;
                        }
                        t->value = TOKint64v;
                        t->uns64value = major * 1000 + minor;
                    }
#if DMDV2
                    else if (id == Id::EOFX)
                    {
                        t->value = TOKeof;
                        // Advance scanner to end of file
                        while (!(*p == 0 || *p == 0x1A))
                            p++;
                    }
#endif
                }
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
                        linnum = loc.linnum;
                        while (1)
                        {
                            while (1)
                            {   unsigned char c = *p;
                                switch (c)
                                {
                                    case '/':
                                        break;

                                    case '\n':
                                        loc.linnum++;
                                        p++;
                                        continue;

                                    case '\r':
                                        p++;
                                        if (*p != '\n')
                                            loc.linnum++;
                                        continue;

                                    case 0:
                                    case 0x1A:
                                        error("unterminated /* */ comment");
                                        p = end;
                                        t->value = TOKeof;
                                        return;

                                    default:
                                        if (c & 0x80)
                                        {   unsigned u = decodeUTF();
                                            if (u == PS || u == LS)
                                                loc.linnum++;
                                        }
                                        p++;
                                        continue;
                                }
                                break;
                            }
                            p++;
                            if (p[-2] == '*' && p - 3 != t->ptr)
                                break;
                        }
                        if (commentToken)
                        {
                            t->value = TOKcomment;
                            return;
                        }
                        else if (doDocComment && t->ptr[2] == '*' && p - 4 != t->ptr)
                        {   // if /** but not /**/
                            getDocComment(t, lastLine == linnum);
                        }
                        continue;

                    case '/':           // do // style comments
                        linnum = loc.linnum;
                        while (1)
                        {   unsigned char c = *++p;
                            switch (c)
                            {
                                case '\n':
                                    break;

                                case '\r':
                                    if (p[1] == '\n')
                                        p++;
                                    break;

                                case 0:
                                case 0x1A:
                                    if (commentToken)
                                    {
                                        p = end;
                                        t->value = TOKcomment;
                                        return;
                                    }
                                    if (doDocComment && t->ptr[2] == '/')
                                        getDocComment(t, lastLine == linnum);
                                    p = end;
                                    t->value = TOKeof;
                                    return;

                                default:
                                    if (c & 0x80)
                                    {   unsigned u = decodeUTF();
                                        if (u == PS || u == LS)
                                            break;
                                    }
                                    continue;
                            }
                            break;
                        }

                        if (commentToken)
                        {
                            p++;
                            loc.linnum++;
                            t->value = TOKcomment;
                            return;
                        }
                        if (doDocComment && t->ptr[2] == '/')
                            getDocComment(t, lastLine == linnum);

                        p++;
                        loc.linnum++;
                        continue;

                    case '+':
                    {   int nest;

                        linnum = loc.linnum;
                        p++;
                        nest = 1;
                        while (1)
                        {   unsigned char c = *p;
                            switch (c)
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

                                case '\r':
                                    p++;
                                    if (*p != '\n')
                                        loc.linnum++;
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
                                    if (c & 0x80)
                                    {   unsigned u = decodeUTF();
                                        if (u == PS || u == LS)
                                            loc.linnum++;
                                    }
                                    p++;
                                    continue;
                            }
                            break;
                        }
                        if (commentToken)
                        {
                            t->value = TOKcomment;
                            return;
                        }
                        if (doDocComment && t->ptr[2] == '+' && p - 4 != t->ptr)
                        {   // if /++ but not /++/
                            getDocComment(t, lastLine == linnum);
                        }
                        continue;
                    }
                    default:
                        break;
                }
                t->value = TOKdiv;
                return;

            case '.':
                p++;
                if (isdigit(*p))
                {   /* Note that we don't allow ._1 and ._ as being
                     * valid floating point numbers.
                     */
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
                        t->value = TOKslice;
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
                    t->value = TOKle;                   // <=
                }
                else if (*p == '<')
                {   p++;
                    if (*p == '=')
                    {   p++;
                        t->value = TOKshlass;           // <<=
                    }
                    else
                        t->value = TOKshl;              // <<
                }
                else if (*p == '>')
                {   p++;
                    if (*p == '=')
                    {   p++;
                        t->value = TOKleg;              // <>=
                    }
                    else
                        t->value = TOKlg;               // <>
                }
                else
                    t->value = TOKlt;                   // <
                return;

            case '>':
                p++;
                if (*p == '=')
                {   p++;
                    t->value = TOKge;                   // >=
                }
                else if (*p == '>')
                {   p++;
                    if (*p == '=')
                    {   p++;
                        t->value = TOKshrass;           // >>=
                    }
                    else if (*p == '>')
                    {   p++;
                        if (*p == '=')
                        {   p++;
                            t->value = TOKushrass;      // >>>=
                        }
                        else
                            t->value = TOKushr;         // >>>
                    }
                    else
                        t->value = TOKshr;              // >>
                }
                else
                    t->value = TOKgt;                   // >
                return;

            case '!':
                p++;
                if (*p == '=')
                {   p++;
                    if (*p == '=' && global.params.Dversion == 1)
                    {   p++;
                        t->value = TOKnotidentity;      // !==
                    }
                    else
                        t->value = TOKnotequal;         // !=
                }
                else if (*p == '<')
                {   p++;
                    if (*p == '>')
                    {   p++;
                        if (*p == '=')
                        {   p++;
                            t->value = TOKunord; // !<>=
                        }
                        else
                            t->value = TOKue;   // !<>
                    }
                    else if (*p == '=')
                    {   p++;
                        t->value = TOKug;       // !<=
                    }
                    else
                        t->value = TOKuge;      // !<
                }
                else if (*p == '>')
                {   p++;
                    if (*p == '=')
                    {   p++;
                        t->value = TOKul;       // !>=
                    }
                    else
                        t->value = TOKule;      // !>
                }
                else
                    t->value = TOKnot;          // !
                return;

            case '=':
                p++;
                if (*p == '=')
                {   p++;
                    if (*p == '=' && global.params.Dversion == 1)
                    {   p++;
                        t->value = TOKidentity;         // ===
                    }
                    else
                        t->value = TOKequal;            // ==
                }
#if DMDV2
                else if (*p == '>')
                {   p++;
                    t->value = TOKgoesto;               // =>
                }
#endif
                else
                    t->value = TOKassign;               // =
                return;

            case '~':
                p++;
                if (*p == '=')
                {   p++;
                    t->value = TOKcatass;               // ~=
                }
                else
                    t->value = TOKtilde;                // ~
                return;

#if DMDV2
            case '^':
                p++;
                if (*p == '^')
                {   p++;
                    if (*p == '=')
                    {   p++;
                        t->value = TOKpowass;  // ^^=
                    }
                    else
                        t->value = TOKpow;     // ^^
                }
                else if (*p == '=')
                {   p++;
                    t->value = TOKxorass;    // ^=
                }
                else
                    t->value = TOKxor;       // ^
                return;
#endif

#define SINGLE(c,tok) case c: p++; t->value = tok; return;

            SINGLE('(', TOKlparen)
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
            SINGLE('@', TOKat)
#undef SINGLE

#define DOUBLE(c1,tok1,c2,tok2)         \
            case c1:                    \
                p++;                    \
                if (*p == c2)           \
                {   p++;                \
                    t->value = tok2;    \
                }                       \
                else                    \
                    t->value = tok1;    \
                return;

            DOUBLE('*', TOKmul, '=', TOKmulass)
            DOUBLE('%', TOKmod, '=', TOKmodass)
#if DMDV1
            DOUBLE('^', TOKxor, '=', TOKxorass)
#endif
#undef DOUBLE

            case '#':
                p++;
                pragma();
                continue;

            default:
            {   unsigned c = *p;

                if (c & 0x80)
                {   c = decodeUTF();

                    // Check for start of unicode identifier
                    if (isUniAlpha(c))
                        goto case_ident;

                    if (c == PS || c == LS)
                    {
                        loc.linnum++;
                        p++;
                        continue;
                    }
                }
                if (c < 0x80 && isprint(c))
                    error("unsupported char '%c'", c);
                else
                    error("unsupported char 0x%02x", c);
                p++;
                continue;
            }
        }
    }
}

/*******************************************
 * Parse escape sequence.
 */

unsigned Lexer::escapeSequence()
{   unsigned c = *p;

#ifdef TEXTUAL_ASSEMBLY_OUT
    return c;
#endif
    int n;
    int ndigits;

    switch (c)
    {
        case '\'':
        case '"':
        case '?':
        case '\\':
        Lconsume:
                p++;
                break;

        case 'a':       c = 7;          goto Lconsume;
        case 'b':       c = 8;          goto Lconsume;
        case 'f':       c = 12;         goto Lconsume;
        case 'n':       c = 10;         goto Lconsume;
        case 'r':       c = 13;         goto Lconsume;
        case 't':       c = 9;          goto Lconsume;
        case 'v':       c = 11;         goto Lconsume;

        case 'u':
                ndigits = 4;
                goto Lhex;
        case 'U':
                ndigits = 8;
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
                    if (ndigits != 2 && !utf_isValidDchar(v))
                    {   error("invalid UTF character \\U%08x", v);
                        v = '?';        // recover with valid UTF character
                    }
                    c = v;
                }
                else
                    error("undefined escape hex sequence \\%c\n",c);
                break;

        case '&':                       // named character entity
                for (unsigned char *idstart = ++p; 1; p++)
                {
                    switch (*p)
                    {
                        case ';':
                            c = HtmlNamedEntity(idstart, p - idstart);
                            if (c == ~0)
                            {   error("unnamed character entity &%.*s;", (int)(p - idstart), idstart);
                                c = ' ';
                            }
                            p++;
                            break;

                        default:
                            if (isalpha(*p) ||
                                (p != idstart + 1 && isdigit(*p)))
                                continue;
                            error("unterminated named entity");
                            break;
                    }
                    break;
                }
                break;

        case 0:
        case 0x1A:                      // end of file
                c = '\\';
                break;

        default:
                if (isoctal(c))
                {   unsigned v;

                    n = 0;
                    v = 0;
                    do
                    {
                        v = v * 8 + (c - '0');
                        c = *++p;
                    } while (++n < 3 && isoctal(c));
                    c = v;
                    if (c > 0xFF)
                        error("0%03o is larger than a byte", c);
                }
                else
                    error("undefined escape sequence \\%c\n",c);
                break;
    }
    return c;
}

/**************************************
 */

TOK Lexer::wysiwygStringConstant(Token *t, int tc)
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
                    continue;   // ignore
                c = '\n';       // treat EndOfLine as \n character
                loc.linnum++;
                break;

            case 0:
            case 0x1A:
                error("unterminated string constant starting at %s", start.toChars());
                t->ustring = (unsigned char *)"";
                t->len = 0;
                t->postfix = 0;
                return TOKstring;

            case '"':
            case '`':
                if (c == tc)
                {
                    t->len = stringbuffer.offset;
                    stringbuffer.writeByte(0);
                    t->ustring = (unsigned char *)mem.malloc(stringbuffer.offset);
                    memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
                    stringPostfix(t);
                    return TOKstring;
                }
                break;

            default:
                if (c & 0x80)
                {   p--;
                    unsigned u = decodeUTF();
                    p++;
                    if (u == PS || u == LS)
                        loc.linnum++;
                    stringbuffer.writeUTF8(u);
                    continue;
                }
                break;
        }
        stringbuffer.writeByte(c);
    }
}

/**************************************
 * Lex hex strings:
 *      x"0A ae 34FE BD"
 */

TOK Lexer::hexStringConstant(Token *t)
{   unsigned c;
    Loc start = loc;
    unsigned n = 0;
    unsigned v;

    p++;
    stringbuffer.reset();
    while (1)
    {
        c = *p++;
        switch (c)
        {
            case ' ':
            case '\t':
            case '\v':
            case '\f':
                continue;                       // skip white space

            case '\r':
                if (*p == '\n')
                    continue;                   // ignore
                // Treat isolated '\r' as if it were a '\n'
            case '\n':
                loc.linnum++;
                continue;

            case 0:
            case 0x1A:
                error("unterminated string constant starting at %s", start.toChars());
                t->ustring = (unsigned char *)"";
                t->len = 0;
                t->postfix = 0;
                return TOKstring;

            case '"':
                if (n & 1)
                {   error("odd number (%d) of hex characters in hex string", n);
                    stringbuffer.writeByte(v);
                }
                t->len = stringbuffer.offset;
                stringbuffer.writeByte(0);
                t->ustring = (unsigned char *)mem.malloc(stringbuffer.offset);
                memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
                stringPostfix(t);
                return TOKstring;

            default:
                if (c >= '0' && c <= '9')
                    c -= '0';
                else if (c >= 'a' && c <= 'f')
                    c -= 'a' - 10;
                else if (c >= 'A' && c <= 'F')
                    c -= 'A' - 10;
                else if (c & 0x80)
                {   p--;
                    unsigned u = decodeUTF();
                    p++;
                    if (u == PS || u == LS)
                        loc.linnum++;
                    else
                        error("non-hex character \\u%04x", u);
                }
                else
                    error("non-hex character '%c'", c);
                if (n & 1)
                {   v = (v << 4) | c;
                    stringbuffer.writeByte(v);
                }
                else
                    v = c;
                n++;
                break;
        }
    }
}


#if DMDV2
/**************************************
 * Lex delimited strings:
 *      q"(foo(xxx))"   // "foo(xxx)"
 *      q"[foo(]"       // "foo("
 *      q"/foo]/"       // "foo]"
 *      q"HERE
 *      foo
 *      HERE"           // "foo\n"
 * Input:
 *      p is on the "
 */

TOK Lexer::delimitedStringConstant(Token *t)
{   unsigned c;
    Loc start = loc;
    unsigned delimleft = 0;
    unsigned delimright = 0;
    unsigned nest = 1;
    unsigned nestcount;
    Identifier *hereid = NULL;
    unsigned blankrol = 0;
    unsigned startline = 0;

    p++;
    stringbuffer.reset();
    while (1)
    {
        c = *p++;
        //printf("c = '%c'\n", c);
        switch (c)
        {
            case '\n':
            Lnextline:
                loc.linnum++;
                startline = 1;
                if (blankrol)
                {   blankrol = 0;
                    continue;
                }
                if (hereid)
                {
                    stringbuffer.writeUTF8(c);
                    continue;
                }
                break;

            case '\r':
                if (*p == '\n')
                    continue;   // ignore
                c = '\n';       // treat EndOfLine as \n character
                goto Lnextline;

            case 0:
            case 0x1A:
                goto Lerror;

            default:
                if (c & 0x80)
                {   p--;
                    c = decodeUTF();
                    p++;
                    if (c == PS || c == LS)
                        goto Lnextline;
                }
                break;
        }
        if (delimleft == 0)
        {   delimleft = c;
            nest = 1;
            nestcount = 1;
            if (c == '(')
                delimright = ')';
            else if (c == '{')
                delimright = '}';
            else if (c == '[')
                delimright = ']';
            else if (c == '<')
                delimright = '>';
            else if (isalpha(c) || c == '_' || (c >= 0x80 && isUniAlpha(c)))
            {   // Start of identifier; must be a heredoc
                Token t;
                p--;
                scan(&t);               // read in heredoc identifier
                if (t.value != TOKidentifier)
                {   error("identifier expected for heredoc, not %s", t.toChars());
                    delimright = c;
                }
                else
                {   hereid = t.ident;
                    //printf("hereid = '%s'\n", hereid->toChars());
                    blankrol = 1;
                }
                nest = 0;
            }
            else
            {   delimright = c;
                nest = 0;
#if DMDV2
                if (isspace(c))
                    error("delimiter cannot be whitespace");
#endif
            }
        }
        else
        {
            if (blankrol)
            {   error("heredoc rest of line should be blank");
                blankrol = 0;
                continue;
            }
            if (nest == 1)
            {
                if (c == delimleft)
                    nestcount++;
                else if (c == delimright)
                {   nestcount--;
                    if (nestcount == 0)
                        goto Ldone;
                }
            }
            else if (c == delimright)
                goto Ldone;
            if (startline && isalpha(c)
#if DMDV2
                            && hereid
#endif
                           )
            {   Token t;
                unsigned char *psave = p;
                p--;
                scan(&t);               // read in possible heredoc identifier
                //printf("endid = '%s'\n", t.ident->toChars());
                if (t.value == TOKidentifier && t.ident->equals(hereid))
                {   /* should check that rest of line is blank
                     */
                    goto Ldone;
                }
                p = psave;
            }
            stringbuffer.writeUTF8(c);
            startline = 0;
        }
    }

Ldone:
    if (*p == '"')
        p++;
    else
        error("delimited string must end in %c\"", delimright);
    t->len = stringbuffer.offset;
    stringbuffer.writeByte(0);
    t->ustring = (unsigned char *)mem.malloc(stringbuffer.offset);
    memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
    stringPostfix(t);
    return TOKstring;

Lerror:
    error("unterminated string constant starting at %s", start.toChars());
    t->ustring = (unsigned char *)"";
    t->len = 0;
    t->postfix = 0;
    return TOKstring;
}

/**************************************
 * Lex delimited strings:
 *      q{ foo(xxx) } // " foo(xxx) "
 *      q{foo(}       // "foo("
 *      q{{foo}"}"}   // "{foo}"}""
 * Input:
 *      p is on the q
 */

TOK Lexer::tokenStringConstant(Token *t)
{
    unsigned nest = 1;
    Loc start = loc;
    unsigned char *pstart = ++p;

    while (1)
    {   Token tok;

        scan(&tok);
        switch (tok.value)
        {
            case TOKlcurly:
                nest++;
                continue;

            case TOKrcurly:
                if (--nest == 0)
                    goto Ldone;
                continue;

            case TOKeof:
                goto Lerror;

            default:
                continue;
        }
    }

Ldone:
    t->len = p - 1 - pstart;
    t->ustring = (unsigned char *)mem.malloc(t->len + 1);
    memcpy(t->ustring, pstart, t->len);
    t->ustring[t->len] = 0;
    stringPostfix(t);
    return TOKstring;

Lerror:
    error("unterminated token string constant starting at %s", start.toChars());
    t->ustring = (unsigned char *)"";
    t->len = 0;
    t->postfix = 0;
    return TOKstring;
}

#endif


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
#if !( TEXTUAL_ASSEMBLY_OUT )
            case '\\':
                switch (*p)
                {
                    case 'u':
                    case 'U':
                    case '&':
                        c = escapeSequence();
                        stringbuffer.writeUTF8(c);
                        continue;

                    default:
                        c = escapeSequence();
                        break;
                }
                break;
#endif
            case '\n':
                loc.linnum++;
                break;

            case '\r':
                if (*p == '\n')
                    continue;   // ignore
                c = '\n';       // treat EndOfLine as \n character
                loc.linnum++;
                break;

            case '"':
                t->len = stringbuffer.offset;
                stringbuffer.writeByte(0);
                t->ustring = (unsigned char *)mem.malloc(stringbuffer.offset);
                memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
                stringPostfix(t);
                return TOKstring;

            case 0:
            case 0x1A:
                p--;
                error("unterminated string constant starting at %s", start.toChars());
                t->ustring = (unsigned char *)"";
                t->len = 0;
                t->postfix = 0;
                return TOKstring;

            default:
                if (c & 0x80)
                {
                    p--;
                    c = decodeUTF();
                    if (c == LS || c == PS)
                    {   c = '\n';
                        loc.linnum++;
                    }
                    p++;
                    stringbuffer.writeUTF8(c);
                    continue;
                }
                break;
        }
        stringbuffer.writeByte(c);
    }
}

/**************************************
 */

TOK Lexer::charConstant(Token *t, int wide)
{
    unsigned c;
    TOK tk = TOKcharv;

    //printf("Lexer::charConstant\n");
    p++;
    c = *p++;
    switch (c)
    {
#if ! TEXTUAL_ASSEMBLY_OUT
        case '\\':
            switch (*p)
            {
                case 'u':
                    t->uns64value = escapeSequence();
                    tk = TOKwcharv;
                    break;

                case 'U':
                case '&':
                    t->uns64value = escapeSequence();
                    tk = TOKdcharv;
                    break;

                default:
                    t->uns64value = escapeSequence();
                    break;
            }
            break;
#endif
        case '\n':
        L1:
            loc.linnum++;
        case '\r':
        case 0:
        case 0x1A:
        case '\'':
            error("unterminated character constant");
            return tk;

        default:
            if (c & 0x80)
            {
                p--;
                c = decodeUTF();
                p++;
                if (c == LS || c == PS)
                    goto L1;
                if (c < 0xD800 || (c >= 0xE000 && c < 0xFFFE))
                    tk = TOKwcharv;
                else
                    tk = TOKdcharv;
            }
            t->uns64value = c;
            break;
    }

    if (*p != '\'')
    {   error("unterminated character constant");
        return tk;
    }
    p++;
    return tk;
}

/***************************************
 * Get postfix of string literal.
 */

void Lexer::stringPostfix(Token *t)
{
    switch (*p)
    {
        case 'c':
        case 'w':
        case 'd':
            t->postfix = *p;
            p++;
            break;

        default:
            t->postfix = 0;
            break;
    }
}

/***************************************
 * Read \u or \U unicode sequence
 * Input:
 *      u       'u' or 'U'
 */

#if 0
unsigned Lexer::wchar(unsigned u)
{
    unsigned value;
    unsigned n;
    unsigned char c;
    unsigned nchars;

    nchars = (u == 'U') ? 8 : 4;
    value = 0;
    for (n = 0; 1; n++)
    {
        ++p;
        if (n == nchars)
            break;
        c = *p;
        if (!ishex(c))
        {   error("\\%c sequence must be followed by %d hex characters", u, nchars);
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
#endif

/**************************************
 * Read in a number.
 * If it's an integer, store it in tok.TKutok.Vlong.
 *      integers can be decimal, octal or hex
 *      Handle the suffixes U, UL, LU, L, etc.
 * If it's double, store it in tok.TKutok.Vdouble.
 * Returns:
 *      TKnum
 *      TKdouble,...
 */

TOK Lexer::number(Token *t)
{
    int base = 10;
    stringbuffer.reset();
    unsigned char *start = p;
    unsigned c;

    c = *p;
    if (c == '0')
    {
        stringbuffer.writeByte(c);
        ++p;
        c = *p;
        switch (c)
        {
            case '0': case '1': case '2': case '3':
            case '4': case '5': case '6': case '7':
                stringbuffer.writeByte(c);
                ++p;
                base = 8;
                break;

            case 'x':
            case 'X':
                stringbuffer.writeByte(c);
                ++p;
                base = 16;
                break;

            case 'b':
            case 'B':
                stringbuffer.writeByte(c);
                ++p;
                base = 2;
                break;

            case '.':
                if (p[1] == '.')        // .. is a separate token
                    goto Ldone;
            case 'i':
            case 'f':
            case 'F':
                goto Lreal;

            case '_':
                ++p;
                base = 8;
                break;

            case 'L':
                if (p[1] == 'i')
                    goto Lreal;
                break;

            default:
                break;
        }
    }

    while (1)
    {
        c = *p;
        switch (c)
        {
            case '0': case '1':
                ++p;
                break;

            case '2': case '3':
            case '4': case '5': case '6': case '7':
                if (base == 2)
                    error("binary digit expected");
                ++p;
                break;

            case '8': case '9':
                ++p;
                if (base < 10)
                    error("radix %d digit expected", base);
                break;

            case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
            case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
                ++p;
                if (base != 16)
                {
                    if (c == 'e' || c == 'E' || c == 'f' || c == 'F')
                        goto Lreal;
                    error("radix %d digit expected", base);
                }
                break;

            case 'L':
                if (p[1] == 'i')
                    goto Lreal;
                goto Ldone;

            case '.':
                if (p[1] == '.')
                    goto Ldone;
            case 'p':
            case 'P':
            case 'i':
            Lreal:
                p = start;
                return inreal(t);

            case '_':
                ++p;
                continue;

            default:
                goto Ldone;
        }
        stringbuffer.writeByte(c);
    }

Ldone:
    stringbuffer.writeByte(0);          // terminate string

    TOK result;
    uinteger_t n;                       // unsigned >=64 bit integer type

    if (stringbuffer.offset == 2 && base <= 10)
        n = stringbuffer.data[0] - '0';
    else
    {
        // Convert string to integer
#if __DMC__
        errno = 0;
        n = strtoull((char *)stringbuffer.data,NULL,base);
        if (errno == ERANGE)
            error("integer overflow");
#else
        // Not everybody implements strtoull()
        char *p = (char *)stringbuffer.data;
        int r = 10, d;

        if (*p == '0')
        {
            if (p[1] == 'x' || p[1] == 'X')
                p += 2, r = 16;
            else if (p[1] == 'b' || p[1] == 'B')
                p += 2, r = 2;
            else if (isdigit((unsigned char)p[1]))
                p += 1, r = 8;
        }

        n = 0;
        while (1)
        {
            if (*p >= '0' && *p <= '9')
                d = *p - '0';
            else if (*p >= 'a' && *p <= 'z')
                d = *p - 'a' + 10;
            else if (*p >= 'A' && *p <= 'Z')
                d = *p - 'A' + 10;
            else
                break;
            if (d >= r)
                break;
            uinteger_t n2 = n * r;
            //printf("n2 / r = %llx, n = %llx\n", n2/r, n);
            if (n2 / r != n || n2 + d < n)
            {
                error ("integer overflow");
                break;
            }

            n = n2 + d;
            p++;
        }
#endif
        if (sizeof(n) > 8 &&
            n > 0xFFFFFFFFFFFFFFFFULL)  // if n needs more than 64 bits
            error("integer overflow");
    }

    // Parse trailing 'u', 'U', 'l' or 'L' in any combination

    enum FLAGS
    {
        FLAGS_none     = 0,
        FLAGS_decimal  = 1,             // decimal
        FLAGS_unsigned = 2,             // u or U suffix
        FLAGS_long     = 4,             // L suffix
    };
    enum FLAGS flags = (base == 10) ? FLAGS_decimal : FLAGS_none;

    const unsigned char *psuffix = p;
    while (1)
    {   unsigned char f;

        switch (*p)
        {   case 'U':
            case 'u':
                f = FLAGS_unsigned;
                goto L1;

            case 'l':
                deprecation("'l' suffix is deprecated, use 'L' instead");
            case 'L':
                f = FLAGS_long;
            L1:
                p++;
                if (flags & f)
                    error("unrecognized token");
                flags = (FLAGS) (flags | f);
                continue;
            default:
                break;
        }
        break;
    }

    if ((global.params.enabledV2hints & V2MODEoctal) &&
        base == 8 && n >= 8 &&
        mod && mod->isRoot()
        )
    {
        warning(loc, "octal literals 0%llo%.*s are not in D2, use "
                "std.conv.octal!%llo%.*s instead or hex 0x%llx%.*s [-v2=%s]",
                n, p - psuffix, psuffix,
                n, p - psuffix, psuffix,
                n, p - psuffix, psuffix,
                V2MODE_name(V2MODEoctal));
    }

    switch (flags)
    {
        case 0:
            /* Octal or Hexadecimal constant.
             * First that fits: int, uint, long, ulong
             */
            if (n & 0x8000000000000000LL)
                    result = TOKuns64v;
            else if (n & 0xFFFFFFFF00000000LL)
                    result = TOKint64v;
            else if (n & 0x80000000)
                    result = TOKuns32v;
            else
                    result = TOKint32v;
            break;

        case FLAGS_decimal:
            /* First that fits: int, long, long long
             */
            if (n & 0x8000000000000000LL)
            {       error("signed integer overflow");
                    result = TOKuns64v;
            }
            else if (n & 0xFFFFFFFF80000000LL)
                    result = TOKint64v;
            else
                    result = TOKint32v;
            break;

        case FLAGS_unsigned:
        case FLAGS_decimal | FLAGS_unsigned:
            /* First that fits: uint, ulong
             */
            if (n & 0xFFFFFFFF00000000LL)
                    result = TOKuns64v;
            else
                    result = TOKuns32v;
            break;

        case FLAGS_decimal | FLAGS_long:
            if (n & 0x8000000000000000LL)
            {       error("signed integer overflow");
                    result = TOKuns64v;
            }
            else
                    result = TOKint64v;
            break;

        case FLAGS_long:
            if (n & 0x8000000000000000LL)
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
 *      Exponent overflow not detected.
 *      Too much requested precision is not detected.
 */

TOK Lexer::inreal(Token *t)
#ifdef __DMC__
__in
{
    assert(*p == '.' || isdigit(*p));
}
__out (result)
{
    switch (result)
    {
        case TOKfloat32v:
        case TOKfloat64v:
        case TOKfloat80v:
        case TOKimaginary32v:
        case TOKimaginary64v:
        case TOKimaginary80v:
            break;

        default:
            assert(0);
    }
}
__body
#endif /* __DMC__ */
{
    //printf("Lexer::inreal()\n");

    stringbuffer.reset();
    unsigned char *pstart = p;
    char hex = 0;
    unsigned c = *p++;

    // Leading '0x'
    if (c == '0')
    {
        c = *p++;
        if (c == 'x' || c == 'X')
        {
            hex = true;
            c = *p++;
        }
    }

    // Digits to left of '.'
    while (1)
    {
        if (c == '.')
        {
            c = *p++;
            break;
        }
        if (isdigit(c) || (hex && isxdigit(c)) || c == '_')
        {
            c = *p++;
            continue;
        }
        break;
    }

    // Digits to right of '.'
    while (1)
    {
        if (isdigit(c) || (hex && isxdigit(c)) || c == '_')
        {
            c = *p++;
            continue;
        }
        break;
    }

    if (c == 'e' || c == 'E' || (hex && (c == 'p' || c == 'P')))
    {
        c = *p++;
        if (c == '-' || c == '+')
        {
            c = *p++;
        }
        bool anyexp;
        while (1)
        {
            if (isdigit(c) || (hex && isxdigit(c)))
            {
                anyexp = true;
                c = *p++;
                continue;
            }
            if (c == '_')
            {
                c = *p++;
                continue;
            }
            if (!anyexp)
                error("missing exponent");
            break;
        }
    }
    else if (hex)
        error("exponent required for hex float");
    --p;
    while (pstart < p)
    {
        if (*pstart != '_')
            stringbuffer.writeByte(*pstart);
        ++pstart;
    }

    stringbuffer.writeByte(0);

    TOK result;

#if _WIN32 && __DMC__
    const char *save = __locale_decpoint;
    __locale_decpoint = ".";
#endif
#ifdef IN_GCC
    t->float80value = real_t::parse((char *)stringbuffer.data, real_t::LongDouble);
#else
    t->float80value = strtold((char *)stringbuffer.data, NULL);
#endif
    errno = 0;
    switch (*p)
    {
        case 'F':
        case 'f':
#ifdef IN_GCC
            real_t::parse((char *)stringbuffer.data, real_t::Float);
#else
            {   // Only interested in errno return
                double d = strtof((char *)stringbuffer.data, NULL);
                // Assign to f to keep gcc warnings at bay
            }
#endif
            result = TOKfloat32v;
            p++;
            break;

        default:
#ifdef IN_GCC
            real_t::parse((char *)stringbuffer.data, real_t::Double);
#else
            /* Should do our own strtod(), since dmc and linux gcc
             * accept 2.22507e-308, while apple gcc will only take
             * 2.22508e-308. Not sure who is right.
             */
            {   // Only interested in errno return
                double d = strtod((char *)stringbuffer.data, NULL);
                // Assign to d to keep gcc warnings at bay
            }
#endif
            result = TOKfloat64v;
            break;

        case 'l':
            deprecation("'l' suffix is deprecated, use 'L' instead");
        case 'L':
            result = TOKfloat80v;
            p++;
            break;
    }
    if (*p == 'i' || *p == 'I')
    {
        if (*p == 'I')
            deprecation("'I' suffix is deprecated, use 'i' instead");
        p++;
        switch (result)
        {
            case TOKfloat32v:
                result = TOKimaginary32v;
                break;
            case TOKfloat64v:
                result = TOKimaginary64v;
                break;
            case TOKfloat80v:
                result = TOKimaginary80v;
                break;
        }
    }
#if _WIN32 && __DMC__
    __locale_decpoint = save;
#endif
    if (errno == ERANGE)
        error("number is not representable");
    return result;
}

/*********************************************
 * Do pragma.
 * Currently, the only pragma supported is:
 *      #line linnum [filespec]
 */

void Lexer::pragma()
{
    Token tok;
    int linnum;
    char *filespec = NULL;
    Loc loc = this->loc;

    scan(&tok);
    if (tok.value != TOKidentifier || tok.ident != Id::line)
        goto Lerr;

    scan(&tok);
    if (tok.value == TOKint32v || tok.value == TOKint64v)
    {   linnum = (int)(tok.uns64value - 1);
        if (linnum != tok.uns64value - 1)
            error("line number out of range");
    }
    else if (tok.value == TOKline)
    {
        linnum = this->loc.linnum;
    }
    else
        goto Lerr;

    while (1)
    {
        switch (*p)
        {
            case 0:
            case 0x1A:
            case '\n':
            Lnewline:
                this->loc.linnum = linnum;
                if (filespec)
                    this->loc.filename = filespec;
                return;

            case '\r':
                p++;
                if (*p != '\n')
                {   p--;
                    goto Lnewline;
                }
                continue;

            case ' ':
            case '\t':
            case '\v':
            case '\f':
                p++;
                continue;                       // skip white space

            case '_':
                if (mod && memcmp(p, "__FILE__", 8) == 0)
                {
                    p += 8;
                    filespec = mem.strdup(loc.filename ? loc.filename : mod->ident->toChars());
                    continue;
                }
                goto Lerr;

            case '"':
                if (filespec)
                    goto Lerr;
                stringbuffer.reset();
                p++;
                while (1)
                {   unsigned c;

                    c = *p;
                    switch (c)
                    {
                        case '\n':
                        case '\r':
                        case 0:
                        case 0x1A:
                            goto Lerr;

                        case '"':
                            stringbuffer.writeByte(0);
                            filespec = mem.strdup((char *)stringbuffer.data);
                            p++;
                            break;

                        default:
                            if (c & 0x80)
                            {   unsigned u = decodeUTF();
                                if (u == PS || u == LS)
                                    goto Lerr;
                            }
                            stringbuffer.writeByte(c);
                            p++;
                            continue;
                    }
                    break;
                }
                continue;

            default:
                if (*p & 0x80)
                {   unsigned u = decodeUTF();
                    if (u == PS || u == LS)
                        goto Lnewline;
                }
                goto Lerr;
        }
    }

Lerr:
    error(loc, "#line integer [\"filespec\"]\\n expected");
}


/********************************************
 * Decode UTF character.
 * Issue error messages for invalid sequences.
 * Return decoded character, advance p to last character in UTF sequence.
 */

unsigned Lexer::decodeUTF()
{
    dchar_t u;
    unsigned char c;
    unsigned char *s = p;
    size_t len;
    size_t idx;
    const char *msg;

    c = *s;
    assert(c & 0x80);

    // Check length of remaining string up to 6 UTF-8 characters
    for (len = 1; len < 6 && s[len]; len++)
        ;

    idx = 0;
    msg = utf_decodeChar(s, len, &idx, &u);
    p += idx - 1;
    if (msg)
    {
        error("%s", msg);
    }
    return u;
}


/***************************************************
 * Parse doc comment embedded between t->ptr and p.
 * Remove trailing blanks and tabs from lines.
 * Replace all newlines with \n.
 * Remove leading comment character from each line.
 * Decide if it's a lineComment or a blockComment.
 * Append to previous one for this token.
 */

void Lexer::getDocComment(Token *t, unsigned lineComment)
{
    /* ct tells us which kind of comment it is: '/', '*', or '+'
     */
    unsigned char ct = t->ptr[2];

    /* Start of comment text skips over / * *, / + +, or / / /
     */
    unsigned char *q = t->ptr + 3;      // start of comment text

    unsigned char *qend = p;
    if (ct == '*' || ct == '+')
        qend -= 2;

    /* Scan over initial row of ****'s or ++++'s or ////'s
     */
    for (; q < qend; q++)
    {
        if (*q != ct)
            break;
    }

    /* Remove trailing row of ****'s or ++++'s
     */
    if (ct != '/')
    {
        for (; q < qend; qend--)
        {
            if (qend[-1] != ct)
                break;
        }
    }

    /* Comment is now [q .. qend].
     * Canonicalize it into buf[].
     */
    OutBuffer buf;
    int linestart = 0;

    for (; q < qend; q++)
    {
        unsigned char c = *q;

        switch (c)
        {
            case '*':
            case '+':
                if (linestart && c == ct)
                {   linestart = 0;
                    /* Trim preceding whitespace up to preceding \n
                     */
                    while (buf.offset && (buf.data[buf.offset - 1] == ' ' || buf.data[buf.offset - 1] == '\t'))
                        buf.offset--;
                    continue;
                }
                break;

            case ' ':
            case '\t':
                break;

            case '\r':
                if (q[1] == '\n')
                    continue;           // skip the \r
                goto Lnewline;

            default:
                if (c == 226)
                {
                    // If LS or PS
                    if (q[1] == 128 &&
                        (q[2] == 168 || q[2] == 169))
                    {
                        q += 2;
                        goto Lnewline;
                    }
                }
                linestart = 0;
                break;

            Lnewline:
                c = '\n';               // replace all newlines with \n
            case '\n':
                linestart = 1;

                /* Trim trailing whitespace
                 */
                while (buf.offset && (buf.data[buf.offset - 1] == ' ' || buf.data[buf.offset - 1] == '\t'))
                    buf.offset--;

                break;
        }
        buf.writeByte(c);
    }

    // Always end with a newline
    if (!buf.offset || buf.data[buf.offset - 1] != '\n')
        buf.writeByte('\n');

    buf.writeByte(0);

    // It's a line comment if the start of the doc comment comes
    // after other non-whitespace on the same line.
    unsigned char** dc = (lineComment && anyToken)
                         ? &t->lineComment
                         : &t->blockComment;

    // Combine with previous doc comment, if any
    if (*dc)
        *dc = combineComments(*dc, (unsigned char *)buf.data);
    else
        *dc = (unsigned char *)buf.extractData();
}

/********************************************
 * Combine two document comments into one,
 * separated by a newline.
 */

unsigned char *Lexer::combineComments(unsigned char *c1, unsigned char *c2)
{
    //printf("Lexer::combineComments('%s', '%s')\n", c1, c2);

    unsigned char *c = c2;

    if (c1)
    {   c = c1;
        if (c2)
        {   size_t len1 = strlen((char *)c1);
            size_t len2 = strlen((char *)c2);

            c = (unsigned char *)mem.malloc(len1 + 1 + len2 + 1);
            memcpy(c, c1, len1);
            if (len1 && c1[len1 - 1] != '\n')
            {   c[len1] = '\n';
                len1++;
            }
            memcpy(c + len1, c2, len2);
            c[len1 + len2] = 0;
        }
    }
    return c;
}

/*******************************************
 * Search actual location of current token
 * even when infinite look-ahead was done.
 */
Loc Lexer::tokenLoc()
{
    Loc result = this->loc;
    Token* last = &token;
    while (last->next)
        last = last->next;

    unsigned char* start = token.ptr;
    unsigned char* stop = last->ptr;

    for (unsigned char* p = start; p < stop; ++p)
    {
        switch (*p)
        {
            case '\n':
                result.linnum--;
                break;
            case '\r':
                if (p[1] != '\n')
                    result.linnum--;
                break;
            default:
                break;
        }
    }
    return result;
}

/********************************************
 * Create an identifier in the string table.
 */

Identifier *Lexer::idPool(const char *s)
{
    size_t len = strlen(s);
    StringValue *sv = stringtable.update(s, len);
    Identifier *id = (Identifier *) sv->ptrvalue;
    if (!id)
    {
        id = new Identifier(sv->toDchars(), TOKidentifier);
        sv->ptrvalue = id;
    }
    return id;
}

/*********************************************
 * Create a unique identifier using the prefix s.
 */

Identifier *Lexer::uniqueId(const char *s, int num)
{   char buffer[32];
    size_t slen = strlen(s);

    assert(slen + sizeof(num) * 3 + 1 <= sizeof(buffer));
    sprintf(buffer, "%s%d", s, num);
    return idPool(buffer);
}

Identifier *Lexer::uniqueId(const char *s)
{
    static int num;
    return uniqueId(s, ++num);
}

/****************************************
 */

struct Keyword
{   const char *name;
    enum TOK value;
};

static Keyword keywords[] =
{
//    { "",             TOK     },

    {   "this",         TOKthis         },
    {   "super",        TOKsuper        },
    {   "assert",       TOKassert       },
    {   "null",         TOKnull         },
    {   "true",         TOKtrue         },
    {   "false",        TOKfalse        },
    {   "cast",         TOKcast         },
    {   "new",          TOKnew          },
    {   "delete",       TOKdelete       },
    {   "throw",        TOKthrow        },
    {   "module",       TOKmodule       },
    {   "pragma",       TOKpragma       },
    {   "typeof",       TOKtypeof       },
    {   "typeid",       TOKtypeid       },

    {   "template",     TOKtemplate     },

    {   "void",         TOKvoid         },
    {   "byte",         TOKint8         },
    {   "ubyte",        TOKuns8         },
    {   "short",        TOKint16        },
    {   "ushort",       TOKuns16        },
    {   "int",          TOKint32        },
    {   "uint",         TOKuns32        },
    {   "long",         TOKint64        },
    {   "ulong",        TOKuns64        },
    {   "cent",         TOKcent,        },
    {   "ucent",        TOKucent,       },
    {   "float",        TOKfloat32      },
    {   "double",       TOKfloat64      },
    {   "real",         TOKfloat80      },

    {   "bool",         TOKbool         },
    {   "char",         TOKchar         },
    {   "wchar",        TOKwchar        },
    {   "dchar",        TOKdchar        },

    {   "ifloat",       TOKimaginary32  },
    {   "idouble",      TOKimaginary64  },
    {   "ireal",        TOKimaginary80  },

    {   "cfloat",       TOKcomplex32    },
    {   "cdouble",      TOKcomplex64    },
    {   "creal",        TOKcomplex80    },

    {   "delegate",     TOKdelegate     },
    {   "function",     TOKfunction     },

    {   "is",           TOKis           },
    {   "if",           TOKif           },
    {   "else",         TOKelse         },
    {   "while",        TOKwhile        },
    {   "for",          TOKfor          },
    {   "do",           TOKdo           },
    {   "switch",       TOKswitch       },
    {   "case",         TOKcase         },
    {   "default",      TOKdefault      },
    {   "break",        TOKbreak        },
    {   "continue",     TOKcontinue     },
    {   "synchronized", TOKsynchronized },
    {   "return",       TOKreturn       },
    {   "goto",         TOKgoto         },
    {   "try",          TOKtry          },
    {   "catch",        TOKcatch        },
    {   "finally",      TOKfinally      },
    {   "with",         TOKwith         },
    {   "asm",          TOKasm          },
    {   "foreach",      TOKforeach      },
    {   "foreach_reverse",      TOKforeach_reverse      },
    {   "scope",        TOKscope        },

    {   "struct",       TOKstruct       },
    {   "class",        TOKclass        },
    {   "interface",    TOKinterface    },
    {   "union",        TOKunion        },
    {   "enum",         TOKenum         },
    {   "import",       TOKimport       },
    {   "mixin",        TOKmixin        },
    {   "static",       TOKstatic       },
    {   "final",        TOKfinal        },
    {   "const",        TOKconst        },
    {   "typedef",      TOKtypedef      },
    {   "alias",        TOKalias        },
    {   "override",     TOKoverride     },
    {   "abstract",     TOKabstract     },
    {   "volatile",     TOKvolatile     },
    {   "debug",        TOKdebug        },
    {   "deprecated",   TOKdeprecated   },
    {   "in",           TOKin           },
    {   "out",          TOKout          },
    {   "inout",        TOKinout        },
    {   "lazy",         TOKlazy         },
    {   "auto",         TOKauto         },

    {   "align",        TOKalign        },
    {   "extern",       TOKextern       },
    {   "private",      TOKprivate      },
    {   "package",      TOKpackage      },
    {   "protected",    TOKprotected    },
    {   "public",       TOKpublic       },
    {   "export",       TOKexport       },

    {   "body",         TOKbody         },
    {   "invariant",    TOKinvariant    },
    {   "unittest",     TOKunittest     },
    {   "version",      TOKversion      },

    // Added after 1.0
    {   "__argTypes",   TOKargTypes     },
    {   "__FILE__",     TOKfile         },
    {   "__LINE__",     TOKline         },
    {   "ref",          TOKref          },
    {   "macro",        TOKmacro        },

    {   "pure",         TOKD2kwd        },
    {   "nothrow",      TOKD2kwd        },
    {   "__parameters", TOKD2kwd        },
    {   "__gshared",    TOKD2kwd        },
    {   "__traits",     TOKD2kwd        },
    {   "__vector",     TOKD2kwd        },
    {   "__overloadset", TOKD2kwd       },
    {   "__MODULE__",   TOKD2kwd        },
    {   "__FUNCTION__", TOKD2kwd        },
    {   "__PRETTY_FUNCTION__", TOKD2kwd },
    {   "shared",       TOKD2kwd        },
    {   "immutable",    TOKD2kwd        },
};

int Token::isKeyword()
{
    for (unsigned u = 0; u < sizeof(keywords) / sizeof(keywords[0]); u++)
    {
        if (keywords[u].value == value)
            return 1;
    }
    return 0;
}

void Lexer::initKeywords()
{
    unsigned nkeywords = sizeof(keywords) / sizeof(keywords[0]);

    stringtable._init(6151);

    if (global.params.Dversion == 1)
        nkeywords -= 2;

    cmtable_init();

    for (unsigned u = 0; u < nkeywords; u++)
    {
        //printf("keyword[%d] = '%s'\n",u, keywords[u].name);
        const char *s = keywords[u].name;
        enum TOK v = keywords[u].value;
        StringValue *sv = stringtable.insert(s, strlen(s));
        sv->ptrvalue = (void *) new Identifier(sv->toDchars(),v);

        //printf("tochars[%d] = '%s'\n",v, s);
        Token::tochars[v] = s;
    }

    Token::tochars[TOKeof]              = "EOF";
    Token::tochars[TOKlcurly]           = "{";
    Token::tochars[TOKrcurly]           = "}";
    Token::tochars[TOKlparen]           = "(";
    Token::tochars[TOKrparen]           = ")";
    Token::tochars[TOKlbracket]         = "[";
    Token::tochars[TOKrbracket]         = "]";
    Token::tochars[TOKsemicolon]        = ";";
    Token::tochars[TOKcolon]            = ":";
    Token::tochars[TOKcomma]            = ",";
    Token::tochars[TOKdot]              = ".";
    Token::tochars[TOKxor]              = "^";
    Token::tochars[TOKxorass]           = "^=";
    Token::tochars[TOKassign]           = "=";
    Token::tochars[TOKconstruct]        = "=";
#if DMDV2
    Token::tochars[TOKblit]             = "=";
#endif
    Token::tochars[TOKlt]               = "<";
    Token::tochars[TOKgt]               = ">";
    Token::tochars[TOKle]               = "<=";
    Token::tochars[TOKge]               = ">=";
    Token::tochars[TOKequal]            = "==";
    Token::tochars[TOKnotequal]         = "!=";
    Token::tochars[TOKnotidentity]      = "!is";
    Token::tochars[TOKtobool]           = "!!";

    Token::tochars[TOKunord]            = "!<>=";
    Token::tochars[TOKue]               = "!<>";
    Token::tochars[TOKlg]               = "<>";
    Token::tochars[TOKleg]              = "<>=";
    Token::tochars[TOKule]              = "!>";
    Token::tochars[TOKul]               = "!>=";
    Token::tochars[TOKuge]              = "!<";
    Token::tochars[TOKug]               = "!<=";

    Token::tochars[TOKnot]              = "!";
    Token::tochars[TOKtobool]           = "!!";
    Token::tochars[TOKshl]              = "<<";
    Token::tochars[TOKshr]              = ">>";
    Token::tochars[TOKushr]             = ">>>";
    Token::tochars[TOKadd]              = "+";
    Token::tochars[TOKmin]              = "-";
    Token::tochars[TOKmul]              = "*";
    Token::tochars[TOKdiv]              = "/";
    Token::tochars[TOKmod]              = "%";
    Token::tochars[TOKslice]            = "..";
    Token::tochars[TOKdotdotdot]        = "...";
    Token::tochars[TOKand]              = "&";
    Token::tochars[TOKandand]           = "&&";
    Token::tochars[TOKor]               = "|";
    Token::tochars[TOKoror]             = "||";
    Token::tochars[TOKarray]            = "[]";
    Token::tochars[TOKindex]            = "[i]";
    Token::tochars[TOKaddress]          = "&";
    Token::tochars[TOKstar]             = "*";
    Token::tochars[TOKtilde]            = "~";
    Token::tochars[TOKdollar]           = "$";
    Token::tochars[TOKcast]             = "cast";
    Token::tochars[TOKplusplus]         = "++";
    Token::tochars[TOKminusminus]       = "--";
    Token::tochars[TOKpreplusplus]      = "++";
    Token::tochars[TOKpreminusminus]    = "--";
    Token::tochars[TOKtype]             = "type";
    Token::tochars[TOKquestion]         = "?";
    Token::tochars[TOKneg]              = "-";
    Token::tochars[TOKuadd]             = "+";
    Token::tochars[TOKvar]              = "var";
    Token::tochars[TOKaddass]           = "+=";
    Token::tochars[TOKminass]           = "-=";
    Token::tochars[TOKmulass]           = "*=";
    Token::tochars[TOKdivass]           = "/=";
    Token::tochars[TOKmodass]           = "%=";
    Token::tochars[TOKshlass]           = "<<=";
    Token::tochars[TOKshrass]           = ">>=";
    Token::tochars[TOKushrass]          = ">>>=";
    Token::tochars[TOKandass]           = "&=";
    Token::tochars[TOKorass]            = "|=";
    Token::tochars[TOKcatass]           = "~=";
    Token::tochars[TOKcat]              = "~";
    Token::tochars[TOKcall]             = "call";
    Token::tochars[TOKidentity]         = "is";
    Token::tochars[TOKnotidentity]      = "!is";

    Token::tochars[TOKorass]            = "|=";
    Token::tochars[TOKidentifier]       = "identifier";
#if DMDV2
    Token::tochars[TOKat]               = "@";
    Token::tochars[TOKpow]              = "^^";
    Token::tochars[TOKpowass]           = "^^=";
    Token::tochars[TOKgoesto]           = "=>";
    Token::tochars[TOKpound]            = "#";
#endif

     // For debugging
    Token::tochars[TOKerror]            = "error";
    Token::tochars[TOKdotexp]           = "dotexp";
    Token::tochars[TOKdotti]            = "dotti";
    Token::tochars[TOKdotvar]           = "dotvar";
    Token::tochars[TOKdottype]          = "dottype";
    Token::tochars[TOKsymoff]           = "symoff";
    Token::tochars[TOKarraylength]      = "arraylength";
    Token::tochars[TOKarrayliteral]     = "arrayliteral";
    Token::tochars[TOKassocarrayliteral] = "assocarrayliteral";
    Token::tochars[TOKstructliteral]    = "structliteral";
    Token::tochars[TOKstring]           = "string";
    Token::tochars[TOKdsymbol]          = "symbol";
    Token::tochars[TOKtuple]            = "tuple";
    Token::tochars[TOKdeclaration]      = "declaration";
    Token::tochars[TOKdottd]            = "dottd";
    Token::tochars[TOKon_scope_exit]    = "scope(exit)";
    Token::tochars[TOKon_scope_success] = "scope(success)";
    Token::tochars[TOKon_scope_failure] = "scope(failure)";

#if UNITTEST
    unittest_lexer();
#endif
}

#if UNITTEST

void unittest_lexer()
{
    //printf("unittest_lexer()\n");

    /* Not much here, just trying things out.
     */
    const unsigned char text[] = "int";
    Lexer lex1(NULL, (unsigned char *)text, 0, sizeof(text), 0, 0);
    TOK tok;
    tok = lex1.nextToken();
    //printf("tok == %s, %d, %d\n", Token::toChars(tok), tok, TOKint32);
    assert(tok == TOKint32);
    tok = lex1.nextToken();
    assert(tok == TOKeof);
    tok = lex1.nextToken();
    assert(tok == TOKeof);
}

#endif

