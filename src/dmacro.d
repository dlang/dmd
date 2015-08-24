// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.dmacro;

import core.stdc.ctype;
import core.stdc.string;
import ddmd.doc;
import ddmd.errors;
import ddmd.globals;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.utf;

struct Macro
{
private:
    Macro* next; // next in list
    const(char)* name; // macro name
    size_t namelen; // length of macro name
    const(char)* text; // macro replacement text
    size_t textlen; // length of replacement text
    int inuse; // macro is in use (don't expand)

    extern (D) this(const(char)* name, size_t namelen, const(char)* text, size_t textlen)
    {
        next = null;
        this.name = name;
        this.namelen = namelen;
        this.text = text;
        this.textlen = textlen;
        inuse = 0;
    }

    extern (C++) Macro* search(const(char)* name, size_t namelen)
    {
        Macro* table;
        //printf("Macro::search(%.*s)\n", namelen, name);
        for (table = &this; table; table = table.next)
        {
            if (table.namelen == namelen && memcmp(table.name, name, namelen) == 0)
            {
                //printf("\tfound %d\n", table->textlen);
                break;
            }
        }
        return table;
    }

public:
    extern (C++) static Macro* define(Macro** ptable, const(char)* name, size_t namelen, const(char)* text, size_t textlen)
    {
        //printf("Macro::define('%.*s' = '%.*s')\n", namelen, name, textlen, text);
        Macro* table;
        //assert(ptable);
        for (table = *ptable; table; table = table.next)
        {
            if (table.namelen == namelen && memcmp(table.name, name, namelen) == 0)
            {
                table.text = text;
                table.textlen = textlen;
                return table;
            }
        }
        table = new Macro(name, namelen, text, textlen);
        table.next = *ptable;
        *ptable = table;
        return table;
    }

    /*****************************************************
     * Expand macro in place in buf.
     * Only look at the text in buf from start to end.
     */
    extern (C++) void expand(OutBuffer* buf, size_t start, size_t* pend, const(char)* arg, size_t arglen)
    {
        version (none)
        {
            printf("Macro::expand(buf[%d..%d], arg = '%.*s')\n", start, *pend, arglen, arg);
            printf("Buf is: '%.*s'\n", *pend - start, buf.data + start);
        }
        // limit recursive expansion
        static __gshared int nest;
        static __gshared const(int) nestLimit = 1000;
        if (nest > nestLimit)
        {
            error(Loc(), "DDoc macro expansion limit exceeded; more than %d expansions.", nestLimit);
            return;
        }
        nest++;
        size_t end = *pend;
        assert(start <= end);
        assert(end <= buf.offset);
        /* First pass - replace $0
         */
        arg = memdup(arg, arglen);
        for (size_t u = start; u + 1 < end;)
        {
            char* p = cast(char*)buf.data; // buf->data is not loop invariant
            /* Look for $0, but not $$0, and replace it with arg.
             */
            if (p[u] == '$' && (isdigit(p[u + 1]) || p[u + 1] == '+'))
            {
                if (u > start && p[u - 1] == '$')
                {
                    // Don't expand $$0, but replace it with $0
                    buf.remove(u - 1, 1);
                    end--;
                    u += 1; // now u is one past the closing '1'
                    continue;
                }
                char c = p[u + 1];
                int n = (c == '+') ? -1 : c - '0';
                const(char)* marg;
                size_t marglen;
                if (n == 0)
                {
                    marg = arg;
                    marglen = arglen;
                }
                else
                    extractArgN(arg, arglen, &marg, &marglen, n);
                if (marglen == 0)
                {
                    // Just remove macro invocation
                    //printf("Replacing '$%c' with '%.*s'\n", p[u + 1], marglen, marg);
                    buf.remove(u, 2);
                    end -= 2;
                }
                else if (c == '+')
                {
                    // Replace '$+' with 'arg'
                    //printf("Replacing '$%c' with '%.*s'\n", p[u + 1], marglen, marg);
                    buf.remove(u, 2);
                    buf.insert(u, marg, marglen);
                    end += marglen - 2;
                    // Scan replaced text for further expansion
                    size_t mend = u + marglen;
                    expand(buf, u, &mend, null, 0);
                    end += mend - (u + marglen);
                    u = mend;
                }
                else
                {
                    // Replace '$1' with '\xFF{arg\xFF}'
                    //printf("Replacing '$%c' with '\xFF{%.*s\xFF}'\n", p[u + 1], marglen, marg);
                    buf.data[u] = 0xFF;
                    buf.data[u + 1] = '{';
                    buf.insert(u + 2, marg, marglen);
                    buf.insert(u + 2 + marglen, cast(const(char)*)"\xFF}", 2);
                    end += -2 + 2 + marglen + 2;
                    // Scan replaced text for further expansion
                    size_t mend = u + 2 + marglen;
                    expand(buf, u + 2, &mend, null, 0);
                    end += mend - (u + 2 + marglen);
                    u = mend;
                }
                //printf("u = %d, end = %d\n", u, end);
                //printf("#%.*s#\n", end, &buf->data[0]);
                continue;
            }
            u++;
        }
        /* Second pass - replace other macros
         */
        for (size_t u = start; u + 4 < end;)
        {
            char* p = cast(char*)buf.data; // buf->data is not loop invariant
            /* A valid start of macro expansion is $(c, where c is
             * an id start character, and not $$(c.
             */
            if (p[u] == '$' && p[u + 1] == '(' && isIdStart(p + u + 2))
            {
                //printf("\tfound macro start '%c'\n", p[u + 2]);
                char* name = p + u + 2;
                size_t namelen = 0;
                const(char)* marg;
                size_t marglen;
                size_t v;
                /* Scan forward to find end of macro name and
                 * beginning of macro argument (marg).
                 */
                for (v = u + 2; v < end; v += utfStride(p + v))
                {
                    if (!isIdTail(p + v))
                    {
                        // We've gone past the end of the macro name.
                        namelen = v - (u + 2);
                        break;
                    }
                }
                v += extractArgN(p + v, end - v, &marg, &marglen, 0);
                assert(v <= end);
                if (v < end)
                {
                    // v is on the closing ')'
                    if (u > start && p[u - 1] == '$')
                    {
                        // Don't expand $$(NAME), but replace it with $(NAME)
                        buf.remove(u - 1, 1);
                        end--;
                        u = v; // now u is one past the closing ')'
                        continue;
                    }
                    Macro* m = search(name, namelen);
                    if (!m)
                    {
                        static __gshared const(char)* undef = "DDOC_UNDEFINED_MACRO";
                        m = search(cast(const(char)*)undef, strlen(undef));
                        if (m)
                        {
                            // Macro was not defined, so this is an expansion of
                            //   DDOC_UNDEFINED_MACRO. Prepend macro name to args.
                            // marg = name[ ] ~ "," ~ marg[ ];
                            if (marglen)
                            {
                                char* q = cast(char*)mem.xmalloc(namelen + 1 + marglen);
                                assert(q);
                                memcpy(q, name, namelen);
                                q[namelen] = ',';
                                memcpy(q + namelen + 1, marg, marglen);
                                marg = q;
                                marglen += namelen + 1;
                            }
                            else
                            {
                                marg = name;
                                marglen = namelen;
                            }
                        }
                    }
                    if (m)
                    {
                        if (m.inuse && marglen == 0)
                        {
                            // Remove macro invocation
                            buf.remove(u, v + 1 - u);
                            end -= v + 1 - u;
                        }
                        else if (m.inuse && ((arglen == marglen && memcmp(arg, marg, arglen) == 0) || (arglen + 4 == marglen && marg[0] == 0xFF && marg[1] == '{' && memcmp(arg, marg + 2, arglen) == 0 && marg[marglen - 2] == 0xFF && marg[marglen - 1] == '}')))
                        {
                            /* Recursive expansion:
                             *   marg is same as arg (with blue paint added)
                             * Just leave in place.
                             */
                        }
                        else
                        {
                            //printf("\tmacro '%.*s'(%.*s) = '%.*s'\n", m->namelen, m->name, marglen, marg, m->textlen, m->text);
                            marg = memdup(marg, marglen);
                            // Insert replacement text
                            buf.spread(v + 1, 2 + m.textlen + 2);
                            buf.data[v + 1] = 0xFF;
                            buf.data[v + 2] = '{';
                            memcpy(buf.data + v + 3, m.text, m.textlen);
                            buf.data[v + 3 + m.textlen] = 0xFF;
                            buf.data[v + 3 + m.textlen + 1] = '}';
                            end += 2 + m.textlen + 2;
                            // Scan replaced text for further expansion
                            m.inuse++;
                            size_t mend = v + 1 + 2 + m.textlen + 2;
                            expand(buf, v + 1, &mend, marg, marglen);
                            end += mend - (v + 1 + 2 + m.textlen + 2);
                            m.inuse--;
                            buf.remove(u, v + 1 - u);
                            end -= v + 1 - u;
                            u += mend - (v + 1);
                            mem.xfree(cast(char*)marg);
                            //printf("u = %d, end = %d\n", u, end);
                            //printf("#%.*s#\n", end - u, &buf->data[u]);
                            continue;
                        }
                    }
                    else
                    {
                        // Replace $(NAME) with nothing
                        buf.remove(u, v + 1 - u);
                        end -= (v + 1 - u);
                        continue;
                    }
                }
            }
            u++;
        }
        mem.xfree(cast(char*)arg);
        *pend = end;
        nest--;
    }
}

extern (C++) char* memdup(const(char)* p, size_t len)
{
    return cast(char*)memcpy(mem.xmalloc(len), p, len);
}

/**********************************************************
 * Given buffer p[0..end], extract argument marg[0..marglen].
 * Params:
 *      n       0:      get entire argument
 *              1..9:   get nth argument
 *              -1:     get 2nd through end
 */
extern (C++) size_t extractArgN(const(char)* p, size_t end, const(char)** pmarg, size_t* pmarglen, int n)
{
    /* Scan forward for matching right parenthesis.
     * Nest parentheses.
     * Skip over "..." and '...' strings inside HTML tags.
     * Skip over <!-- ... --> comments.
     * Skip over previous macro insertions
     * Set marglen.
     */
    uint parens = 1;
    ubyte instring = 0;
    uint incomment = 0;
    uint intag = 0;
    uint inexp = 0;
    uint argn = 0;
    size_t v = 0;
Largstart:
    // Skip first space, if any, to find the start of the macro argument
    if (n != 1 && v < end && isspace(p[v]))
        v++;
    *pmarg = p + v;
    for (; v < end; v++)
    {
        char c = p[v];
        switch (c)
        {
        case ',':
            if (!inexp && !instring && !incomment && parens == 1)
            {
                argn++;
                if (argn == 1 && n == -1)
                {
                    v++;
                    goto Largstart;
                }
                if (argn == n)
                    break;
                if (argn + 1 == n)
                {
                    v++;
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
                if (v + 6 < end && p[v + 1] == '!' && p[v + 2] == '-' && p[v + 3] == '-')
                {
                    incomment = 1;
                    v += 3;
                }
                else if (v + 2 < end && isalpha(p[v + 1]))
                    intag = 1;
            }
            continue;
        case '>':
            if (!inexp)
                intag = 0;
            continue;
        case '-':
            if (!inexp && !instring && incomment && v + 2 < end && p[v + 1] == '-' && p[v + 2] == '>')
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
