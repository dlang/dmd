
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#ifndef DCHAR_H
#define DCHAR_H

#if __GNUC__ && !_WIN32
#include "gnuc.h"
#endif

#if _MSC_VER
    // Disable useless warnings about unreferenced functions
    #pragma warning (disable : 4514)
#endif

//#include "root.h"
typedef size_t hash_t;

#undef TEXT

// NOTE: All functions accepting pointer arguments must not be NULL

#if M_UNICODE

#include <string.h>
#include <wchar.h>

typedef wchar_t dchar;
#define TEXT(x)         L##x

#define Dchar_mbmax     1

struct Dchar
{
    static dchar *inc(dchar *p) { return p + 1; }
    static dchar *dec(dchar *pstart, dchar *p) { (void)pstart; return p - 1; }
    static int len(const dchar *p) { return wcslen(p); }
    static dchar get(dchar *p) { return *p; }
    static dchar getprev(dchar *pstart, dchar *p) { (void)pstart; return p[-1]; }
    static dchar *put(dchar *p, dchar c) { *p = c; return p + 1; }
    static int cmp(dchar *s1, dchar *s2)
    {
#if __DMC__
        if (!*s1 && !*s2)       // wcscmp is broken
            return 0;
#endif
        return wcscmp(s1, s2);
#if 0
        return (*s1 == *s2)
            ? wcscmp(s1, s2)
            : ((int)*s1 - (int)*s2);
#endif
    }
    static int memcmp(const dchar *s1, const dchar *s2, int nchars) { return ::memcmp(s1, s2, nchars * sizeof(dchar)); }
    static int isDigit(dchar c) { return '0' <= c && c <= '9'; }
    static int isAlpha(dchar c) { return iswalpha(c); }
    static int isUpper(dchar c) { return iswupper(c); }
    static int isLower(dchar c) { return iswlower(c); }
    static int isLocaleUpper(dchar c) { return isUpper(c); }
    static int isLocaleLower(dchar c) { return isLower(c); }
    static int toLower(dchar c) { return isUpper(c) ? towlower(c) : c; }
    static int toLower(dchar *p) { return toLower(*p); }
    static int toUpper(dchar c) { return isLower(c) ? towupper(c) : c; }
    static dchar *dup(dchar *p) { return ::_wcsdup(p); }        // BUG: out of memory?
    static dchar *dup(char *p);
    static dchar *chr(dchar *p, unsigned c) { return wcschr(p, (dchar)c); }
    static dchar *rchr(dchar *p, unsigned c) { return wcsrchr(p, (dchar)c); }
    static dchar *memchr(dchar *p, int c, int count);
    static dchar *cpy(dchar *s1, dchar *s2) { return wcscpy(s1, s2); }
    static dchar *str(dchar *s1, dchar *s2) { return wcsstr(s1, s2); }
    static hash_t calcHash(const dchar *str, size_t len);

    // Case insensitive versions
    static int icmp(dchar *s1, dchar *s2) { return wcsicmp(s1, s2); }
    static int memicmp(const dchar *s1, const dchar *s2, int nchars) { return ::wcsnicmp(s1, s2, nchars); }
    static hash_t icalcHash(const dchar *str, size_t len);
};

#elif MCBS

#include <limits.h>
#include <mbstring.h>

typedef char dchar;
#define TEXT(x)         x

#define Dchar_mbmax     MB_LEN_MAX

#elif UTF8

typedef char dchar;
#define TEXT(x)         x

#define Dchar_mbmax     6

struct Dchar
{
    static char mblen[256];

    static dchar *inc(dchar *p) { return p + mblen[*p & 0xFF]; }
    static dchar *dec(dchar *pstart, dchar *p);
    static int len(const dchar *p) { return strlen(p); }
    static int get(dchar *p);
    static int getprev(dchar *pstart, dchar *p)
        { return *dec(pstart, p) & 0xFF; }
    static dchar *put(dchar *p, unsigned c);
    static int cmp(dchar *s1, dchar *s2) { return strcmp(s1, s2); }
    static int memcmp(const dchar *s1, const dchar *s2, int nchars) { return ::memcmp(s1, s2, nchars); }
    static int isDigit(dchar c) { return '0' <= c && c <= '9'; }
    static int isAlpha(dchar c) { return c <= 0x7F ? isalpha(c) : 0; }
    static int isUpper(dchar c) { return c <= 0x7F ? isupper(c) : 0; }
    static int isLower(dchar c) { return c <= 0x7F ? islower(c) : 0; }
    static int isLocaleUpper(dchar c) { return isUpper(c); }
    static int isLocaleLower(dchar c) { return isLower(c); }
    static int toLower(dchar c) { return isUpper(c) ? tolower(c) : c; }
    static int toLower(dchar *p) { return toLower(*p); }
    static int toUpper(dchar c) { return isLower(c) ? toupper(c) : c; }
    static dchar *dup(dchar *p) { return ::strdup(p); } // BUG: out of memory?
    static dchar *chr(dchar *p, int c) { return strchr(p, c); }
    static dchar *rchr(dchar *p, int c) { return strrchr(p, c); }
    static dchar *memchr(dchar *p, int c, int count)
        { return (dchar *)::memchr(p, c, count); }
    static dchar *cpy(dchar *s1, dchar *s2) { return strcpy(s1, s2); }
    static dchar *str(dchar *s1, dchar *s2) { return strstr(s1, s2); }
    static hash_t calcHash(const dchar *str, size_t len);

    // Case insensitive versions
    static int icmp(dchar *s1, dchar *s2) { return _mbsicmp(s1, s2); }
    static int memicmp(const dchar *s1, const dchar *s2, int nchars) { return ::_mbsnicmp(s1, s2, nchars); }
};

#else

#include <string.h>

#ifndef GCC_SAFE_DMD
#include <ctype.h>
#endif

typedef char dchar;
#define TEXT(x)         x

#define Dchar_mbmax     1

struct Dchar
{
    static dchar *inc(dchar *p) { return p + 1; }
    static dchar *dec(dchar *pstart, dchar *p) { return p - 1; }
    static int len(const dchar *p) { return strlen(p); }
    static int get(dchar *p) { return *p & 0xFF; }
    static int getprev(dchar *pstart, dchar *p) { return p[-1] & 0xFF; }
    static dchar *put(dchar *p, unsigned c) { *p = c; return p + 1; }
    static int cmp(dchar *s1, dchar *s2) { return strcmp(s1, s2); }
    static int memcmp(const dchar *s1, const dchar *s2, int nchars) { return ::memcmp(s1, s2, nchars); }
    static int isDigit(dchar c) { return '0' <= c && c <= '9'; }
#ifndef GCC_SAFE_DMD
    static int isAlpha(dchar c) { return isalpha((unsigned char)c); }
    static int isUpper(dchar c) { return isupper((unsigned char)c); }
    static int isLower(dchar c) { return islower((unsigned char)c); }
    static int isLocaleUpper(dchar c) { return isupper((unsigned char)c); }
    static int isLocaleLower(dchar c) { return islower((unsigned char)c); }
    static int toLower(dchar c) { return isupper((unsigned char)c) ? tolower(c) : c; }
    static int toLower(dchar *p) { return toLower(*p); }
    static int toUpper(dchar c) { return islower((unsigned char)c) ? toupper(c) : c; }
    static dchar *dup(dchar *p) { return ::strdup(p); } // BUG: out of memory?
#endif
    static dchar *chr(dchar *p, int c) { return strchr(p, c); }
    static dchar *rchr(dchar *p, int c) { return strrchr(p, c); }
    static dchar *memchr(dchar *p, int c, int count)
        { return (dchar *)::memchr(p, c, count); }
    static dchar *cpy(dchar *s1, dchar *s2) { return strcpy(s1, s2); }
    static dchar *str(dchar *s1, dchar *s2) { return strstr(s1, s2); }
    static hash_t calcHash(const dchar *str, size_t len);

    // Case insensitive versions
#ifdef __GNUC__
    static int icmp(dchar *s1, dchar *s2) { return strcasecmp(s1, s2); }
#else
    static int icmp(dchar *s1, dchar *s2) { return stricmp(s1, s2); }
#endif
    static int memicmp(const dchar *s1, const dchar *s2, int nchars) { return ::memicmp(s1, s2, nchars); }
    static hash_t icalcHash(const dchar *str, size_t len);
};

#endif
#endif

