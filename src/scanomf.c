
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/scanomf.c
 */

/* Implements scanning an object module for names to go in the library table of contents.
 * The object module format is OMF.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#include "root.h"
#include "mars.h"

#define LOG 0

/**************************
 * Record types:
 */

#define RHEADR  0x6E
#define REGINT  0x70
#define REDATA  0x72
#define RIDATA  0x74
#define OVLDEF  0x76
#define ENDREC  0x78
#define BLKDEF  0x7A
#define BLKEND  0x7C
#define DEBSYM  0x7E
#define THEADR  0x80
#define LHEADR  0x82
#define PEDATA  0x84
#define PIDATA  0x86
#define COMENT  0x88
#define MODEND  0x8A
#define M386END 0x8B    /* 32 bit module end record */
#define EXTDEF  0x8C
#define TYPDEF  0x8E
#define PUBDEF  0x90
#define PUB386  0x91
#define LOCSYM  0x92
#define LINNUM  0x94
#define LNAMES  0x96
#define SEGDEF  0x98
#define GRPDEF  0x9A
#define FIXUPP  0x9C
/*#define (none)        0x9E    */
#define LEDATA  0xA0
#define LIDATA  0xA2
#define LIBHED  0xA4
#define LIBNAM  0xA6
#define LIBLOC  0xA8
#define LIBDIC  0xAA
#define COMDEF  0xB0
#define LEXTDEF 0xB4
#define LPUBDEF 0xB6
#define LCOMDEF 0xB8
#define CEXTDEF 0xBC
#define COMDAT  0xC2
#define LINSYM  0xC4
#define ALIAS   0xC6
#define LLNAMES 0xCA

#define LIBIDMAX (512 - 0x25 - 3 - 4)   // max size that will fit in dictionary

void parseName(unsigned char **pp, char *name)
{
    unsigned char *p = *pp;
    unsigned len = *p++;
    if (len == 0xFF && *p == 0)  // if long name
    {
        len = p[1] & 0xFF;
        len |= (unsigned)p[2] << 8;
        p += 3;
        assert(len <= LIBIDMAX);
    }
    memcpy(name, p, len);
    name[len] = 0;
    *pp = p + len;
}

static unsigned short parseIdx(unsigned char **pp)
{
    unsigned char *p = *pp;
    unsigned char c = *p++;

    unsigned short idx = (0x80 & c) ? ((0x7F & c) << 8) + *p++ : c;
    *pp = p;
    return idx;
}

// skip numeric field of a data type of a COMDEF record
static void skipNumericField(unsigned char **pp)
{
    unsigned char *p = *pp;
    unsigned char c = *p++;
    if (c == 0x81)
        p += 2;
    else if (c == 0x84)
        p += 3;
    else if (c == 0x88)
        p += 4;
    else
        assert(c <= 0x80);
    *pp = p;
}

// skip data type of a COMDEF record
static void skipDataType(unsigned char **pp)
{
    unsigned char *p = *pp;
    unsigned char c = *p++;

    if (c == 0x61)
    {
        // FAR data
        skipNumericField(&p);
        skipNumericField(&p);
    }
    else if (c == 0x62)
    {
        // NEAR data
        skipNumericField(&p);
    }
    else
    {
        assert(1 <= c && c <= 0x5f); // Borland segment indices
    }
    *pp = p;
}



/*****************************************
 * Reads an object module from base[0..buflen] and passes the names
 * of any exported symbols to (*pAddSymbol)().
 * Input:
 *      pctx            context pointer, pass to *pAddSymbol
 *      pAddSymbol      function to pass the names to
 *      base[0..buflen] contains contents of object module
 *      module_name     name of the object module (used for error messages)
 *      loc             location to use for error printing
 */

void scanOmfObjModule(void* pctx, void (*pAddSymbol)(void* pctx, const char* name, int pickAny),
    void *base, size_t buflen, const char *module_name, Loc loc)
{
#if LOG
    printf("scanMSCoffObjModule(%s)\n", module_name);
#endif
    int easyomf;
    unsigned char result = 0;
    char name[LIBIDMAX + 1];

    Strings names;
    names.push(NULL);           // don't use index 0

    easyomf = 0;                                // assume not EASY-OMF
    unsigned char *pend = (unsigned char *)base + buflen;

    unsigned char *pnext;
    for (unsigned char *p = (unsigned char *)base; 1; p = pnext)
    {
        assert(p < pend);
        unsigned char recTyp = *p++;
        unsigned short recLen = *(unsigned short *)p;
        p += 2;
        pnext = p + recLen;
        recLen--;                               // forget the checksum

        switch (recTyp)
        {
            case LNAMES:
            case LLNAMES:
                while (p + 1 < pnext)
                {
                    parseName(&p, name);
                    names.push(strdup(name));
                }
                break;

            case PUBDEF:
                if (easyomf)
                    recTyp = PUB386;            // convert to MS format
            case PUB386:
                if (!(parseIdx(&p) | parseIdx(&p)))
                    p += 2;                     // skip seg, grp, frame
                while (p + 1 < pnext)
                {
                    parseName(&p, name);
                    p += (recTyp == PUBDEF) ? 2 : 4;    // skip offset
                    parseIdx(&p);                               // skip type index
                    (*pAddSymbol)(pctx, name, 0);
                }
                break;

            case COMDAT:
                if (easyomf)
                    recTyp = COMDAT+1;          // convert to MS format
            case COMDAT+1:
            {
                int pickAny = 0;

                if (*p++ & 5)           // if continuation or local comdat
                    break;

                unsigned char attr = *p++;
                if (attr & 0xF0)        // attr: if multiple instances allowed
                    pickAny = 1;
                p++;                    // align

                p += 2;                 // enum data offset
                if (recTyp == COMDAT+1)
                    p += 2;                     // enum data offset

                parseIdx(&p);                   // type index

                if ((attr & 0x0F) == 0) // if explicit allocation
                {   parseIdx(&p);               // base group
                    parseIdx(&p);               // base segment
                }

                unsigned idx = parseIdx(&p);    // public name index
                if( idx == 0 || idx >= names.dim)
                {
                    //debug(printf("[s] name idx=%d, uCntNames=%d\n", idx, uCntNames));
                    error(loc, "corrupt COMDAT");
                    return;
                }

                //printf("[s] name='%s'\n",name);
                (*pAddSymbol)(pctx, names[idx],pickAny);
                break;
            }
            case COMDEF:
            {
                while (p + 1 < pnext)
                {
                    parseName(&p, name);
                    parseIdx(&p);               // type index
                    skipDataType(&p);           // data type
                    (*pAddSymbol)(pctx, name, 1);
                }
                break;
            }
            case ALIAS:
                while (p + 1 < pnext)
                {
                    parseName(&p, name);
                    (*pAddSymbol)(pctx, name, 0);
                    parseName(&p, name);
                }
                break;

            case MODEND:
            case M386END:
                result = 1;
                goto Ret;

            case COMENT:
                // Recognize Phar Lap EASY-OMF format
                {   static unsigned char omfstr[7] =
                        {0x80,0xAA,'8','0','3','8','6'};

                    if (recLen == sizeof(omfstr))
                    {
                        for (unsigned i = 0; i < sizeof(omfstr); i++)
                            if (*p++ != omfstr[i])
                                goto L1;
                        easyomf = 1;
                        break;
                    L1: ;
                    }
                }
                // Recognize .IMPDEF Import Definition Records
                {   static unsigned char omfstr[] =
                        {0,0xA0,1};

                    if (recLen >= 7)
                    {
                        p++;
                        for (unsigned i = 1; i < sizeof(omfstr); i++)
                            if (*p++ != omfstr[i])
                                goto L2;
                        p++;            // skip OrdFlag field
                        parseName(&p, name);
                        (*pAddSymbol)(pctx, name, 0);
                        break;
                    L2: ;
                    }
                }
                break;

            default:
                // ignore
                ;
        }
    }
Ret:
    for (size_t u = 1; u < names.dim; u++)
        free((void *)names[u]);
}

/*************************************************
 * Scan a block of memory buf[0..buflen], pulling out each
 * OMF object module in it and sending the info in it to (*pAddObjModule).
 * Returns:
 *      true for corrupt OMF data
 */

bool scanOmfLib(void *pctx,
        void (*pAddObjModule)(void* pctx, char* name, void *base, size_t length),
        void *buf, size_t buflen,
        unsigned pagesize)
{
    /* Split up the buffer buf[0..buflen] into multiple object modules,
     * each aligned on a pagesize boundary.
     */

    bool first_module = true;
    unsigned char *base = NULL;
    char name[LIBIDMAX + 1];

    unsigned char *p = (unsigned char *)buf;
    unsigned char *pend = p + buflen;
    unsigned char *pnext;
    for (; p < pend; p = pnext)         // for each OMF record
    {
        if (p + 3 >= pend)
            return true;                // corrupt
        unsigned char recTyp = *p;
        unsigned short recLen = *(unsigned short *)(p + 1);
        pnext = p + 3 + recLen;
        if (pnext > pend)
            return true;                // corrupt
        recLen--;                       // forget the checksum

        switch (recTyp)
        {
            case LHEADR :
            case THEADR :
                if (!base)
                {
                    base = p;
                    p += 3;
                    parseName(&p, name);
                    if (name[0] == 'C' && name[1] == 0) // old C compilers did this
                        base = pnext;                   // skip past THEADR
                }
                break;

            case MODEND :
            case M386END:
            {
                if (base)
                {
                    (*pAddObjModule)(pctx, name, base, pnext - base);
                    base = NULL;
                }
                // Round up to next page
                unsigned t = pnext - (unsigned char *)buf;
                t = (t + pagesize - 1) & ~(unsigned)(pagesize - 1);
                pnext = (unsigned char *)buf + t;
                break;
            }
            default:
                // ignore
                ;
        }
    }

    return (base != NULL);          // missing MODEND record
}


unsigned OMFObjSize(const void *base, unsigned length, const char *name)
{
    unsigned char c = *(const unsigned char *)base;
    if (c != THEADR && c != LHEADR)
    {   size_t len = strlen(name);
        assert(len <= LIBIDMAX);
        length += len + 5;
    }
    return length;
}

void writeOMFObj(OutBuffer *buf, const void *base, unsigned length, const char *name)
{
    unsigned char c = *(const unsigned char *)base;
    if (c != THEADR && c != LHEADR)
    {   size_t len = strlen(name);
        assert(len <= LIBIDMAX);
        unsigned char header[4 + LIBIDMAX + 1];

        header [0] = THEADR;
        header [1] = 2 + len;
        header [2] = 0;
        header [3] = len;
        assert(len <= 0xFF - 2);

        memcpy(4 + header, name, len);

        // Compute and store record checksum
        unsigned n = len + 4;
        unsigned char checksum = 0;
        unsigned char *p = header;
        while (n--)
        {   checksum -= *p;
            p++;
        }
        *p = checksum;

        buf->write(header, len + 5);
    }
    buf->write(base, length);
}
