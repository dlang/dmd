
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/* Simple macro text processor.
 */

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <ctype.h>
#include <assert.h>

#include "rmem.h"
#include "root.h"

#include "macro.h"

int isIdStart(unsigned char *p);
int isIdTail(unsigned char *p);
int utfStride(unsigned char *p);

unsigned char *memdup(unsigned char *p, size_t len)
{
    return (unsigned char *)memcpy(mem.malloc(len), p, len);
}

Macro::Macro(unsigned char *name, size_t namelen, unsigned char *text, size_t textlen)
{
    next = NULL;

#if 1
    this->name = name;
    this->namelen = namelen;

    this->text = text;
    this->textlen = textlen;
#else
    this->name = name;
    this->namelen = namelen;

    this->text = text;
    this->textlen = textlen;
#endif
    inuse = 0;
}


Macro *Macro::search(const unsigned char *name, size_t namelen)
{   Macro *table;

    //printf("Macro::search(%.*s)\n", namelen, name);
    for (table = this; table; table = table->next)
    {
        if (table->namelen == namelen &&
            memcmp(table->name, name, namelen) == 0)
        {
            //printf("\tfound %.*s\n", (int)namelen, name);
            break;
        }
    }
    return table;
}

Macro *Macro::define(Macro **ptable, unsigned char *name, size_t namelen, unsigned char *text, size_t textlen)
{
    //printf("Macro::define('%.*s' = '%.*s')\n", namelen, name, textlen, text);

    Macro *table;

    //assert(ptable);
    for (table = *ptable; table; table = table->next)
    {
        if (table->namelen == namelen &&
            memcmp(table->name, name, namelen) == 0)
        {
            table->text = text;
            table->textlen = textlen;
            return table;
        }
    }
    table = new Macro(name, namelen, text, textlen);
    table->next = *ptable;
    *ptable = table;
    return table;
}

/**********************************************************
 * Given buffer p[0..end], extract argument marg[0..marglen].
 * Params:
 *      n       0:      get entire argument
 *              1..9:   get nth argument
 *              -1:     get 2nd through end
 */

size_t extractArgN(unsigned char *p, size_t end, unsigned char **pmarg, size_t *pmarglen, int n)
{
    /* Scan forward for matching right parenthesis.
     * Nest parentheses.
     * Skip over $( and $)
     * Skip over "..." and '...' strings inside HTML tags.
     * Skip over <!-- ... --> comments.
     * Skip over previous macro insertions
     * Set marglen.
     */
    unsigned parens = 1;
    unsigned char instring = 0;
    unsigned incomment = 0;
    unsigned intag = 0;
    unsigned inexp = 0;
    unsigned argn = 0;

    size_t v = 0;

  Largstart:
#if 1
    // Skip first space, if any, to find the start of the macro argument
    if (v < end && isspace(p[v]))
        v++;
#else
    // Skip past spaces to find the start of the macro argument
    for (; v < end && isspace(p[v]); v++)
        ;
#endif
    *pmarg = p + v;

    for (; v < end; v++)
    {   unsigned char c = p[v];

        switch (c)
        {
            case ',':
                if (!inexp && !instring && !incomment && parens == 1)
                {
                    argn++;
                    if (argn == 1 && n == -1)
                    {   v++;
                        goto Largstart;
                    }
                    if (argn == n)
                        break;
                    if (argn + 1 == n)
                    {   v++;
                        goto Largstart;
                    }
                }
                continue;

            case '(':
                if (!inexp && !instring && !incomment)
                    parens++;
                continue;

            case ')':
                if (!inexp && !instring && !incomment && --parens == 0)
                {
                    break;
                }
                continue;

            case '"':
            case '\'':
                if (!inexp && !incomment && intag)
                {
                    if (c == instring)
                        instring = 0;
                    else if (!instring)
                        instring = c;
                }
                continue;

            case '<':
                if (!inexp && !instring && !incomment)
                {
                    if (v + 6 < end &&
                        p[v + 1] == '!' &&
                        p[v + 2] == '-' &&
                        p[v + 3] == '-')
                    {
                        incomment = 1;
                        v += 3;
                    }
                    else if (v + 2 < end &&
                        isalpha(p[v + 1]))
                        intag = 1;
                }
                continue;

            case '>':
                if (!inexp)
                    intag = 0;
                continue;

            case '-':
                if (!inexp &&
                    !instring &&
                    incomment &&
                    v + 2 < end &&
                    p[v + 1] == '-' &&
                    p[v + 2] == '>')
                {
                    incomment = 0;
                    v += 2;
                }
                continue;

            case 0xFF:
                if (v + 1 < end)
                {
                    if (p[v + 1] == '{')
                        inexp++;
                    else if (p[v + 1] == '}')
                        inexp--;
                }
                continue;

            default:
                continue;
        }
        break;
    }
    if (argn == 0 && n == -1)
        *pmarg = p + v;
    *pmarglen = p + v - *pmarg;
    //printf("extractArg%d('%.*s') = '%.*s'\n", n, end, p, *pmarglen, *pmarg);
    return v;
}


/*****************************************************
 * Expand macro in place in buf.
 * Only look at the text in buf from start to end.
 */

void Macro::expand(OutBuffer *buf, size_t start, size_t *pend,
        unsigned char *arg, size_t arglen)
{
#if 0
  printf("Macro::expand(buf[%zd..%zd], arg = '%.*s')\n", start, *pend,
         int(arglen > 40 ? 40 : arglen), arg);
  printf("Buf is: '%.*s'\n", int(*pend - start > 40 ? 40 : *pend - start),
         buf->data + start);
#endif

    static int nest;
    if (nest > 100)             // limit recursive expansion
        return;
    nest++;

    size_t end = *pend;
    assert(start <= end);
    assert(end <= buf->offset);

    /* First pass - replace $0
     */
    arg = memdup(arg, arglen);
    for (size_t u = start; u + 1 < end; )
    {
        unsigned char *p = buf->data;   // buf->data is not loop invariant

        /* Look for $0, but not $$0, and replace it with arg.
         */
        if (p[u] != '$' || !isdigit(p[u + 1]) && p[u + 1] != '+')
        {
            ++u;
            continue;
        }

        if (u > start && p[u - 1] == '$')
        {   // Don't expand $$0, but replace it with $0
            buf->remove(u - 1, 1);
            end--;
            ++u; // now u is one past the closing '1'
            continue;
        }

        unsigned char c = p[u + 1];
        int n = (c == '+') ? -1 : c - '0';

        unsigned char *marg;
        size_t marglen;
        extractArgN(arg, arglen, &marg, &marglen, n);
        if (marglen == 0)
        {   // Just remove macro invocation
            //printf("Replacing '$%c' with '%.*s'\n", p[u + 1], marglen, marg);
            buf->remove(u, 2);
            end -= 2;
        }
        else if (c == '+')
        {
            // Replace '$+' with 'arg'
            //printf("Replacing '$%c' with '%.*s'\n", p[u + 1], marglen, marg);
            buf->remove(u, 2);
            buf->insert(u, marg, marglen);
            end += marglen - 2;

            // Scan replaced text for further expansion
            size_t mend = u + marglen;
            expand(buf, u, &mend, NULL, 0);
            end += mend - (u + marglen);
            u = mend;
        }
        else
        {
            // Replace '$1' with '\xFF{arg\xFF}'
            //printf("Replacing '$%c' with '\xFF{%.*s\xFF}'\n", p[u + 1], marglen, marg);
            buf->data[u] = 0xFF;
            buf->data[u + 1] = '{';
            buf->insert(u + 2, marg, marglen);
            buf->insert(u + 2 + marglen, "\xFF}", 2);
            end += -2 + 2 + marglen + 2;

            // Scan replaced text for further expansion
            size_t mend = u + 2 + marglen;
            expand(buf, u + 2, &mend, NULL, 0);
            end += mend - (u + 2 + marglen);
            u = mend;
        }
        //printf("u = %d, end = %d\n", u, end);
        //printf("#%.*s#\n", end, &buf->data[0]);
    }

    /* Second pass - replace other macros
     */
    for (size_t u = start; u + 4 < end; )
    {
        unsigned char *p = buf->data;   // buf->data is not loop invariant

        /* A valid start of macro expansion is $(c, where c is
         * an id start character, and not $$(c.
         */
        if (p[u] != '$' || p[u + 1] != '(' || !isIdStart(p+u+2))
        {
            // Not a macro, so just move on
            ++u;
            continue;
        }

        //printf("\tfound macro start '%c'\n", p[u + 2]);
        unsigned char *name = p + u + 2;
        size_t namelen = 0;

        /* Scan forward to find end of macro name and
         * beginning of macro argument (marg).
         */
        size_t v = u + 2;
        for (; v < end; v+=utfStride(p+v))
        {
            if (!isIdTail(p+v))
            {   // We've gone past the end of the macro name.
                namelen = v - (u + 2);
                break;
            }
        }

        unsigned char *marg;
        size_t marglen;
        v += extractArgN(p + v, end - v, &marg, &marglen, 0);
        assert(v <= end);

        if (v >= end)
        {
            ++u;
            continue;
        }

        if (u > start && p[u - 1] == '$')
        {   // Don't expand $$(NAME), but replace it with $(NAME)
            buf->remove(u - 1, 1);
            end--;
            u = v;      // now u is one past the closing ')'
            continue;
        }

        bool macroWasUndefined = false;
        Macro *m = search(name, namelen);
        if (!m)
        {
            m = search((const unsigned char*)"DDOC_UNDEFINED_MACRO",
                       20 /* strlen("DDOC_UNDEFINED_MACRO") */);
            if (m)
            {
                macroWasUndefined = true;
            }
        }

        if (!m)
        {
            // Replace $(NAME) with nothing
            buf->remove(u, v + 1 - u);
            end -= v + 1 - u;
            continue;
        }

        if (m->inuse && marglen == 0)
        {
            // Recursive macro with empty argument => remove macro
            // invocation to stop recursion.
            buf->remove(u, v + 1 - u);
            end -= v + 1 - u;
        }
        else if (m->inuse && arglen == marglen && memcmp(arg, marg, arglen) == 0)
        {   // Recursive expansion; just leave in place

        }
        else
        {
            // Regular expansion
            if (macroWasUndefined)
            {
                // Macro was not defined, so this is an expansion of
                // DDOC_UNDEFINED_MACRO. We must prepend the name of
                // the original macro as the first argument.
                unsigned char* p = (unsigned char*)malloc(namelen + 1 + marglen);
                memcpy(p, name, namelen);
                p[namelen] = ',';
                memcpy(p + namelen + 1, marg, marglen);
                marg = p;
                marglen += namelen + 1;
            }
            else
            {
                marg = memdup(marg, marglen);
            }

            // printf("\tmacro %.*s(%.*s) = '%.*s'\n", m->namelen,
            //   m->name, marglen, marg, m->textlen, m->text);

            // Insert replacement text
            buf->spread(v + 1, 2 + m->textlen + 2);
            buf->data[v + 1] = 0xFF;
            buf->data[v + 2] = '{';
            memcpy(buf->data + v + 3, m->text, m->textlen);
            buf->data[v + 3 + m->textlen] = 0xFF;
            buf->data[v + 3 + m->textlen + 1] = '}';

            end += 2 + m->textlen + 2;

            // Scan replaced text for further expansion
            m->inuse++;
            size_t mend = v + 1 + 2+m->textlen+2;
            expand(buf, v + 1, &mend, marg, marglen);
            end += mend - (v + 1 + 2+m->textlen+2);
            m->inuse--;

            buf->remove(u, v + 1 - u);
            end -= v + 1 - u;
            u += mend - (v + 1);
            mem.free(marg);
            //printf("u = %d, end = %d\n", u, end);
            //printf("#%.*s#\n", end - u, &buf->data[u]);
            continue;
        }
        u++;
    }
    mem.free(arg);
    *pend = end;
    nest--;
}
