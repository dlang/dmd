
/*
 * Copyright (c) 1986-1995 by Symantec
 * Copyright (c) 2000-2013 by Digital Mars
 * All Rights Reserved
 * http://www.digitalmars.com
 * Written by Walter Bright
 *
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

// Compiler implementation of the D programming language

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>                     // str{len|dup}(),memcpy()

#include "rmem.h"
#include "root.h"
#include "stringtable.h"

#include "mars.h"
#include "lib.h"

#define LOG 0

struct ObjModule;

struct ObjSymbol
{
    char *name;
    ObjModule *om;
};

#include "arraytypes.h"

typedef Array<ObjModule *> ObjModules;
typedef Array<ObjSymbol *> ObjSymbols;

class LibOMF : public Library
{
  public:
    File *libfile;
    ObjModules objmodules;   // ObjModule[]
    ObjSymbols objsymbols;   // ObjSymbol[]

    StringTable tab;

    LibOMF();
    void setFilename(const char *dir, const char *filename);
    void addObject(const char *module_name, void *buf, size_t buflen);
    void addLibrary(void *buf, size_t buflen);
    void write();

    void addSymbol(ObjModule *om, const char *name, int pickAny = 0);
  private:
    void scanObjModule(ObjModule *om);
    unsigned short numDictPages(unsigned padding);
    bool FillDict(unsigned char *bucketsP, unsigned short uNumPages);
    void WriteLibToBuffer(OutBuffer *libbuf);

    void error(const char *format, ...)
    {
        Loc loc;
        if (libfile)
        {
            loc.filename = libfile->name->toChars();
            loc.linnum = 0;
            loc.charnum = 0;
        }
        va_list ap;
        va_start(ap, format);
        ::verror(loc, format, ap);
        va_end(ap);
    }

    Loc loc;
};

Library *LibOMF_factory()
{
    return global.params.mscoff ? LibMSCoff_factory() : new LibOMF();
}

LibOMF::LibOMF()
{
    libfile = NULL;
    tab._init(14000);
}

/***********************************
 * Set the library file name based on the output directory
 * and the filename.
 * Add default library file name extension.
 */

void LibOMF::setFilename(const char *dir, const char *filename)
{
    const char *arg = filename;
    if (!arg || !*arg)
    {   // Generate lib file name from first obj name
        const char *n = (*global.params.objfiles)[0];

        n = FileName::name(n);
        arg = FileName::forceExt(n, global.lib_ext);
    }
    if (!FileName::absolute(arg))
        arg = FileName::combine(dir, arg);
    const char *libfilename = FileName::defaultExt(arg, global.lib_ext);

    libfile = File::create(libfilename);

    loc.filename = libfile->name->toChars();
    loc.linnum = 0;
    loc.charnum = 0;
}

void LibOMF::write()
{
    if (global.params.verbose)
        fprintf(global.stdmsg, "library   %s\n", libfile->name->toChars());

    OutBuffer libbuf;
    WriteLibToBuffer(&libbuf);

    // Transfer image to file
    libfile->setbuffer(libbuf.data, libbuf.offset);
    libbuf.extractData();


    ensurePathToNameExists(Loc(), libfile->name->toChars());

    writeFile(Loc(), libfile);
}

/*****************************************************************************/

void LibOMF::addLibrary(void *buf, size_t buflen)
{
    addObject(NULL, buf, buflen);
}


/*****************************************************************************/
/*****************************************************************************/

struct ObjModule
{
    unsigned char *base;        // where are we holding it in memory
    unsigned length;            // in bytes
    unsigned short page;        // page module starts in output file
    char *name;                 // module name
};

unsigned OMFObjSize(const void *base, unsigned length, const char *name);
void writeOMFObj(OutBuffer *buf, const void *base, unsigned length, const char *name);

void LibOMF::addSymbol(ObjModule *om, const char *name, int pickAny)
{
#if LOG
    printf("LibOMF::addSymbol(%s, %s, %d)\n", om->name, name, pickAny);
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
 * Send those symbols to LibOMF::addSymbol().
 */

void LibOMF::scanObjModule(ObjModule *om)
{
#if LOG
    printf("LibMSCoff::scanObjModule(%s)\n", om->name);
#endif

    struct Context
    {
        LibOMF *lib;
        ObjModule *om;

        Context(LibOMF *lib, ObjModule *om)
        {
            this->lib = lib;
            this->om = om;
        }

        static void addSymbol(void *pctx, const char *name, int pickAny)
        {
            ((Context *)pctx)->lib->addSymbol(((Context *)pctx)->om, name, pickAny);
        }
    };

    Context ctx(this, om);

    extern void scanOmfObjModule(void*, void (*pAddSymbol)(void*, const char*, int), void *, size_t, const char *, Loc loc);
    scanOmfObjModule(&ctx, &Context::addSymbol, om->base, om->length, om->name, loc);
}

/***************************************
 * Add object module or library to the library.
 * Examine the buffer to see which it is.
 * If the buffer is NULL, use module_name as the file name
 * and load the file.
 */

void LibOMF::addObject(const char *module_name, void *buf, size_t buflen)
{
#if LOG
    printf("LibOMF::addObject(%s)\n", module_name ? module_name : "");
#endif
    if (!buf)
    {   assert(module_name);
        File *file = File::create((char *)module_name);
        readFile(Loc(), file);
        buf = file->buffer;
        buflen = file->len;
        file->ref = 1;
    }

    unsigned g_page_size;
    unsigned char *pstart = (unsigned char *)buf;
    bool islibrary = false;

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

    struct Context
    {
        LibOMF *lib;
        unsigned char *pstart;
        unsigned pagesize;
        bool firstmodule;
        bool islibrary;
        const char *module_name;

        Context(LibOMF *lib, unsigned char *pstart, unsigned pagesize, bool islibrary, const char *module_name)
        {
            this->lib = lib;
            this->pstart = pstart;
            this->pagesize = pagesize;
            this->firstmodule = true;
            this->islibrary = islibrary;
            this->module_name = module_name;
        }

        static void addObjModule(void *pctx, char *name, void *base, size_t length)
        {
            Context *ctx = (Context *)pctx;
            ObjModule *om = new ObjModule();
            om->base = (unsigned char *)base;
            om->page = om->page = (om->base - ctx->pstart) / ctx->pagesize;
            om->length = length;

            /* Determine the name of the module
             */
            if (ctx->firstmodule && ctx->module_name && !ctx->islibrary)
            {   // Remove path and extension
                om->name = strdup(FileName::name(ctx->module_name));
                char *ext = (char *)FileName::ext(om->name);
                if (ext)
                    ext[-1] = 0;
            }
            else
            {   /* Use THEADR name as module name,
                 * removing path and extension.
                 */
                om->name = strdup(FileName::name(name));
                char *ext = (char *)FileName::ext(om->name);
                if (ext)
                    ext[-1] = 0;
            }

            ctx->firstmodule = false;

            ctx->lib->objmodules.push(om);
        }
    };

    Context ctx(this, pstart, g_page_size, islibrary, module_name);

    extern bool scanOmfLib(void*, void (*pAddObjModule)(void*, char*, void *, size_t), void *, size_t, unsigned);
    if (scanOmfLib(&ctx, &Context::addObjModule, buf, buflen, g_page_size))
        goto Lcorrupt;
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

unsigned short LibOMF::numDictPages(unsigned padding)
{
    unsigned short      ndicpages;
    unsigned short      bucksForHash;
    unsigned short      bucksForSize;
    unsigned symSize = 0;

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *s = objsymbols[i];

        symSize += ( strlen(s->name) + 4 ) & ~1;
    }

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

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
 *      false   failure
 */

static bool EnterDict( unsigned char *bucketsP, unsigned short ndicpages, unsigned char *entry, unsigned entrylen )
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
                    return true;
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

    return false;
}

/*******************************************
 * Write the module and symbol names to the dictionary.
 * Returns:
 *      false   failure
 */

bool LibOMF::FillDict(unsigned char *bucketsP, unsigned short ndicpages)
{
    #define LIBIDMAX (512 - 0x25 - 3 - 4)   // max size that will fit in dictionary
    unsigned char entry[4 + LIBIDMAX + 2 + 1];

    //printf("FillDict()\n");

    // Add each of the module names
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

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
            return false;
    }

    // Sort the symbols
    qsort( objsymbols.tdata(), objsymbols.dim, sizeof(objsymbols[0]), (cmpfunc_t)NameCompare );

    // Add each of the symbols
    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

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
            return false;
        }
    }
    return true;
}


/**********************************************
 * Create and write library to libbuf.
 * The library consists of:
 *      library header
 *      object modules...
 *      dictionary header
 *      dictionary pages...
 */

void LibOMF::WriteLibToBuffer(OutBuffer *libbuf)
{
    /* Scan each of the object modules for symbols
     * to go into the dictionary
     */
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

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
        {   ObjModule *om = objmodules[i];

            unsigned page = offset / g_page_size;
            if (page > 0xFFFF)
            {   // Page size is too small, double it and try again
                g_page_size *= 2;
                goto Lagain;
            }

            offset += OMFObjSize(om->base, om->length, om->name);

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
    {   ObjModule *om = objmodules[i];

        unsigned page = libbuf->offset / g_page_size;
        assert(page <= 0xFFFF);
        om->page = page;

        // Write out the object module om
        writeOMFObj(libbuf, om->base, om->length, om->name);

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
        unsigned        trailerPosn;
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
