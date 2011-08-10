
/*
 * Copyright (c) 1986-1995 by Symantec
 * Copyright (c) 2000-2011 by Digital Mars
 * All Rights Reserved
 * http://www.digitalmars.com
 * Written by Walter Bright
 *
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

// Compiler implementation of the D programming language

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "rmem.h"
#include "root.h"
#include "stringtable.h"

#include "mars.h"
#include "lib.h"

#define LOG 0

Library::Library()
{
    libfile = NULL;
}

/***********************************
 * Set the library file name based on the output directory
 * and the filename.
 * Add default library file name extension.
 */

void Library::setFilename(char *dir, char *filename)
{
    char *arg = filename;
    if (!arg || !*arg)
    {   // Generate lib file name from first obj name
        char *n = global.params.objfiles->tdata()[0];

        n = FileName::name(n);
        FileName *fn = FileName::forceExt(n, global.lib_ext);
        arg = fn->toChars();
    }
    if (!FileName::absolute(arg))
        arg = FileName::combine(dir, arg);
    FileName *libfilename = FileName::defaultExt(arg, global.lib_ext);

    libfile = new File(libfilename);
}

void Library::write()
{
    if (global.params.verbose)
        printf("library   %s\n", libfile->name->toChars());

    OutBuffer libbuf;
    WriteLibToBuffer(&libbuf);

    // Transfer image to file
    libfile->setbuffer(libbuf.data, libbuf.offset);
    libbuf.extractData();


    char *p = FileName::path(libfile->name->toChars());
    FileName::ensurePathExists(p);
    //mem.free(p);

    libfile->writev();
}

/*****************************************************************************/

void Library::addLibrary(void *buf, size_t buflen)
{
    addObject(NULL, buf, buflen);
}


/*****************************************************************************/
/*****************************************************************************/

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


struct ObjModule
{
    unsigned char *base;        // where are we holding it in memory
    unsigned length;            // in bytes
    unsigned short page;        // page module starts in output file
    unsigned char flags;
#define MFgentheadr     1       // generate THEADR record
#define MFtheadr        2       // module name comes from THEADR record
    char *name;                 // module name
};

static void parseName(unsigned char **pp, char *name)
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

void Library::addSymbol(ObjModule *om, char *name, int pickAny)
{
#if LOG
    printf("Library::addSymbol(%s, %s, %d)\n", om->name, name, pickAny);
#endif
    StringValue *s = tab.insert(name, strlen(name));
    if (!s)
    {   // already in table
        if (!pickAny)
        {   s = tab.lookup(name, strlen(name));
            assert(s);
            ObjSymbol *os = (ObjSymbol *)s->ptrvalue;
            error("multiple definition of %s: %s and %s: %s",
                om->name, name, os->om->name, os->name);
        }
    }
    else
    {
        ObjSymbol *os = new ObjSymbol();
        os->name = strdup(name);
        os->om = om;
        s->ptrvalue = (void *)os;

        objsymbols.push(os);
    }
}

/************************************
 * Scan single object module for dictionary symbols.
 * Send those symbols to Library::addSymbol().
 */

void Library::scanObjModule(ObjModule *om)
{   int easyomf;
    unsigned u;
    unsigned char result = 0;
    char name[LIBIDMAX + 1];

    Strings names;
    names.push(NULL);           // don't use index 0

    assert(om);
    easyomf = 0;                                // assume not EASY-OMF
    unsigned char *pend = om->base + om->length;

    unsigned char *pnext;
    for (unsigned char *p = om->base; 1; p = pnext)
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
                    addSymbol(om, name);
                }
                break;

            case COMDAT:
                if (easyomf)
                    recTyp = COMDAT+1;          // convert to MS format
            case COMDAT+1:
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
                    error("corrupt COMDAT");
                    return;
                }

                //printf("[s] name='%s'\n",name);
                addSymbol(om, names.tdata()[idx],pickAny);
                break;

            case ALIAS:
                while (p + 1 < pnext)
                {
                    parseName(&p, name);
                    addSymbol(om, name);
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
                        addSymbol(om, name);
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
    for (u = 1; u < names.dim; u++)
        free(names.tdata()[u]);
}

/***************************************
 * Add object module or library to the library.
 * Examine the buffer to see which it is.
 * If the buffer is NULL, use module_name as the file name
 * and load the file.
 */

void Library::addObject(const char *module_name, void *buf, size_t buflen)
{
#if LOG
    printf("Library::addObject(%s)\n", module_name ? module_name : "");
#endif
    if (!buf)
    {   assert(module_name);
        FileName f((char *)module_name, 0);
        File file(&f);
        file.readv();
        buf = file.buffer;
        buflen = file.len;
        file.ref = 1;
    }

    unsigned g_page_size;
    unsigned char *pstart = (unsigned char *)buf;
    int islibrary = 0;

    /* See if it's an OMF library.
     * Don't go by file extension.
     */

    #pragma pack(1)
    struct LibHeader
    {
        unsigned char       recTyp;      // 0xF0
        unsigned short      pagesize;
        unsigned long       lSymSeek;
        unsigned short      ndicpages;
        unsigned char       flags;
    };
    #pragma pack()

    /* Determine if it is an OMF library, an OMF object module,
     * or something else.
     */
    if (buflen < sizeof(LibHeader))
    {
      Lcorrupt:
        error("corrupt object module");
    }
    LibHeader *lh = (LibHeader *)buf;
    if (lh->recTyp == 0xF0)
    {   /* OMF library
         * The modules are all at buf[g_page_size .. lh->lSymSeek]
         */
        islibrary = 1;
        g_page_size = lh->pagesize + 3;
        buf = (void *)(pstart + g_page_size);
        if (lh->lSymSeek > buflen ||
            g_page_size > buflen)
            goto Lcorrupt;
        buflen = lh->lSymSeek - g_page_size;
    }
    else if (lh->recTyp == '!' && memcmp(lh, "!<arch>\n", 8) == 0)
    {
        error("COFF libraries not supported");
        return;
    }
    else
    {   // Not a library, assume OMF object module
        g_page_size = 16;
    }

    /* Split up the buffer buf[0..buflen] into multiple object modules,
     * each aligned on a g_page_size boundary.
     */

    ObjModule *om = NULL;
    int first_module    = 1;

    unsigned char *p = (unsigned char *)buf;
    unsigned char *pend = p + buflen;
    unsigned char *pnext;
    for (; p < pend; p = pnext)         // for each OMF record
    {
        if (p + 3 >= pend)
            goto Lcorrupt;
        unsigned char recTyp = *p;
        unsigned short recLen = *(unsigned short *)(p + 1);
        pnext = p + 3 + recLen;
        if (pnext > pend)
            goto Lcorrupt;
        recLen--;                          /* forget the checksum */

        switch (recTyp)
        {
            case LHEADR :
            case THEADR :
                if (!om)
                {   char name[LIBIDMAX + 1];
                    om = new ObjModule();
                    om->flags = 0;
                    om->base = p;
                    p += 3;
                    parseName(&p, name);
                    if (first_module && module_name && !islibrary)
                    {   // Remove path and extension
                        om->name = strdup(FileName::name(module_name));
                        char *ext = FileName::ext(om->name);
                        if (ext)
                            ext[-1] = 0;
                    }
                    else
                    {   /* Use THEADR name as module name,
                         * removing path and extension.
                         */
                        om->name = strdup(FileName::name(name));
                        char *ext = FileName::ext(om->name);
                        if (ext)
                            ext[-1] = 0;

                        om->flags |= MFtheadr;
                    }
                    if (strcmp(name, "C") == 0)    // old C compilers did this
                    {   om->flags |= MFgentheadr;  // generate our own THEADR
                        om->base = pnext;          // skip past THEADR
                    }
                    objmodules.push(om);
                    first_module = 0;
                }
                break;

            case MODEND :
            case M386END:
                if (om)
                {   om->page = (om->base - pstart) / g_page_size;
                    om->length = pnext - om->base;
                    om = NULL;
                }
                // Round up to next page
                unsigned t = pnext - pstart;
                t = (t + g_page_size - 1) & ~(unsigned)(g_page_size - 1);
                pnext = pstart + t;
                break;

            default:
                // ignore
                ;
        }
    }

    if (om)
        goto Lcorrupt;          // missing MODEND record
}


/*****************************************************************************/
/*****************************************************************************/

typedef int (__cdecl * cmpfunc_t)(const void *,const void *);

extern "C" int NameCompare(ObjSymbol **p1, ObjSymbol **p2)
{
    return strcmp((*p1)->name, (*p2)->name);
}

#define HASHMOD     0x25
#define BUCKETPAGE  512
#define BUCKETSIZE  (BUCKETPAGE - HASHMOD - 1)


/***********************************
 * Calculates number of pages needed for dictionary
 * Returns:
 *      number of pages
 */

unsigned short Library::numDictPages(unsigned padding)
{
    unsigned short      ndicpages;
    unsigned short      bucksForHash;
    unsigned short      bucksForSize;
    unsigned symSize = 0;

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *s = objsymbols.tdata()[i];

        symSize += ( strlen(s->name) + 4 ) & ~1;
    }

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];

        size_t len = strlen(om->name);
        if (len > 0xFF)
            len += 2;                   // Digital Mars long name extension
        symSize += ( len + 4 + 1 ) & ~1;
    }

    bucksForHash = (objsymbols.dim + objmodules.dim + HASHMOD - 3) /
                (HASHMOD - 2);
    bucksForSize = (symSize + BUCKETSIZE - padding - padding - 1) /
                (BUCKETSIZE - padding);

    ndicpages = (bucksForHash > bucksForSize ) ? bucksForHash : bucksForSize;
    //printf("ndicpages = %u\n",ndicpages);

    // Find prime number greater than ndicpages
    static unsigned primes[] =
    { 1,2,3,5,7,11,13,17,19,23,29,31,37,41,43,
      47,53,59,61,67,71,73,79,83,89,97,101,103,
      107,109,113,127,131,137,139,149,151,157,
      163,167,173,179,181,191,193,197,199,211,
      223,227,229,233,239,241,251,257,263,269,
      271,277,281,283,293,307,311,313,317,331,
      337,347,349,353,359,367,373,379,383,389,
      397,401,409,419,421,431,433,439,443,449,
      457,461,463,467,479,487,491,499,503,509,
      //521,523,541,547,
      0
    };

    for (size_t i = 0; 1; i++)
    {
        if ( primes[i] == 0 )
        {   // Quick and easy way is out.
            // Now try and find first prime number > ndicpages
            unsigned prime;

            for (prime = (ndicpages + 1) | 1; 1; prime += 2)
            {   // Determine if prime is prime
                for (unsigned u = 3; u < prime / 2; u += 2)
                {
                    if ((prime / u) * u == prime)
                        goto L1;
                }
                break;

            L1: ;
            }
            ndicpages = prime;
            break;
        }

        if (primes[i] > ndicpages)
        {
            ndicpages = primes[i];
            break;
        }
    }

    return ndicpages;
}


/*******************************************
 * Write a single entry into dictionary.
 * Returns:
 *      0       failure
 */

static int EnterDict( unsigned char *bucketsP, unsigned short ndicpages, unsigned char *entry, unsigned entrylen )
{
    unsigned short      uStartIndex;
    unsigned short      uStep;
    unsigned short      uStartPage;
    unsigned short      uPageStep;
    unsigned short      uIndex;
    unsigned short      uPage;
    unsigned short      n;
    unsigned            u;
    unsigned            nbytes;
    unsigned char       *aP;
    unsigned char       *zP;

    aP = entry;
    zP = aP + entrylen;         // point at last char in identifier

    uStartPage  = 0;
    uPageStep   = 0;
    uStartIndex = 0;
    uStep       = 0;

    u = entrylen;
    while ( u-- )
    {
        uStartPage  = _rotl( uStartPage,  2 ) ^ ( *aP   | 0x20 );
        uStep       = _rotr( uStep,       2 ) ^ ( *aP++ | 0x20 );
        uStartIndex = _rotr( uStartIndex, 2 ) ^ ( *zP   | 0x20 );
        uPageStep   = _rotl( uPageStep,   2 ) ^ ( *zP-- | 0x20 );
    }

    uStartPage %= ndicpages;
    uPageStep  %= ndicpages;
    if ( uPageStep == 0 )
        uPageStep++;
    uStartIndex %= HASHMOD;
    uStep       %= HASHMOD;
    if ( uStep == 0 )
        uStep++;

    uPage = uStartPage;
    uIndex = uStartIndex;

    // number of bytes in entry
    nbytes = 1 + entrylen + 2;
    if (entrylen > 255)
        nbytes += 2;

    while (1)
    {
        aP = &bucketsP[uPage * BUCKETPAGE];
        uStartIndex = uIndex;
        while (1)
        {
            if ( 0 == aP[ uIndex ] )
            {
                // n = next available position in this page
                n = aP[ HASHMOD ] << 1;
                assert(n > HASHMOD);

                // if off end of this page
                if (n + nbytes > BUCKETPAGE )
                {   aP[ HASHMOD ] = 0xFF;
                    break;                      // next page
                }
                else
                {
                    aP[ uIndex ] = n >> 1;
                    memcpy( (aP + n), entry, nbytes );
                    aP[ HASHMOD ] += (nbytes + 1) >> 1;
                    if (aP[HASHMOD] == 0)
                        aP[HASHMOD] = 0xFF;
                    return 1;
                }
            }
            uIndex += uStep;
            uIndex %= 0x25;
            /*if (uIndex > 0x25)
                uIndex -= 0x25;*/
            if( uIndex == uStartIndex )
                break;
        }
        uPage += uPageStep;
        if (uPage >= ndicpages)
            uPage -= ndicpages;
        if( uPage == uStartPage )
            break;
    }

    return 0;
}

/*******************************************
 * Write the module and symbol names to the dictionary.
 * Returns:
 *      0       failure
 */

int Library::FillDict(unsigned char *bucketsP, unsigned short ndicpages)
{
    unsigned char entry[4 + LIBIDMAX + 2 + 1];

    //printf("FillDict()\n");

    // Add each of the module names
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];

        unsigned short n = strlen( om->name );
        if (n > 255)
        {   entry[0] = 0xFF;
            entry[1] = 0;
            *(unsigned short *)(entry + 2) = n + 1;
            memcpy(entry + 4, om->name, n);
            n += 3;
        }
        else
        {   entry[ 0 ] = 1 + n;
            memcpy(entry + 1, om->name, n );
        }
        entry[ n + 1 ] = '!';
        *((unsigned short *)( n + 2 + entry )) = om->page;
        if ( n & 1 )
            entry[ n + 2 + 2 ] = 0;
        if ( !EnterDict( bucketsP, ndicpages, entry, n + 1 ) )
            return 0;
    }

    // Sort the symbols
    qsort( objsymbols.tdata(), objsymbols.dim, 4, (cmpfunc_t)NameCompare );

    // Add each of the symbols
    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols.tdata()[i];

        unsigned short n = strlen( os->name );
        if (n > 255)
        {   entry[0] = 0xFF;
            entry[1] = 0;
            *(unsigned short *)(entry + 2) = n;
            memcpy(entry + 4, os->name, n);
            n += 3;
        }
        else
        {   entry[ 0 ] = n;
            memcpy( entry + 1, os->name, n );
        }
        *((unsigned short *)( n + 1 + entry )) = os->om->page;
        if ( (n & 1) == 0 )
            entry[ n + 3] = 0;
        if ( !EnterDict( bucketsP, ndicpages, entry, n ) )
        {
            return 0;
        }
    }
    return 1;
}


/**********************************************
 * Create and write library to libbuf.
 * The library consists of:
 *      library header
 *      object modules...
 *      dictionary header
 *      dictionary pages...
 */

void Library::WriteLibToBuffer(OutBuffer *libbuf)
{
    /* Scan each of the object modules for symbols
     * to go into the dictionary
     */
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];

        scanObjModule(om);
    }

    unsigned g_page_size = 16;

    /* Calculate page size so that the number of pages
     * fits in 16 bits. This is because object modules
     * are indexed by page number, stored as an unsigned short.
     */
    while (1)
    {
      Lagain:
#if LOG
        printf("g_page_size = %d\n", g_page_size);
#endif
        unsigned offset = g_page_size;

        for (size_t i = 0; i < objmodules.dim; i++)
        {   ObjModule *om = objmodules.tdata()[i];

            unsigned page = offset / g_page_size;
            if (page > 0xFFFF)
            {   // Page size is too small, double it and try again
                g_page_size *= 2;
                goto Lagain;
            }

            // Write out the object module m
            if (om->flags & MFgentheadr)                // if generate THEADR record
            {
                size_t size = strlen(om->name);
                assert(size <= LIBIDMAX);

                offset += size + 5;
                //offset += om->length - (size + 5);
                offset += om->length;
            }
            else
                offset += om->length;

            // Round the size of the file up to the next page size
            // by filling with 0s
            unsigned n = (g_page_size - 1) & offset;
            if (n)
                offset += g_page_size - n;
        }
        break;
    }


    /* Leave one page of 0s at start as a dummy library header.
     * Fill it in later with the real data.
     */
    libbuf->fill0(g_page_size);

    /* Write each object module into the library
     */
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];

        unsigned page = libbuf->offset / g_page_size;
        assert(page <= 0xFFFF);
        om->page = page;

        // Write out the object module om
        if (om->flags & MFgentheadr)            // if generate THEADR record
        {
            unsigned size = strlen(om->name);
            unsigned char header[4 + LIBIDMAX + 1];

            header [0] = THEADR;
            header [1] = 2 + size;
            header [2] = 0;
            header [3] = size;
            assert(size <= 0xFF - 2);

            memcpy(4 + header, om->name, size);

            // Compute and store record checksum
            unsigned n = size + 4;
            unsigned char checksum = 0;
            unsigned char *p = header;
            while (n--)
            {   checksum -= *p;
                p++;
            }
            *p = checksum;

            libbuf->write(header, size + 5);
            //libbuf->write(om->base, om->length - (size + 5));
            libbuf->write(om->base, om->length);
        }
        else
            libbuf->write(om->base, om->length);

        // Round the size of the file up to the next page size
        // by filling with 0s
        unsigned n = (g_page_size - 1) & libbuf->offset;
        if (n)
            libbuf->fill0(g_page_size - n);
    }

    // File offset of start of dictionary
    unsigned offset = libbuf->offset;

    // Write dictionary header, then round it to a BUCKETPAGE boundary
    unsigned short size = (BUCKETPAGE - ((short)offset + 3)) & (BUCKETPAGE - 1);
    libbuf->writeByte(0xF1);
    libbuf->writeword(size);
    libbuf->fill0(size);

    // Create dictionary
    unsigned char *bucketsP = NULL;
    unsigned short ndicpages;
    unsigned short padding = 32;
    for (;;)
    {
        ndicpages = numDictPages(padding);

#if LOG
        printf("ndicpages = %d\n", ndicpages);
#endif
        // Allocate dictionary
        if (bucketsP)
            bucketsP = (unsigned char *)realloc(bucketsP, ndicpages * BUCKETPAGE);
        else
            bucketsP = (unsigned char *)malloc(ndicpages * BUCKETPAGE);
        assert(bucketsP);
        memset(bucketsP, 0, ndicpages * BUCKETPAGE);
        for (unsigned u = 0; u < ndicpages; u++)
        {
            // 'next available' slot
            bucketsP[u * BUCKETPAGE + HASHMOD] = (HASHMOD + 1) >> 1;
        }

        if (FillDict(bucketsP, ndicpages))
            break;
        padding += 16;      // try again with more margins
    }

    // Write dictionary
    libbuf->write(bucketsP, ndicpages * BUCKETPAGE);
    if (bucketsP)
        free(bucketsP);

    // Create library header
    #pragma pack(1)
    struct Libheader
    {
        unsigned char   recTyp;
        unsigned short  recLen;
        long            trailerPosn;
        unsigned short  ndicpages;
        unsigned char   flags;
        char            filler[ 6 ];
    };
    #pragma pack()

    Libheader libHeader;
    memset(&libHeader, 0, sizeof(Libheader));
    libHeader.recTyp = 0xF0;
    libHeader.recLen  = 0x0D;
    libHeader.trailerPosn = offset + (3 + size);
    libHeader.recLen = g_page_size - 3;
    libHeader.ndicpages = ndicpages;
    libHeader.flags = 1;                // always case sensitive

    // Write library header at start of buffer
    memcpy(libbuf->data, &libHeader, sizeof(libHeader));
}
