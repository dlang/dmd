
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/* HTML parser
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <errno.h>
#include <wchar.h>

#include "root.h"
#include "html.h"

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
    this->sourcename = sourcename;
    this->base = base;
    p = base;
    end = base + length;
    linnum = 0;
    dbuf = NULL;
    inCode = 0;
}

/**********************************************
 * Print error & quit.
 */

void Html::error(const char *format, ...)
{
    printf("%s(%d) : HTML Error: ", sourcename, linnum);

    va_list ap;
    va_start(ap, format);
    vprintf(format, ap);
    va_end(ap);

    printf("\n");
    fflush(stdout);

    global.errors++;
    fatal();
}

/**********************************************
 * Extract all the code from an HTML file,
 * concatenate it all together, and store in buf.
 */

void Html::extractCode(OutBuffer *buf)
{
    dbuf = buf;			// save for other routines
    buf->reserve(end - p);
    inCode = 0;
    while (1)
    {
	switch (*p)
	{
	    case '"':
	    case '\'':
		skipString();
		continue;

	    case '<':
		if (p[1] == '!' && p[2] == '-' && p[3] == '-')
		{   // Comments start with <!--
		    p += 4;
		    scanComment();
		}
		else if ((p[1] == '/' && istagstart(p[2])) ||
			 istagstart(p[1]))
		    skipTag();
		continue;

	    case 0:
	    case 0x1a:
		break;		// end of file

	    case '&':
		if (inCode)
		{   // Translate character entity into ascii for D parser
		    // BUG: wchar?
		    int c;

		    c = charEntity();
		    buf->writeByte(c);		// BUG: wchar
		}
		else
		    p++;
		continue;

	    case '\n':
		linnum++;
		// Always extract new lines, so that D lexer counts the
		// lines right.
		buf->writeByte(*p);		// BUG: wchar
		p++;
		continue;

	    default:
		if (inCode)
		    buf->writeByte(*p);		// BUG: wchar
		p++;
		continue;
	}
	break;
    }
    buf->writeByte(0);				// ending sentinel
						// BUG: wchar
    //printf("D code is: '%s'\n", (char *)buf->data);
}

/***********************************************
 * Scan to end of <> tag.
 * Look for <code> and </code> tags to start/stop D processing.
 * Input:
 *	p is on opening '<' of tag; it's already verified that
 *	it's a tag by lookahead
 * Output:
 *	p is past closing '>' of tag
 */

void Html::skipTag()
{
    enum TagState	// what parsing state we're in
    {
	TStagstart,	// start of tag name
	TStag,		// in a tag name
	TSrest,		// following tag name
    };
    enum TagState state = TStagstart;
    int nottag;
    unsigned char *tagstart = NULL;
    int taglen = 0;

    p++;
    nottag = 0;
    if (*p == '/')
    {	nottag = 1;
	p++;
    }
    while (1)
    {
	switch (*p)
	{
	    case '>':		// found end of tag
		p++;
		break;

	    case '"':
	    case '\'':
		state = TSrest;
		skipString();
		continue;

	    case '<':
		if (p[1] == '!' && p[2] == '-' && p[3] == '-')
		{   // Comments start with <!--
		    p += 4;
		    scanComment();
		}
		else if ((p[1] == '/' && istagstart(p[2])) ||
			 istagstart(p[1]))
		{   error("nested tag");
		    skipTag();
		}
		// Treat comments as if they were whitespace
		state = TSrest;
		continue;

	    case 0:
	    case 0x1a:
		error("end of file before end of tag");
		break;		// end of file

	    case '\n':
		linnum++;
		// Always extract new lines, so that code lexer counts the
		// lines right.
		dbuf->writeByte(*p);		// BUG: wchar
		state = TSrest;			// end of tag
		p++;
		continue;

	    default:
		switch (state)
		{
		    case TStagstart:		// start of tag name
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
    if (taglen && memicmp((char *)tagstart, "CODE", taglen) == 0)
    {
	if (nottag)
	{   inCode--;
	    if (inCode < 0)
		inCode = 0;		// ignore extra </code>'s
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

	    case '\n':
		linnum++;
		// Always extract new lines, so that D lexer counts the
		// lines right.
		dbuf->writeByte(*p);		// BUG: wchar
		continue;

	    case 0:
	    case 0x1a:
	    Leof:
		error("end of file before closing %c of string", tc);
		break;

	    default:
		continue;
	}
	break;
    }
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

    while (1)
    {
	scangt = 1;			// IE 5.0 compatibility
	p++;
	switch (*p)
	{
	    case '-':
		if (p[1] == '-')
		{
		    if (p[2] == '>')	// optimize for most common case
		    {
			p += 3;
			break;
		    }
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
	    case '\r':
	    case '\f':
	    case '\v':
		// skip white space
		continue;

	    case '\n':
		linnum++;		// remember to count lines
		// Always extract new lines, so that D lexer counts the
		// lines right.
		dbuf->writeByte(*p);		// BUG: wchar
		continue;

	    case 0:
	    case 0x1a:
		error("end of file before closing --> of comment");
		break;

	    default:
		scangt = 0;		// it's not -->
		continue;
	}
	break;
    }
}

/********************************************
 * Convert an HTML character entity into a character.
 * Forms are:
 *	&name;		named entity
 *	&#ddd;		decimal
 *	&#xhhhh;	hex
 * Input:
 *	p is on the &
 */

int Html::charEntity()
{   int c = 0;
    int v;
    int hex;

    if (p[1] == '#')
    {
	p++;
	if (p[1] == 'x' || p[1] == 'X')
	{   p++;
	    hex = 1;
	}
	else
	    hex = 0;

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
		case '<':	// tag start
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
		    if (c > 0xFFFF)
			error("character entity out of range");
		    continue;

		default:
		Linvalid:
		    error("invalid numeric character reference");
		    break;
	    }
	}

	// Kludge to convert non-breaking space to ascii space
	if (c == 160)
	    c = 32;
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
		case '<':	// tag start
		    // Termination is assumed
		    c = namedEntity(idstart, p - idstart);
		    break;

		case ';':
		    // Termination is explicit
		    c = namedEntity(idstart, p - idstart);
		    p++;
		    break;

		default:
		    continue;
	    }
	    break;
	}
    }
    return c;
}

/*********************************************
 * Convert from named entity to its encoding.
 */

struct NameId
{
    char *name;
    int value;
};

static NameId names[] =
{
    "quot",	34,
    "amp",	38,
    "lt",	60,
    "gt",	62,
//    "nbsp",	160,
    "nbsp",	32,		// make non-breaking space appear as space
    "iexcl",	161,
    "cent",	162,
    "pound",	163,
    "curren",	164,
    "yen",	165,
    "brvbar",	166,
    "sect",	167,
    "uml",	168,
    "copy",	169,
    "ordf",	170,
    "laquo",	171,
    "not",	172,
    "shy",	173,
    "reg",	174,

    // BUG: This is only a partial list.
    // For the rest, consult:
    // http://www.w3.org/TR/1999/REC-html401-19991224/sgml/entities.html
};

int Html::namedEntity(unsigned char *p, int length)
{
    int i;

    // BUG: this is a dumb, slow linear search
    for (i = 0; i < sizeof(names) / sizeof(names[0]); i++)
    {
	// Do case insensitive compare
	if (memicmp(names[i].name, (char *)p, length) == 0)
	    return names[i].value;
    }
    error("unrecognized character entity");
    return 0;
}
