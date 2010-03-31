
// lstring.h
// length-prefixed strings

// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef LSTRING_H
#define LSTRING_H 1

#include "dchar.h"

struct Lstring
{
    unsigned length;

    // Disable warning about nonstandard extension
    #pragma warning (disable : 4200)
    dchar string[];

    static Lstring zero;        // 0 length string

    // No constructors because we want to be able to statically
    // initialize Lstring's, and Lstrings are of variable size.

    #if M_UNICODE
    #define LSTRING(p,length) { length, L##p }
    #else
    #define LSTRING(p,length) { length, p }
    #endif

#if __GNUC__
    #define LSTRING_EMPTY() { 0 }
#else
    #define LSTRING_EMPTY() LSTRING("", 0)
#endif

    static Lstring *ctor(const dchar *p) { return ctor(p, Dchar::len(p)); }
    static Lstring *ctor(const dchar *p, unsigned length);
    static unsigned size(unsigned length) { return sizeof(Lstring) + (length + 1) * sizeof(dchar); }
    static Lstring *alloc(unsigned length);
    Lstring *clone();

    unsigned len() { return length; }

    dchar *toDchars() { return string; }

    hash_t hash() { return Dchar::calcHash(string, length); }
    hash_t ihash() { return Dchar::icalcHash(string, length); }

    static int cmp(const Lstring *s1, const Lstring *s2)
    {
        int c = s2->length - s1->length;
        return c ? c : Dchar::memcmp(s1->string, s2->string, s1->length);
    }

    static int icmp(const Lstring *s1, const Lstring *s2)
    {
        int c = s2->length - s1->length;
        return c ? c : Dchar::memicmp(s1->string, s2->string, s1->length);
    }

    Lstring *append(const Lstring *s);
    Lstring *substring(int start, int end);
};

#endif
