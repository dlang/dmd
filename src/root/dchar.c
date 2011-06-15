
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

#include "dchar.h"
#include "rmem.h"

#if M_UNICODE

// Converts a char string to Unicode

dchar *Dchar::dup(char *p)
{
    dchar *s;
    size_t len;

    if (!p)
        return NULL;
    len = strlen(p);
    s = (dchar *)mem.malloc((len + 1) * sizeof(dchar));
    for (unsigned i = 0; i < len; i++)
    {
        s[i] = (dchar)(p[i] & 0xFF);
    }
    s[len] = 0;
    return s;
}

dchar *Dchar::memchr(dchar *p, int c, int count)
{
    int u;

    for (u = 0; u < count; u++)
    {
        if (p[u] == c)
            return p + u;
    }
    return NULL;
}

#if _WIN32 && __DMC__
__declspec(naked)
unsigned Dchar::calcHash(const dchar *str, unsigned len)
{
    __asm
    {
        mov     ECX,4[ESP]
        mov     EDX,8[ESP]
        xor     EAX,EAX
        test    EDX,EDX
        je      L92

LC8:    cmp     EDX,1
        je      L98
        cmp     EDX,2
        je      LAE

        add     EAX,[ECX]
//      imul    EAX,EAX,025h
        lea     EAX,[EAX][EAX*8]
        add     ECX,4
        sub     EDX,2
        jmp     LC8

L98:    mov     DX,[ECX]
        and     EDX,0FFFFh
        add     EAX,EDX
        ret

LAE:    add     EAX,[ECX]
L92:    ret
    }
}
#else
hash_t Dchar::calcHash(const dchar *str, size_t len)
{
    unsigned hash = 0;

    for (;;)
    {
        switch (len)
        {
            case 0:
                return hash;

            case 1:
                hash += *(const uint16_t *)str;
                return hash;

            case 2:
                hash += *(const uint32_t *)str;
                return hash;

            default:
                hash += *(const uint32_t *)str;
                hash *= 37;
                str += 2;
                len -= 2;
                break;
        }
    }
}
#endif

hash_t Dchar::icalcHash(const dchar *str, size_t len)
{
    hash_t hash = 0;

    for (;;)
    {
        switch (len)
        {
            case 0:
                return hash;

            case 1:
                hash += *(const uint16_t *)str | 0x20;
                return hash;

            case 2:
                hash += *(const uint32_t *)str | 0x200020;
                return hash;

            default:
                hash += *(const uint32_t *)str | 0x200020;
                hash *= 37;
                str += 2;
                len -= 2;
                break;
        }
    }
}

#elif MCBS

hash_t Dchar::calcHash(const dchar *str, size_t len)
{
    hash_t hash = 0;

    while (1)
    {
        switch (len)
        {
            case 0:
                return hash;

            case 1:
                hash *= 37;
                hash += *(const uint8_t *)str;
                return hash;

            case 2:
                hash *= 37;
                hash += *(const uint16_t *)str;
                return hash;

            case 3:
                hash *= 37;
                hash += (*(const uint16_t *)str << 8) +
                        ((const uint8_t *)str)[2];
                return hash;

            default:
                hash *= 37;
                hash += *(const uint32_t *)str;
                str += 4;
                len -= 4;
                break;
        }
    }
}

#elif UTF8

// Specification is: http://anubis.dkuug.dk/JTC1/SC2/WG2/docs/n1335

char Dchar::mblen[256] =
{
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4,5,5,5,5,6,6,1,1,
};

dchar *Dchar::dec(dchar *pstart, dchar *p)
{
    while ((p[-1] & 0xC0) == 0x80)
        p--;
    return p;
}

int Dchar::get(dchar *p)
{
    unsigned c;
    unsigned char *q = (unsigned char *)p;

    c = q[0];
    switch (mblen[c])
    {
        case 2:
            c = ((c    - 0xC0) << 6) |
                 (q[1] - 0x80);
            break;

        case 3:
            c = ((c    - 0xE0) << 12) |
                ((q[1] - 0x80) <<  6) |
                 (q[2] - 0x80);
            break;

        case 4:
            c = ((c    - 0xF0) << 18) |
                ((q[1] - 0x80) << 12) |
                ((q[2] - 0x80) <<  6) |
                 (q[3] - 0x80);
            break;

        case 5:
            c = ((c    - 0xF8) << 24) |
                ((q[1] - 0x80) << 18) |
                ((q[2] - 0x80) << 12) |
                ((q[3] - 0x80) <<  6) |
                 (q[4] - 0x80);
            break;

        case 6:
            c = ((c    - 0xFC) << 30) |
                ((q[1] - 0x80) << 24) |
                ((q[2] - 0x80) << 18) |
                ((q[3] - 0x80) << 12) |
                ((q[4] - 0x80) <<  6) |
                 (q[5] - 0x80);
            break;
    }
    return c;
}

dchar *Dchar::put(dchar *p, unsigned c)
{
    if (c <= 0x7F)
    {
        *p++ = c;
    }
    else if (c <= 0x7FF)
    {
        p[0] = 0xC0 + (c >> 6);
        p[1] = 0x80 + (c & 0x3F);
        p += 2;
    }
    else if (c <= 0xFFFF)
    {
        p[0] = 0xE0 + (c >> 12);
        p[1] = 0x80 + ((c >> 6) & 0x3F);
        p[2] = 0x80 + (c & 0x3F);
        p += 3;
    }
    else if (c <= 0x1FFFFF)
    {
        p[0] = 0xF0 + (c >> 18);
        p[1] = 0x80 + ((c >> 12) & 0x3F);
        p[2] = 0x80 + ((c >> 6) & 0x3F);
        p[3] = 0x80 + (c & 0x3F);
        p += 4;
    }
    else if (c <= 0x3FFFFFF)
    {
        p[0] = 0xF8 + (c >> 24);
        p[1] = 0x80 + ((c >> 18) & 0x3F);
        p[2] = 0x80 + ((c >> 12) & 0x3F);
        p[3] = 0x80 + ((c >> 6) & 0x3F);
        p[4] = 0x80 + (c & 0x3F);
        p += 5;
    }
    else if (c <= 0x7FFFFFFF)
    {
        p[0] = 0xFC + (c >> 30);
        p[1] = 0x80 + ((c >> 24) & 0x3F);
        p[2] = 0x80 + ((c >> 18) & 0x3F);
        p[3] = 0x80 + ((c >> 12) & 0x3F);
        p[4] = 0x80 + ((c >> 6) & 0x3F);
        p[5] = 0x80 + (c & 0x3F);
        p += 6;
    }
    else
        assert(0);              // not a UCS-4 character
    return p;
}

hash_t Dchar::calcHash(const dchar *str, size_t len)
{
    hash_t hash = 0;

    while (1)
    {
        switch (len)
        {
            case 0:
                return hash;

            case 1:
                hash *= 37;
                hash += *(const uint8_t *)str;
                return hash;

            case 2:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += *(const uint16_t *)str;
#else
                hash += str[0] * 256 + str[1];
#endif
                return hash;

            case 3:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += (*(const uint16_t *)str << 8) +
                        ((const uint8_t *)str)[2];
#else
                hash += (str[0] * 256 + str[1]) * 256 + str[2];
#endif
                return hash;

            default:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += *(const uint32_t *)str;
#else
                hash += ((str[0] * 256 + str[1]) * 256 + str[2]) * 256 + str[3];
#endif

                str += 4;
                len -= 4;
                break;
        }
    }
}

#else // ascii

hash_t Dchar::calcHash(const dchar *str, size_t len)
{
    hash_t hash = 0;

    while (1)
    {
        switch (len)
        {
            case 0:
                return hash;

            case 1:
                hash *= 37;
                hash += *(const uint8_t *)str;
                return hash;

            case 2:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += *(const uint16_t *)str;
#else
                hash += str[0] * 256 + str[1];
#endif
                return hash;

            case 3:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += (*(const uint16_t *)str << 8) +
                        ((const uint8_t *)str)[2];
#else
                hash += (str[0] * 256 + str[1]) * 256 + str[2];
#endif
                return hash;

            default:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += *(const uint32_t *)str;
#else
                hash += ((str[0] * 256 + str[1]) * 256 + str[2]) * 256 + str[3];
#endif
                str += 4;
                len -= 4;
                break;
        }
    }
}

hash_t Dchar::icalcHash(const dchar *str, size_t len)
{
    hash_t hash = 0;

    while (1)
    {
        switch (len)
        {
            case 0:
                return hash;

            case 1:
                hash *= 37;
                hash += *(const uint8_t *)str | 0x20;
                return hash;

            case 2:
                hash *= 37;
                hash += *(const uint16_t *)str | 0x2020;
                return hash;

            case 3:
                hash *= 37;
                hash += ((*(const uint16_t *)str << 8) +
                         ((const uint8_t *)str)[2]) | 0x202020;
                return hash;

            default:
                hash *= 37;
                hash += *(const uint32_t *)str | 0x20202020;
                str += 4;
                len -= 4;
                break;
        }
    }
}

#endif

#if 0
#include <stdio.h>

void main()
{
    // Print out values to hardcode into Dchar::mblen[]
    int c;
    int s;

    for (c = 0; c < 256; c++)
    {
        s = 1;
        if (c >= 0xC0 && c <= 0xDF)
            s = 2;
        if (c >= 0xE0 && c <= 0xEF)
            s = 3;
        if (c >= 0xF0 && c <= 0xF7)
            s = 4;
        if (c >= 0xF8 && c <= 0xFB)
            s = 5;
        if (c >= 0xFC && c <= 0xFD)
            s = 6;

        printf("%d", s);
        if ((c & 15) == 15)
            printf(",\n");
        else
            printf(",");
    }
}
#endif
