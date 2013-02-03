
// Copyright (c) 1999-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gpl.txt.
// See the included readme.txt for details.


/* HTML parser
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <errno.h>
#include <wchar.h>

#include "html.h"

#if MARS
#include <assert.h>
#include "root.h"
//#include "../mars/mars.h"
#else
#include "outbuf.h"
#include "msgs2.h"

extern void html_err(const char *, unsigned, unsigned, ...);

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"
#endif

int mymemicmp(const char *s1, const char *s2, int n)
{
    int result = 0;

    for (int i = 0; i < n; i++)
    {   char c1 = s1[i];
        char c2 = s2[i];

        result = c1 - c2;
        if (result)
        {
            if ('A' <= c1 && c1 <= 'Z')
                c1 += 'a' - 'A';
            if ('A' <= c2 && c2 <= 'Z')
                c2 += 'a' - 'A';
            result = c1 - c2;
            if (result)
                break;
        }
    }
    return result;
}

extern int HtmlNamedEntity(unsigned char *p, int length);

static int isLineSeparator(const unsigned char* p);

/**********************************
 * Determine if beginning of tag identifier
 * or a continuation of a tag identifier.
 */

inline int istagstart(int c)
{
    return (isalpha(c) || c == '_');
}

inline int istag(int c)
{
    return (isalnum(c) || c == '_');
}

/**********************************************
 */

Html::Html(const char *sourcename, unsigned char *base, unsigned length)
{
    //printf("Html::Html()\n");
    this->sourcename = sourcename;
    this->base = base;
    p = base;
    end = base + length;
    linnum = 1;
    dbuf = NULL;
    inCode = 0;
}

/**********************************************
 * Print error & quit.
 */

void Html::error(const char *format, ...)
{
    fprintf(stderr, "%s(%d) : HTML Error: ", sourcename, linnum);

    va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);

    fprintf(stderr, "\n");
    fflush(stderr);

//#if MARS
//    global.errors++;
//#else
    exit(EXIT_FAILURE);
//#endif
}

/**********************************************
 * Extract all the code from an HTML file,
 * concatenate it all together, and store in buf.
 */

#if MARS
void Html::extractCode(OutBuffer *buf)
#else
void Html::extractCode(Outbuffer *buf)
#endif
{
    //printf("Html::extractCode()\n");
    dbuf = buf;                 // save for other routines
    buf->reserve(end - p);
    inCode = 0;
    while (1)
    {
        //printf("p = %p, *p = x%x\n", p, *p);
        switch (*p)
        {
#if 0 // strings are not recognized outside of tags
            case '"':
            case '\'':
                skipString();
                continue;
#endif
            case '<':
                if (p[1] == '!' && isCommentStart())
                {   // Comments start with <!--
                    scanComment();
                }
                else if(p[1] == '!' && isCDATAStart())
                {
                    scanCDATA();
                }
                else if (p[1] == '/' && istagstart(*skipWhite(p + 2)))
                    skipTag();
                else if (istagstart(*skipWhite(p + 1)))
                    skipTag();
                else
                    goto Ldefault;
                continue;

            case 0:
            case 0x1a:
                break;          // end of file

            case '&':
                if (inCode)
                {   // Translate character entity into ascii for D parser
                    int c;

                    c = charEntity();
#if MARS
                    buf->writeUTF8(c);
#else
                    buf->writeByte(c);
#endif
                }
                else
                    p++;
                continue;

            case '\r':
                if (p[1] == '\n')
                    goto Ldefault;
            case '\n':
                linnum++;
                // Always extract new lines, so that D lexer counts the
                // lines right.
                buf->writeByte(*p);
                p++;
                continue;

            default:
            Ldefault:
                if (inCode)
                    buf->writeByte(*p);
                p++;
                continue;
        }
        break;
    }
    buf->writeByte(0);                          // ending sentinel
#if SCPP
    //printf("Code is: '%s'\n", buf->toString() + 3);
#endif
#if MARS
    //printf("D code is: '%s'\n", (char *)buf->data);
#endif
}

/***********************************************
 * Scan to end of <> tag.
 * Look for <code> and </code> tags to start/stop D processing.
 * Input:
 *      p is on opening '<' of tag; it's already verified that
 *      it's a tag by lookahead
 * Output:
 *      p is past closing '>' of tag
 */

void Html::skipTag()
{
    enum TagState       // what parsing state we're in
    {
        TStagstart,     // start of tag name
        TStag,          // in a tag name
        TSrest,         // following tag name
    };
    enum TagState state = TStagstart;
    int inot;
    unsigned char *tagstart = NULL;
    int taglen = 0;

    p++;
    inot = 0;
    if (*p == '/')
    {   inot = 1;
        p++;
    }
    while (1)
    {
        switch (*p)
        {
            case '>':           // found end of tag
                p++;
                break;

            case '"':
            case '\'':
                state = TSrest;
                skipString();
                continue;

            case '<':
                if (p[1] == '!' && isCommentStart())
                {   // Comments start with <!--
                    scanComment();
                }
                else if (p[1] == '/' && istagstart(*skipWhite(p + 2)))
                {   error("nested tag");
                    skipTag();
                }
                else if (istagstart(*skipWhite(p + 1)))
                {   error("nested tag");
                    skipTag();
                }
                // Treat comments as if they were whitespace
                state = TSrest;
                continue;

            case 0:
            case 0x1a:
                error("end of file before end of tag");
                break;          // end of file

            case '\r':
                if (p[1] == '\n')
                    goto Ldefault;
            case '\n':
                linnum++;
                // Always extract new lines, so that code lexer counts the
                // lines right.
                dbuf->writeByte(*p);
                state = TSrest;                 // end of tag
                p++;
                continue;

            case ' ':
            case '\t':
            case '\f':
            case '\v':
                if (state == TStagstart)
                {   p++;
                    continue;
                }
            default:
            Ldefault:
                switch (state)
                {
                    case TStagstart:            // start of tag name
                        assert(istagstart(*p));
                        state = TStag;
                        tagstart = p;
                        taglen = 0;
                        break;

                    case TStag:
                        if (istag(*p))
                        {   // Continuing tag name
                            taglen++;
                        }
                        else
                        {   // End of tag name
                            state = TSrest;
                        }
                        break;

                    case TSrest:
                        break;
                }
                p++;
                continue;
        }
        break;
    }

    // See if we parsed a <code> or </code> tag
    if (taglen && mymemicmp((char *) tagstart, (char *) "CODE", taglen) == 0
        && *(p - 2) != '/') // ignore "<code />" (XHTML)
    {
        if (inot)
        {   inCode--;
            if (inCode < 0)
                inCode = 0;             // ignore extra </code>'s
        }
        else
            inCode++;
    }
}

/***********************************************
 * Scan to end of attribute string.
 */

void Html::skipString()
{
    int tc = *p;

    while (1)
    {
        p++;
        switch (*p)
        {
            case '"':
            case '\'':
                if (*p == tc)
                {   p++;
                    break;
                }
                continue;

            case '\r':
                if (p[1] == '\n')
                    goto Ldefault;
            case '\n':
                linnum++;
                // Always extract new lines, so that D lexer counts the
                // lines right.
                dbuf->writeByte(*p);
                continue;

            case 0:
            case 0x1a:
            Leof:
                error("end of file before closing %c of string", tc);
                break;

            default:
            Ldefault:
                continue;
        }
        break;
    }
}

/*********************************
 * If p points to any white space, skip it
 * and return pointer just past it.
 */

unsigned char *Html::skipWhite(unsigned char *q)
{
    for (; 1; q++)
    {
        switch (*q)
        {
            case ' ':
            case '\t':
            case '\f':
            case '\v':
            case '\r':
            case '\n':
                continue;

            default:
                break;
        }
        break;
    }
    return q;
}

/***************************************************
 * Scan to end of comment.
 * Comments are defined any of a number of ways.
 * IE 5.0: <!-- followed by >
 * "HTML The Definitive Guide": <!-- text with at least one space in it -->
 * Netscape: <!-- --> comments nest
 * w3c: whitespace can appear between -- and > of comment close
 */

void Html::scanComment()
{
    // Most of the complexity is dealing with the case that
    // an arbitrary amount of whitespace can appear between
    // the -- and the > of a comment close.
    int scangt = 0;

    //printf("scanComment()\n");
    if (*p == '\n')
    {   linnum++;
        // Always extract new lines, so that D lexer counts the
        // lines right.
        dbuf->writeByte(*p);
    }
    while (1)
    {
        //scangt = 1;                   // IE 5.0 compatibility
        p++;
        switch (*p)
        {
            case '-':
                if (p[1] == '-')
                {
                    if (p[2] == '>')    // optimize for most common case
                    {
                        p += 3;
                        break;
                    }
                    p++;
                    scangt = 1;
                }
                else
                    scangt = 0;
                continue;

            case '>':
                if (scangt)
                {   // found -->
                    p++;
                    break;
                }
                continue;

            case ' ':
            case '\t':
            case '\f':
            case '\v':
                // skip white space
                continue;

            case '\r':
                if (p[1] == '\n')
                    goto Ldefault;
            case '\n':
                linnum++;               // remember to count lines
                // Always extract new lines, so that D lexer counts the
                // lines right.
                dbuf->writeByte(*p);
                continue;

            case 0:
            case 0x1a:
                error("end of file before closing --> of comment");
                break;

            default:
            Ldefault:
                scangt = 0;             // it's not -->
                continue;
        }
        break;
    }
    //printf("*p = '%c'\n", *p);
}

/********************************************
 * Determine if we are at the start of a comment.
 * Input:
 *      p is on the opening '<'
 * Returns:
 *      0 if not start of a comment
 *      1 if start of a comment, p is adjusted to point past --
 */

int Html::isCommentStart()
#ifdef __DMC__
    __out(result)
    {
        if (result == 0)
            ;
        else if (result == 1)
        {
            assert(p[-2] == '-' && p[-1] == '-');
        }
        else
            assert(0);
    }
    __body
#endif /* __DMC__ */
    {   unsigned char *s;

        if (p[0] == '<' && p[1] == '!')
        {
            for (s = p + 2; 1; s++)
            {
                switch (*s)
                {
                    case ' ':
                    case '\t':
                    case '\r':
                    case '\f':
                    case '\v':
                        // skip white space, even though spec says no
                        // white space is allowed
                        continue;

                    case '-':
                        if (s[1] == '-')
                        {
                            p = s + 2;
                            return 1;
                        }
                        goto No;

                    default:
                        goto No;
                }
            }
        }
    No:
        return 0;
    }

int Html::isCDATAStart()
{
    const char * CDATA_START_MARKER = "<![CDATA[";
    size_t len = strlen(CDATA_START_MARKER);

    if (strncmp((char*)p, CDATA_START_MARKER, len) == 0)
    {
        p += len;
        return 1;
    }
    else
    {
        return 0;
    }
}

void Html::scanCDATA()
{
    while(*p && *p != 0x1A)
    {
        int lineSepLength = isLineSeparator(p);
        if (lineSepLength>0)
        {
            /* Always extract new lines, so that D lexer counts the lines
             * right.
             */
            linnum++;
            dbuf->writeByte('\n');
            p += lineSepLength;
            continue;
        }
        else if (p[0] == ']' && p[1] == ']' && p[2] == '>')
        {
            /* end of CDATA section */
            p += 3;
            return;
        }
        else if (inCode)
        {
            /* this CDATA section contains D code */
            dbuf->writeByte(*p);
        }

        p++;
    }
}


/********************************************
 * Convert an HTML character entity into a character.
 * Forms are:
 *      &name;          named entity
 *      &#ddd;          decimal
 *      &#xhhhh;        hex
 * Input:
 *      p is on the &
 */

int Html::charEntity()
{   int c = 0;
    int v;
    int hex;
    unsigned char *pstart = p;

    //printf("Html::charEntity('%c')\n", *p);
    if (p[1] == '#')
    {
        p++;
        if (p[1] == 'x' || p[1] == 'X')
        {   p++;
            hex = 1;
        }
        else
            hex = 0;
        if (p[1] == ';')
            goto Linvalid;
        while (1)
        {
            p++;
            switch (*p)
            {
                case 0:
                case 0x1a:
                    error("end of file before end of character entity");
                    goto Lignore;

                case '\n':
                case '\r':
                case '<':       // tag start
                    // Termination is assumed
                    break;

                case ';':
                    // Termination is explicit
                    p++;
                    break;

                case '0': case '1': case '2': case '3': case '4':
                case '5': case '6': case '7': case '8': case '9':
                    v = *p - '0';
                    goto Lvalue;

                case 'a': case 'b': case 'c':
                case 'd': case 'e': case 'f':
                    if (!hex)
                        goto Linvalid;
                    v = (*p - 'a') + 10;
                    goto Lvalue;

                case 'A': case 'B': case 'C':
                case 'D': case 'E': case 'F':
                    if (!hex)
                        goto Linvalid;
                    v = (*p - 'A') + 10;
                    goto Lvalue;

                Lvalue:
                    if (hex)
                        c = (c << 4) + v;
                    else
                        c = (c * 10) + v;
                    if (c > 0x10FFFF)
                    {
                        error("character entity out of range");
                        goto Lignore;
                    }
                    continue;

                default:
                Linvalid:
                    error("invalid numeric character reference");
                    goto Lignore;
            }
            break;
        }
    }
    else
    {
        // It's a named entity; gather all characters until ;
        unsigned char *idstart = p + 1;

        while (1)
        {
            p++;
            switch (*p)
            {
                case 0:
                case 0x1a:
                    error("end of file before end of character entity");
                    break;

                case '\n':
                case '\r':
                case '<':       // tag start
                    // Termination is assumed
                    c = HtmlNamedEntity(idstart, p - idstart);
                    if (c == -1)
                        goto Lignore;
                    break;

                case ';':
                    // Termination is explicit
                    c = HtmlNamedEntity(idstart, p - idstart);
                    if (c == -1)
                        goto Lignore;
                    p++;
                    break;

                default:
                    continue;
            }
            break;
        }
    }

    // Kludge to convert non-breaking space to ascii space
    if (c == 160)
        c = ' ';

    return c;

Lignore:
    //printf("Lignore\n");
    p = pstart + 1;
    return '&';
}

/**
 * identify DOS, Linux, Mac, Next and Unicode line endings
 * 0 if this is no line separator
 * >0 the length of the separator
 * Note: input has to be UTF-8
 */
static int isLineSeparator(const unsigned char* p)
{
    // Linux
    if( p[0]=='\n')
        return 1;

    // Mac & Dos
    if( p[0]=='\r')
        return (p[1]=='\n') ? 2 : 1;

    // Unicode (line || paragraph sep.)
    if( p[0]==0xE2 && p[1]==0x80 && (p[2]==0xA8 || p[2]==0xA9))
        return 3;

    // Next
    if( p[0]==0xC2 && p[1]==0x85)
        return 2;

    return 0;
}


