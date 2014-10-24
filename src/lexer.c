
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/lexer.c
 */

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

extern int HtmlNamedEntity(const utf8_t *p, size_t length);

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

inline bool isoctal (utf8_t c) { return (cmtable[c] & CMoctal) != 0; }
inline bool ishex   (utf8_t c) { return (cmtable[c] & CMhex) != 0; }
inline bool isidchar(utf8_t c) { return (cmtable[c] & CMidchar) != 0; }

static void cmtable_init()
{
    for (unsigned c = 0; c < 256; c++)
    {
        if ('0' <= c && c <= '7')
            cmtable[c] |= CMoctal;
        if (isxdigit(c))
            cmtable[c] |= CMhex;
        if (isalnum(c) || c == '_')
            cmtable[c] |= CMidchar;
    }
}


/************************* Token **********************************************/

const char *Token::tochars[TOKMAX];

Token *Token::alloc()
{
    if (Lexer::freelist)
    {
        Token *t = Lexer::freelist;
        Lexer::freelist = t->next;
        t->next = NULL;
        return t;
    }

    return new Token();
}

#ifdef DEBUG
void Token::print()
{
    fprintf(stderr, "%s\n", toChars());
}
#endif

const char *Token::toChars()
{   const char *p;
    static char buffer[3 + 3 * sizeof(float80value) + 1];

    p = &buffer[0];
    switch (value)
    {
        case TOKint32v:
            sprintf(&buffer[0],"%d",int32value);
            break;

        case TOKuns32v:
        case TOKcharv:
        case TOKwcharv:
        case TOKdcharv:
            sprintf(&buffer[0],"%uU",uns32value);
            break;

        case TOKint64v:
            sprintf(&buffer[0],"%lldL",(longlong)int64value);
            break;

        case TOKuns64v:
            sprintf(&buffer[0],"%lluUL",(ulonglong)uns64value);
            break;

        case TOKfloat32v:
            ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "f");
            break;

        case TOKfloat64v:
            ld_sprint(&buffer[0], 'g', float80value);
            break;

        case TOKfloat80v:
            ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "L");
            break;

        case TOKimaginary32v:
            ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "fi");
            break;

        case TOKimaginary64v:
            ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "i");
            break;

        case TOKimaginary80v:
            ld_sprint(&buffer[0], 'g', float80value);
            strcat(&buffer[0], "Li");
            break;

        case TOKstring:
        {   OutBuffer buf;

            buf.writeByte('"');
            for (size_t i = 0; i < len; )
            {   unsigned c;

                utf_decodeChar((utf8_t *)ustring, len, &i, &c);
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
                buf.writeByte(postfix);
            p = buf.extractString();
        }
            break;

        case TOKxstring:
        {
            OutBuffer buf;
            buf.writeByte('x');
            buf.writeByte('"');
            for (size_t i = 0; i < len; i++)
            {
                if (i)
                    buf.writeByte(' ');
                buf.printf("%02x", ustring[i]);
            }
            buf.writeByte('"');
            if (postfix)
                buf.writeByte(postfix);
            buf.writeByte(0);
            p = (char *)buf.extractData();
            break;
        }

        case TOKidentifier:
        case TOKenum:
        case TOKstruct:
        case TOKimport:
        case TOKwchar: case TOKdchar:
        case TOKbool: case TOKchar:
        case TOKint8: case TOKuns8:
        case TOKint16: case TOKuns16:
        case TOKint32: case TOKuns32:
        case TOKint64: case TOKuns64:
        case TOKint128: case TOKuns128:
        case TOKfloat32: case TOKfloat64: case TOKfloat80:
        case TOKimaginary32: case TOKimaginary64: case TOKimaginary80:
        case TOKcomplex32: case TOKcomplex64: case TOKcomplex80:
        case TOKvoid:
            p = ident->toChars();
            break;

        default:
            p = toChars(value);
            break;
    }
    return p;
}

const char *Token::toChars(TOK value)
{   const char *p;
    static char buffer[3 + 3 * sizeof(value) + 1];

    p = tochars[value];
    if (!p)
    {   sprintf(&buffer[0],"TOK%d",value);
        p = &buffer[0];
    }
    return p;
}

/*************************** Lexer ********************************************/

Token *Lexer::freelist = NULL;
StringTable Lexer::stringtable;
OutBuffer Lexer::stringbuffer;

Lexer::Lexer(Module *mod,
        const utf8_t *base, size_t begoffset, size_t endoffset,
        int doDocComment, int commentToken)
{
    scanloc = Loc(mod, 1, 1);
    //printf("Lexer::Lexer(%p,%d)\n",base,length);
    //printf("lexer.mod = %p, %p\n", mod, this->loc.mod);
    memset(&token,0,sizeof(token));
    this->base = base;
    this->end  = base + endoffset;
    p = base + begoffset;
    line = p;
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
        {   utf8_t c = *p;
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
        endOfLine();
    }
}


void Lexer::endOfLine()
{
    scanloc.linnum++;
    line = p;
}

Loc Lexer::loc()
{
    scanloc.charnum = (unsigned)(1 + p-line);
    return scanloc;
}

void Lexer::error(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::verror(token.loc, format, ap);
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
    ::vdeprecation(token.loc, format, ap);
    va_end(ap);
}

TOK Lexer::nextToken()
{
    if (token.next)
    {
        Token *t = token.next;
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
{
    Token *t;
    if (ct->next)
        t = ct->next;
    else
    {
        t = Token::alloc();
        scan(t);
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

int Lexer::isValidIdentifier(const char *p)
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

        const char *q = utf_decodeChar((utf8_t *)p, len, &idx, &dc);
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
    unsigned lastLine = scanloc.linnum;
    Loc startLoc;

    t->blockComment = NULL;
    t->lineComment = NULL;
    while (1)
    {
        t->ptr = p;
        //printf("p = %p, *p = '%c'\n",p,*p);
        t->loc = loc();
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
                    endOfLine();
                continue;                       // skip white space

            case '\n':
                p++;
                endOfLine();
                continue;                       // skip white space

            case '0':   case '1':   case '2':   case '3':   case '4':
            case '5':   case '6':   case '7':   case '8':   case '9':
                t->value = number(t);
                return;

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

            case '"':
                t->value = escapeStringConstant(t,0);
                return;

            case 'a':   case 'b':   case 'c':   case 'd':   case 'e':
            case 'f':   case 'g':   case 'h':   case 'i':   case 'j':
            case 'k':   case 'l':   case 'm':   case 'n':   case 'o':
            case 'p':   /*case 'q': case 'r':*/ case 's':   case 't':
            case 'u':   case 'v':   case 'w': /*case 'x':*/ case 'y':
            case 'z':
            case 'A':   case 'B':   case 'C':   case 'D':   case 'E':
            case 'F':   case 'G':   case 'H':   case 'I':   case 'J':
            case 'K':   case 'L':   case 'M':   case 'N':   case 'O':
            case 'P':   case 'Q':   case 'R':   case 'S':   case 'T':
            case 'U':   case 'V':   case 'W':   case 'X':   case 'Y':
            case 'Z':
            case '_':
            case_ident:
            {   utf8_t c;

                while (1)
                {
                    c = *++p;
                    if (isidchar(c))
                        continue;
                    else if (c & 0x80)
                    {   const utf8_t *s = p;
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
                    sv->ptrvalue = (char *)id;
                }
                t->ident = id;
                t->value = (TOK) id->value;
                anyToken = 1;
                if (*t->ptr == '_')     // if special identifier token
                {
                    static bool initdone = false;
                    static char date[11+1];
                    static char time[8+1];
                    static char timestamp[24+1];

                    if (!initdone)       // lazy evaluation
                    {
                        initdone = true;
                        time_t ct;
                        ::time(&ct);
                        char *p = ctime(&ct);
                        assert(p);
                        sprintf(&date[0], "%.6s %.4s", p + 4, p + 20);
                        sprintf(&time[0], "%.8s", p + 11);
                        sprintf(&timestamp[0], "%.24s", p);
                    }

                    if (id == Id::DATE)
                    {
                        t->ustring = (utf8_t *)date;
                        goto Lstr;
                    }
                    else if (id == Id::TIME)
                    {
                        t->ustring = (utf8_t *)time;
                        goto Lstr;
                    }
                    else if (id == Id::VENDOR)
                    {
                        t->ustring = (utf8_t *)global.compiler.vendor;
                        goto Lstr;
                    }
                    else if (id == Id::TIMESTAMP)
                    {
                        t->ustring = (utf8_t *)timestamp;
                     Lstr:
                        t->value = TOKstring;
                        t->postfix = 0;
                        t->len = (unsigned)strlen((char *)t->ustring);
                    }
                    else if (id == Id::VERSIONX)
                    {   unsigned major = 0;
                        unsigned minor = 0;
                        bool point = false;

                        for (const char *p = global.version + 1; 1; p++)
                        {
                            c = *p;
                            if (isdigit((utf8_t)c))
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
                    else if (id == Id::EOFX)
                    {
                        t->value = TOKeof;
                        // Advance scanner to end of file
                        while (!(*p == 0 || *p == 0x1A))
                            p++;
                    }
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
                        startLoc = loc();
                        while (1)
                        {
                            while (1)
                            {   utf8_t c = *p;
                                switch (c)
                                {
                                    case '/':
                                        break;

                                    case '\n':
                                        endOfLine();
                                        p++;
                                        continue;

                                    case '\r':
                                        p++;
                                        if (*p != '\n')
                                            endOfLine();
                                        continue;

                                    case 0:
                                    case 0x1A:
                                        error("unterminated /* */ comment");
                                        p = end;
                                        t->loc = loc();
                                        t->value = TOKeof;
                                        return;

                                    default:
                                        if (c & 0x80)
                                        {   unsigned u = decodeUTF();
                                            if (u == PS || u == LS)
                                                endOfLine();
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
                            t->loc = startLoc;
                            t->value = TOKcomment;
                            return;
                        }
                        else if (doDocComment && t->ptr[2] == '*' && p - 4 != t->ptr)
                        {   // if /** but not /**/
                            getDocComment(t, lastLine == startLoc.linnum);
                        }
                        continue;

                    case '/':           // do // style comments
                        startLoc = loc();
                        while (1)
                        {   utf8_t c = *++p;
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
                                        t->loc = startLoc;
                                        t->value = TOKcomment;
                                        return;
                                    }
                                    if (doDocComment && t->ptr[2] == '/')
                                        getDocComment(t, lastLine == startLoc.linnum);
                                    p = end;
                                    t->loc = loc();
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
                            endOfLine();
                            t->loc = startLoc;
                            t->value = TOKcomment;
                            return;
                        }
                        if (doDocComment && t->ptr[2] == '/')
                            getDocComment(t, lastLine == startLoc.linnum);

                        p++;
                        endOfLine();
                        continue;

                    case '+':
                    {   int nest;

                        startLoc = loc();
                        p++;
                        nest = 1;
                        while (1)
                        {   utf8_t c = *p;
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
                                        endOfLine();
                                    continue;

                                case '\n':
                                    endOfLine();
                                    p++;
                                    continue;

                                case 0:
                                case 0x1A:
                                    error("unterminated /+ +/ comment");
                                    p = end;
                                    t->loc = loc();
                                    t->value = TOKeof;
                                    return;

                                default:
                                    if (c & 0x80)
                                    {   unsigned u = decodeUTF();
                                        if (u == PS || u == LS)
                                            endOfLine();
                                    }
                                    p++;
                                    continue;
                            }
                            break;
                        }
                        if (commentToken)
                        {
                            t->loc = startLoc;
                            t->value = TOKcomment;
                            return;
                        }
                        if (doDocComment && t->ptr[2] == '+' && p - 4 != t->ptr)
                        {   // if /++ but not /++/
                            getDocComment(t, lastLine == startLoc.linnum);
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
                    t->value = TOKequal;            // ==
                }
                else if (*p == '>')
                {   p++;
                    t->value = TOKgoesto;               // =>
                }
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

            case '(': p++; t->value = TOKlparen; return;
            case ')': p++; t->value = TOKrparen; return;
            case '[': p++; t->value = TOKlbracket; return;
            case ']': p++; t->value = TOKrbracket; return;
            case '{': p++; t->value = TOKlcurly; return;
            case '}': p++; t->value = TOKrcurly; return;
            case '?': p++; t->value = TOKquestion; return;
            case ',': p++; t->value = TOKcomma; return;
            case ';': p++; t->value = TOKsemicolon; return;
            case ':': p++; t->value = TOKcolon; return;
            case '$': p++; t->value = TOKdollar; return;
            case '@': p++; t->value = TOKat; return;

            case '*':
                p++;
                if (*p == '=')
                {   p++;
                    t->value = TOKmulass;
                }
                else
                    t->value = TOKmul;
                return;
            case '%':
                p++;
                if (*p == '=')
                {   p++;
                    t->value = TOKmodass;
                }
                else
                    t->value = TOKmod;
                return;

            case '#':
            {
                p++;
                Token n;
                scan(&n);
                if (n.value == TOKidentifier && n.ident == Id::line)
                {
                    poundLine();
                    continue;
                }
                else
                {
                    t->value = TOKpound;
                    return;
                }
            }

            default:
            {   unsigned c = *p;

                if (c & 0x80)
                {   c = decodeUTF();

                    // Check for start of unicode identifier
                    if (isUniAlpha(c))
                        goto case_ident;

                    if (c == PS || c == LS)
                    {
                        endOfLine();
                        p++;
                        continue;
                    }
                }
                if (c < 0x80 && isprint(c))
                    error("character '%c' is not a valid token", c);
                else
                    error("character 0x%02x is not a valid token", c);
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
                if (ishex((utf8_t)c))
                {   unsigned v;

                    n = 0;
                    v = 0;
                    while (1)
                    {
                        if (isdigit((utf8_t)c))
                            c -= '0';
                        else if (islower(c))
                            c -= 'a' - 10;
                        else
                            c -= 'A' - 10;
                        v = v * 16 + c;
                        c = *++p;
                        if (++n == ndigits)
                            break;
                        if (!ishex((utf8_t)c))
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
                    error("undefined escape hex sequence \\%c",c);
                break;

        case '&':                       // named character entity
                for (const utf8_t *idstart = ++p; 1; p++)
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
                if (isoctal((utf8_t)c))
                {   unsigned v;

                    n = 0;
                    v = 0;
                    do
                    {
                        v = v * 8 + (c - '0');
                        c = *++p;
                    } while (++n < 3 && isoctal((utf8_t)c));
                    c = v;
                    if (c > 0xFF)
                        error("0%03o is larger than a byte", c);
                }
                else
                    error("undefined escape sequence \\%c",c);
                break;
    }
    return c;
}

/**************************************
 */

TOK Lexer::wysiwygStringConstant(Token *t, int tc)
{
    unsigned c;
    Loc start = loc();

    p++;
    stringbuffer.reset();
    while (1)
    {
        c = *p++;
        switch (c)
        {
            case '\n':
                endOfLine();
                break;

            case '\r':
                if (*p == '\n')
                    continue;   // ignore
                c = '\n';       // treat EndOfLine as \n character
                endOfLine();
                break;

            case 0:
            case 0x1A:
                error("unterminated string constant starting at %s", start.toChars());
                t->ustring = (utf8_t *)"";
                t->len = 0;
                t->postfix = 0;
                return TOKstring;

            case '"':
            case '`':
                if (c == tc)
                {
                    t->len = (unsigned)stringbuffer.offset;
                    stringbuffer.writeByte(0);
                    t->ustring = (utf8_t *)mem.malloc(stringbuffer.offset);
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
                        endOfLine();
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
{
    unsigned c;
    Loc start = loc();
    unsigned n = 0;
    unsigned v = ~0; // dead assignment, needed to suppress warning

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
                endOfLine();
                continue;

            case 0:
            case 0x1A:
                error("unterminated string constant starting at %s", start.toChars());
                t->ustring = (utf8_t *)"";
                t->len = 0;
                t->postfix = 0;
                return TOKxstring;

            case '"':
                if (n & 1)
                {   error("odd number (%d) of hex characters in hex string", n);
                    stringbuffer.writeByte(v);
                }
                t->len = (unsigned)stringbuffer.offset;
                stringbuffer.writeByte(0);
                t->ustring = (utf8_t *)mem.malloc(stringbuffer.offset);
                memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
                stringPostfix(t);
                return TOKxstring;

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
                        endOfLine();
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
{
    unsigned c;
    Loc start = loc();
    unsigned delimleft = 0;
    unsigned delimright = 0;
    unsigned nest = 1;
    unsigned nestcount = ~0; // dead assignment, needed to suppress warning
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
                endOfLine();
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
                Token tok;
                p--;
                scan(&tok);               // read in heredoc identifier
                if (tok.value != TOKidentifier)
                {   error("identifier expected for heredoc, not %s", tok.toChars());
                    delimright = c;
                }
                else
                {   hereid = tok.ident;
                    //printf("hereid = '%s'\n", hereid->toChars());
                    blankrol = 1;
                }
                nest = 0;
            }
            else
            {   delimright = c;
                nest = 0;
                if (isspace(c))
                    error("delimiter cannot be whitespace");
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
            if (startline && isalpha(c) && hereid)
            {   Token tok;
                const utf8_t *psave = p;
                p--;
                scan(&tok);               // read in possible heredoc identifier
                //printf("endid = '%s'\n", tok.ident->toChars());
                if (tok.value == TOKidentifier && tok.ident->equals(hereid))
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
    else if (hereid)
        error("delimited string must end in %s\"", hereid->toChars());
    else
        error("delimited string must end in %c\"", delimright);
    t->len = (unsigned)stringbuffer.offset;
    stringbuffer.writeByte(0);
    t->ustring = (utf8_t *)mem.malloc(stringbuffer.offset);
    memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
    stringPostfix(t);
    return TOKstring;

Lerror:
    error("unterminated string constant starting at %s", start.toChars());
    t->ustring = (utf8_t *)"";
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
    Loc start = loc();
    const utf8_t *pstart = ++p;

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
    t->len = (unsigned)(p - 1 - pstart);
    t->ustring = (utf8_t *)mem.malloc(t->len + 1);
    memcpy(t->ustring, pstart, t->len);
    t->ustring[t->len] = 0;
    stringPostfix(t);
    return TOKstring;

Lerror:
    error("unterminated token string constant starting at %s", start.toChars());
    t->ustring = (utf8_t *)"";
    t->len = 0;
    t->postfix = 0;
    return TOKstring;
}



/**************************************
 */

TOK Lexer::escapeStringConstant(Token *t, int wide)
{
    unsigned c;
    Loc start = loc();

    p++;
    stringbuffer.reset();
    while (1)
    {
        c = *p++;
        switch (c)
        {
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
            case '\n':
                endOfLine();
                break;

            case '\r':
                if (*p == '\n')
                    continue;   // ignore
                c = '\n';       // treat EndOfLine as \n character
                endOfLine();
                break;

            case '"':
                t->len = (unsigned)stringbuffer.offset;
                stringbuffer.writeByte(0);
                t->ustring = (utf8_t *)mem.malloc(stringbuffer.offset);
                memcpy(t->ustring, stringbuffer.data, stringbuffer.offset);
                stringPostfix(t);
                return TOKstring;

            case 0:
            case 0x1A:
                p--;
                error("unterminated string constant starting at %s", start.toChars());
                t->ustring = (utf8_t *)"";
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
                        endOfLine();
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
        case '\n':
        L1:
            endOfLine();
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
    const utf8_t *start = p;
    unsigned c;
    uinteger_t n = 0;                       // unsigned >=64 bit integer type
    int d;
    bool err = false;
    bool overflow = false;

    c = *p;
    if (c == '0')
    {
        ++p;
        c = *p;
        switch (c)
        {
            case '0': case '1': case '2': case '3':
            case '4': case '5': case '6': case '7':
                n = c - '0';
                ++p;
                base = 8;
                break;

            case 'x':
            case 'X':
                ++p;
                base = 16;
                break;

            case 'b':
            case 'B':
                ++p;
                base = 2;
                break;

            case '.':
                if (p[1] == '.')
                    goto Ldone; // if ".."
                if (isalpha(p[1]) || p[1] == '_' || p[1] & 0x80)
                    goto Ldone; // if ".identifier" or ".unicode"
                goto Lreal; // '.' is part of current token

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
                d = c - '0';
                break;

            case '2': case '3':
            case '4': case '5': case '6': case '7':
                if (base == 2 && !err)
                {
                    error("binary digit expected");
                    err = true;
                }
                ++p;
                d = c - '0';
                break;

            case '8': case '9':
                ++p;
                if (base < 10 && !err)
                {
                    error("radix %d digit expected", base);
                    err = true;
                }
                d = c - '0';
                break;

            case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
            case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
                ++p;
                if (base != 16)
                {
                    if (c == 'e' || c == 'E' || c == 'f' || c == 'F')
                        goto Lreal;
                    if (!err)
                    {
                        error("radix %d digit expected", base);
                        err = true;
                    }
                }
                if (c >= 'a')
                    d = c + 10 - 'a';
                else
                    d = c + 10 - 'A';
                break;

            case 'L':
                if (p[1] == 'i')
                    goto Lreal;
                goto Ldone;

            case '.':
                if (p[1] == '.')
                    goto Ldone; // if ".."
                if (base == 10 && (isalpha(p[1]) || p[1] == '_' || p[1] & 0x80))
                    goto Ldone; // if ".identifier" or ".unicode"
                goto Lreal; // otherwise as part of a floating point literal

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

        uinteger_t n2 = n * base;
        if ((n2 / base != n || n2 + d < n))
        {
            overflow = true;
        }
        n = n2 + d;

        // if n needs more than 64 bits
        if (sizeof(n) > 8 &&
            n > 0xFFFFFFFFFFFFFFFFULL)
        {
            overflow = true;
        }
    }

Ldone:

    if (overflow && !err)
    {
        error("integer overflow");
        err = true;
    }

    enum FLAGS
    {
        FLAGS_none     = 0,
        FLAGS_decimal  = 1,             // decimal
        FLAGS_unsigned = 2,             // u or U suffix
        FLAGS_long     = 4,             // L suffix
    };

    FLAGS flags = (base == 10) ? FLAGS_decimal : FLAGS_none;

    // Parse trailing 'u', 'U', 'l' or 'L' in any combination
    const utf8_t *psuffix = p;
    while (1)
    {
        utf8_t f;
        switch (*p)
        {
            case 'U':
            case 'u':
                f = FLAGS_unsigned;
                goto L1;

            case 'l':
                f = FLAGS_long;
                error("Lower case integer suffix 'l' is not allowed. Please use 'L' instead");
                goto L1;

            case 'L':
                f = FLAGS_long;
            L1:
                p++;
                if ((flags & f) && !err)
                {
                    error("unrecognized token");
                    err = true;
                }
                flags = (FLAGS) (flags | f);
                continue;
            default:
                break;
        }
        break;
    }

    if (base == 8 && n >= 8)
        error("octal literals 0%llo%.*s are no longer supported, use std.conv.octal!%llo%.*s instead",
                n, p - psuffix, psuffix, n, p - psuffix, psuffix);

    TOK result;
    switch (flags)
    {
        case FLAGS_none:
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
            {
                if (!err)
                {
                    error("signed integer overflow");
                    err = true;
                }
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
            {
                if (!err)
                {
                    error("signed integer overflow");
                    err = true;
                }
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
{
    //printf("Lexer::inreal()\n");
#ifdef DEBUG
    assert(*p == '.' || isdigit(*p));
#endif
    stringbuffer.reset();
    const utf8_t *pstart = p;
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
        bool anyexp = false;
        while (1)
        {
            if (isdigit(c))
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
    t->float80value = Port::strtold((char *)stringbuffer.data, NULL);
    errno = 0;
    switch (*p)
    {
        case 'F':
        case 'f':
            // Only interested in errno return
            (void)Port::strtof((char *)stringbuffer.data, NULL);
            result = TOKfloat32v;
            p++;
            break;

        default:
            /* Should do our own strtod(), since dmc and linux gcc
             * accept 2.22507e-308, while apple gcc will only take
             * 2.22508e-308. Not sure who is right.
             */
            // Only interested in errno return
            (void)Port::strtod((char *)stringbuffer.data, NULL);
            result = TOKfloat64v;
            break;

        case 'l':
            error("'l' suffix is deprecated, use 'L' instead");
        case 'L':
            result = TOKfloat80v;
            p++;
            break;
    }
    if (*p == 'i' || *p == 'I')
    {
        if (*p == 'I')
            error("'I' suffix is deprecated, use 'i' instead");
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
            default: break;
        }
    }
    if (errno == ERANGE)
        error("number is not representable");
#ifdef DEBUG
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
#endif
    return result;
}

/*********************************************
 * parse:
 *      #line linnum [filespec]
 * also allow __LINE__ for linnum, and __FILE__ for filespec
 */

void Lexer::poundLine()
{
    Token tok;
    int linnum;
    char *filespec = NULL;
    Loc loc = this->loc();

    scan(&tok);
    if (tok.value == TOKint32v || tok.value == TOKint64v)
    {   linnum = (int)(tok.uns64value - 1);
        if (linnum != tok.uns64value - 1)
            error("line number out of range");
    }
    else if (tok.value == TOKline)
    {
        linnum = this->scanloc.linnum;
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
                this->scanloc.linnum = linnum;
                if (filespec)
                    this->scanloc.filename = filespec;
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
                    filespec = mem.strdup(scanloc.filename ? scanloc.filename : mod->ident->toChars());
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
    utf8_t c;
    const utf8_t *s = p;
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
    utf8_t ct = t->ptr[2];

    /* Start of comment text skips over / * *, / + +, or / / /
     */
    const utf8_t *q = t->ptr + 3;      // start of comment text

    const utf8_t *qend = p;
    if (ct == '*' || ct == '+')
        qend -= 2;

    /* Scan over initial row of ****'s or ++++'s or ////'s
     */
    for (; q < qend; q++)
    {
        if (*q != ct)
            break;
    }

    /* Remove leading spaces until start of the comment
     */
    int linestart = 0;
    if (ct == '/')
    {
        while (q < qend && (*q == ' ' || *q == '\t'))
            ++q;
    }
    else if (q < qend)
    {
        if (*q == '\r')
        {
            ++q;
            if (q < qend && *q == '\n')
                ++q;
            linestart = 1;
        }
        else if (*q == '\n')
        {
            ++q;
            linestart = 1;
        }
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

    for (; q < qend; q++)
    {
        utf8_t c = *q;

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

    /* Trim trailing whitespace (if the last line does not have newline)
     */
    if (buf.offset && (buf.data[buf.offset - 1] == ' ' || buf.data[buf.offset - 1] == '\t'))
    {
        while (buf.offset && (buf.data[buf.offset - 1] == ' ' || buf.data[buf.offset - 1] == '\t'))
            buf.offset--;
    }

    // Always end with a newline
    if (!buf.offset || buf.data[buf.offset - 1] != '\n')
        buf.writeByte('\n');

    buf.writeByte(0);

    // It's a line comment if the start of the doc comment comes
    // after other non-whitespace on the same line.
    const utf8_t** dc = (lineComment && anyToken)
                         ? &t->lineComment
                         : &t->blockComment;

    // Combine with previous doc comment, if any
    if (*dc)
        *dc = combineComments(*dc, (utf8_t *)buf.data);
    else
        *dc = (utf8_t *)buf.extractData();
}

/********************************************
 * Combine two document comments into one,
 * separated by a newline.
 */

const utf8_t *Lexer::combineComments(const utf8_t *c1, const utf8_t *c2)
{
    //printf("Lexer::combineComments('%s', '%s')\n", c1, c2);

    const utf8_t *c = c2;

    if (c1)
    {
        c = c1;
        if (c2)
        {
            size_t len1 = strlen((char *)c1);
            size_t len2 = strlen((char *)c2);

            int insertNewLine = 0;
            if (len1 && c1[len1 - 1] != '\n')
            {
                ++len1;
                insertNewLine = 1;
            }

            utf8_t *p = (utf8_t *)mem.malloc(len1 + 1 + len2 + 1);
            memcpy(p, c1, len1 - insertNewLine);
            if (insertNewLine)
                p[len1 - 1] = '\n';

            p[len1] = '\n';

            memcpy(p + len1 + 1, c2, len2);
            p[len1 + 1 + len2] = 0;
            c = p;
        }
    }
    return c;
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
        sv->ptrvalue = (char *)id;
    }
    return id;
}

/*********************************************
 * Create a unique identifier using the prefix s.
 */

Identifier *Lexer::uniqueId(const char *s, int num)
{
    const size_t BUFFER_LEN = 32;
    char buffer[BUFFER_LEN];
    size_t slen = strlen(s);

    assert(slen + sizeof(num) * 3 + 1 <= BUFFER_LEN);
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
    TOK value;
};

static size_t nkeywords;
static Keyword keywords[] =
{
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
    {   "cent",         TOKint128,      },
    {   "ucent",        TOKuns128,      },
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

    {   "__argTypes",   TOKargTypes     },
    {   "__parameters", TOKparameters   },
    {   "ref",          TOKref          },
    {   "macro",        TOKmacro        },

    {   "pure",         TOKpure         },
    {   "nothrow",      TOKnothrow      },
    {   "__gshared",    TOKgshared      },
    {   "__traits",     TOKtraits       },
    {   "__vector",     TOKvector       },
    {   "__overloadset", TOKoverloadset },
    {   "__FILE__",     TOKfile         },
    {   "__LINE__",     TOKline         },
    {   "__MODULE__",   TOKmodulestring },
    {   "__FUNCTION__", TOKfuncstring   },
    {   "__PRETTY_FUNCTION__", TOKprettyfunc   },
    {   "shared",       TOKshared       },
    {   "immutable",    TOKimmutable    },
    {   NULL,           TOKreserved     }
};

int Token::isKeyword()
{
    for (size_t u = 0; u < nkeywords; u++)
    {
        if (keywords[u].value == value)
            return 1;
    }
    return 0;
}

void Lexer::initKeywords()
{
    stringtable._init(28000);

    cmtable_init();

    for (nkeywords = 0; keywords[nkeywords].name; nkeywords++)
    {
        //printf("keyword[%d] = '%s'\n",u, keywords[u].name);
        const char *s = keywords[nkeywords].name;
        TOK v = keywords[nkeywords].value;
        StringValue *sv = stringtable.insert(s, strlen(s));
        sv->ptrvalue = (char *)new Identifier(sv->toDchars(),v);

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
    Token::tochars[TOKblit]             = "=";
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
    Token::tochars[TOKat]               = "@";
    Token::tochars[TOKpow]              = "^^";
    Token::tochars[TOKpowass]           = "^^=";
    Token::tochars[TOKgoesto]           = "=>";
    Token::tochars[TOKpound]            = "#";

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
    const utf8_t text[] = "int";
    Lexer lex1(NULL, (utf8_t *)text, 0, sizeof(text), 0, 0);
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
