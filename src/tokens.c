
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/lexer.c
 */

#include <stdio.h>
#include <ctype.h>

#include "lexer.h"
#include "rmem.h"
#include "outbuffer.h"
#include "id.h"
#include "identifier.h"
#include "utf.h"

/************************* Token **********************************************/

Token *Token::freelist = NULL;

const char *Token::tochars[TOKMAX];

Token *Token::alloc()
{
    if (Token::freelist)
    {
        Token *t = freelist;
        freelist = t->next;
        t->next = NULL;
        return t;
    }

    return new Token();
}

void Token::free()
{
    next = freelist;
    freelist = this;
}

#ifdef DEBUG
void Token::print()
{
    fprintf(stderr, "%s\n", toChars());
}
#endif

const char *Token::toChars()
{
    static char buffer[3 + 3 * sizeof(float80value) + 1];

    const char *p = &buffer[0];
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
        {
            OutBuffer buf;
            buf.writeByte('"');
            for (size_t i = 0; i < len; )
            {
                unsigned c;
                utf_decodeChar((utf8_t *)ustring, len, &i, &c);
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
{
    static char buffer[3 + 3 * sizeof(value) + 1];

    const char *p = tochars[value];
    if (!p)
    {
        sprintf(&buffer[0],"TOK%d",value);
        p = &buffer[0];
    }
    return p;
}
