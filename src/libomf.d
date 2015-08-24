// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.libomf;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;
import core.stdc.stdarg;
import ddmd.globals;
import ddmd.lib;
import ddmd.mars;
import ddmd.root.array;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.stringtable;
import ddmd.errors;

enum LOG = false;

struct OmfObjSymbol
{
    char* name;
    OmfObjModule* om;
}

alias OmfObjModules = Array!(OmfObjModule*);
alias OmfObjSymbols = Array!(OmfObjSymbol*);

extern (C++) void scanOmfObjModule(void* pctx, void function(void* pctx, const(char)* name, int pickAny) pAddSymbol, void* base, size_t buflen, const(char)* module_name, Loc loc);

extern (C++) bool scanOmfLib(void* pctx, void function(void* pctx, char* name, void* base, size_t length) pAddObjModule, void* buf, size_t buflen, uint pagesize);

extern (C++) uint OMFObjSize(const(void)* base, uint length, const(char)* name);

extern (C++) void writeOMFObj(OutBuffer* buf, const(void)* base, uint length, const(char)* name);

extern (C) uint _rotl(uint value, int shift);
extern (C) uint _rotr(uint value, int shift);

extern (C++) final class LibOMF : Library
{
public:
    File* libfile;
    OmfObjModules objmodules; // OmfObjModule[]
    OmfObjSymbols objsymbols; // OmfObjSymbol[]
    StringTable tab;

    extern (D) this()
    {
        libfile = null;
        tab._init(14000);
    }

    /***********************************
     * Set the library file name based on the output directory
     * and the filename.
     * Add default library file name extension.
     */
    void setFilename(const(char)* dir, const(char)* filename)
    {
        const(char)* arg = filename;
        if (!arg || !*arg)
        {
            // Generate lib file name from first obj name
            const(char)* n = (*global.params.objfiles)[0];
            n = FileName.name(n);
            arg = FileName.forceExt(n, global.lib_ext);
        }
        if (!FileName.absolute(arg))
            arg = FileName.combine(dir, arg);
        const(char)* libfilename = FileName.defaultExt(arg, global.lib_ext);
        libfile = File.create(libfilename);
        loc.filename = libfile.name.toChars();
        loc.linnum = 0;
        loc.charnum = 0;
    }

    /***************************************
     * Add object module or library to the library.
     * Examine the buffer to see which it is.
     * If the buffer is NULL, use module_name as the file name
     * and load the file.
     */
    void addObject(const(char)* module_name, void* buf, size_t buflen)
    {
        static if (LOG)
        {
            printf("LibOMF::addObject(%s)\n", module_name ? module_name : "");
        }
        if (!buf)
        {
            assert(module_name);
            File* file = File.create(cast(char*)module_name);
            readFile(Loc(), file);
            buf = file.buffer;
            buflen = file.len;
            file._ref = 1;
        }
        uint g_page_size;
        ubyte* pstart = cast(ubyte*)buf;
        bool islibrary = false;
        /* See if it's an OMF library.
         * Don't go by file extension.
         */
        struct LibHeader
        {
        align(1):
            ubyte recTyp; // 0xF0
            ushort pagesize;
            uint lSymSeek;
            ushort ndicpages;
        }

        /* Determine if it is an OMF library, an OMF object module,
         * or something else.
         */
        if (buflen < (LibHeader).sizeof)
        {
        Lcorrupt:
            error("corrupt object module");
        }
        LibHeader* lh = cast(LibHeader*)buf;
        if (lh.recTyp == 0xF0)
        {
            /* OMF library
             * The modules are all at buf[g_page_size .. lh->lSymSeek]
             */
            islibrary = 1;
            g_page_size = lh.pagesize + 3;
            buf = cast(void*)(pstart + g_page_size);
            if (lh.lSymSeek > buflen || g_page_size > buflen)
                goto Lcorrupt;
            buflen = lh.lSymSeek - g_page_size;
        }
        else if (lh.recTyp == '!' && memcmp(lh, cast(char*)"!<arch>\n", 8) == 0)
        {
            error("COFF libraries not supported");
            return;
        }
        else
        {
            // Not a library, assume OMF object module
            g_page_size = 16;
        }
        struct Context
        {
            LibOMF lib;
            ubyte* pstart;
            uint pagesize;
            bool firstmodule;
            bool islibrary;
            const(char)* module_name;

            extern (D) this(LibOMF lib, ubyte* pstart, uint pagesize, bool islibrary, const(char)* module_name)
            {
                this.lib = lib;
                this.pstart = pstart;
                this.pagesize = pagesize;
                this.firstmodule = true;
                this.islibrary = islibrary;
                this.module_name = module_name;
            }

            extern (C++) static void addOmfObjModule(void* pctx, char* name, void* base, size_t length)
            {
                Context* ctx = cast(Context*)pctx;
                auto om = new OmfObjModule();
                om.base = cast(ubyte*)base;
                om.page = om.page = cast(ushort)((om.base - ctx.pstart) / ctx.pagesize);
                om.length = cast(uint)length;
                /* Determine the name of the module
                 */
                if (ctx.firstmodule && ctx.module_name && !ctx.islibrary)
                {
                    // Remove path and extension
                    om.name = strdup(FileName.name(ctx.module_name));
                    char* ext = cast(char*)FileName.ext(om.name);
                    if (ext)
                        ext[-1] = 0;
                }
                else
                {
                    /* Use THEADR name as module name,
                     * removing path and extension.
                     */
                    om.name = strdup(FileName.name(name));
                    char* ext = cast(char*)FileName.ext(om.name);
                    if (ext)
                        ext[-1] = 0;
                }
                ctx.firstmodule = false;
                ctx.lib.objmodules.push(om);
            }
        }

        auto ctx = Context(this, pstart, g_page_size, islibrary, module_name);
        if (scanOmfLib(&ctx, &Context.addOmfObjModule, buf, buflen, g_page_size))
            goto Lcorrupt;
    }

    /*****************************************************************************/
    void addLibrary(void* buf, size_t buflen)
    {
        addObject(null, buf, buflen);
    }

    void write()
    {
        if (global.params.verbose)
            fprintf(global.stdmsg, "library   %s\n", libfile.name.toChars());
        OutBuffer libbuf;
        WriteLibToBuffer(&libbuf);
        // Transfer image to file
        libfile.setbuffer(libbuf.data, libbuf.offset);
        libbuf.extractData();
        ensurePathToNameExists(Loc(), libfile.name.toChars());
        writeFile(Loc(), libfile);
    }

    void addSymbol(OmfObjModule* om, const(char)* name, int pickAny = 0)
    {
        static if (LOG)
        {
            printf("LibOMF::addSymbol(%s, %s, %d)\n", om.name, name, pickAny);
        }
        StringValue* s = tab.insert(name, strlen(name));
        if (!s)
        {
            // already in table
            if (!pickAny)
            {
                s = tab.lookup(name, strlen(name));
                assert(s);
                OmfObjSymbol* os = cast(OmfObjSymbol*)s.ptrvalue;
                error("multiple definition of %s: %s and %s: %s", om.name, name, os.om.name, os.name);
            }
        }
        else
        {
            auto os = new OmfObjSymbol();
            os.name = strdup(name);
            os.om = om;
            s.ptrvalue = cast(void*)os;
            objsymbols.push(os);
        }
    }

private:
    /************************************
     * Scan single object module for dictionary symbols.
     * Send those symbols to LibOMF::addSymbol().
     */
    void scanObjModule(OmfObjModule* om)
    {
        static if (LOG)
        {
            printf("LibMSCoff::scanObjModule(%s)\n", om.name);
        }
        struct Context
        {
            LibOMF lib;
            OmfObjModule* om;

            extern (D) this(LibOMF lib, OmfObjModule* om)
            {
                this.lib = lib;
                this.om = om;
            }

            extern (C++) static void addSymbol(void* pctx, const(char)* name, int pickAny)
            {
                (cast(Context*)pctx).lib.addSymbol((cast(Context*)pctx).om, name, pickAny);
            }
        }

        auto ctx = Context(this, om);
        scanOmfObjModule(&ctx, &Context.addSymbol, om.base, om.length, om.name, loc);
    }

    /***********************************
     * Calculates number of pages needed for dictionary
     * Returns:
     *      number of pages
     */
    ushort numDictPages(uint padding)
    {
        ushort ndicpages;
        ushort bucksForHash;
        ushort bucksForSize;
        uint symSize = 0;
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            OmfObjSymbol* s = objsymbols[i];
            symSize += (strlen(s.name) + 4) & ~1;
        }
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            OmfObjModule* om = objmodules[i];
            size_t len = strlen(om.name);
            if (len > 0xFF)
                len += 2; // Digital Mars long name extension
            symSize += (len + 4 + 1) & ~1;
        }
        bucksForHash = cast(ushort)((objsymbols.dim + objmodules.dim + HASHMOD - 3) / (HASHMOD - 2));
        bucksForSize = cast(ushort)((symSize + BUCKETSIZE - padding - padding - 1) / (BUCKETSIZE - padding));
        ndicpages = (bucksForHash > bucksForSize) ? bucksForHash : bucksForSize;
        //printf("ndicpages = %u\n",ndicpages);
        // Find prime number greater than ndicpages
        static __gshared uint* primes =
        [
            1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43,
            47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103,
            107, 109, 113, 127, 131, 137, 139, 149, 151, 157,
            163, 167, 173, 179, 181, 191, 193, 197, 199, 211,
            223, 227, 229, 233, 239, 241, 251, 257, 263, 269,
            271, 277, 281, 283, 293, 307, 311, 313, 317, 331,
            337, 347, 349, 353, 359, 367, 373, 379, 383, 389,
            397, 401, 409, 419, 421, 431, 433, 439, 443, 449,
            457, 461, 463, 467, 479, 487, 491, 499, 503, 509,
            0
        ];
        //521,523,541,547,
        for (size_t i = 0; 1; i++)
        {
            if (primes[i] == 0)
            {
                // Quick and easy way is out.
                // Now try and find first prime number > ndicpages
                uint prime;
                for (prime = (ndicpages + 1) | 1; 1; prime += 2)
                {
                    // Determine if prime is prime
                    for (uint u = 3; u < prime / 2; u += 2)
                    {
                        if ((prime / u) * u == prime)
                            goto L1;
                    }
                    break;
                L1:
                }
                ndicpages = cast(ushort)prime;
                break;
            }
            if (primes[i] > ndicpages)
            {
                ndicpages = cast(ushort)primes[i];
                break;
            }
        }
        return ndicpages;
    }

    /*******************************************
     * Write the module and symbol names to the dictionary.
     * Returns:
     *      false   failure
     */
    bool FillDict(ubyte* bucketsP, ushort ndicpages)
    {
        enum LIBIDMAX = (512 - 0x25 - 3 - 4);
        // max size that will fit in dictionary
        ubyte[4 + LIBIDMAX + 2 + 1] entry;
        //printf("FillDict()\n");
        // Add each of the module names
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            OmfObjModule* om = objmodules[i];
            ushort n = cast(ushort)strlen(om.name);
            if (n > 255)
            {
                entry[0] = 0xFF;
                entry[1] = 0;
                *cast(ushort*)(entry.ptr + 2) = cast(ushort)(n + 1);
                memcpy(entry.ptr + 4, om.name, n);
                n += 3;
            }
            else
            {
                entry[0] = cast(ubyte)(1 + n);
                memcpy(entry.ptr + 1, om.name, n);
            }
            entry[n + 1] = '!';
            *(cast(ushort*)(n + 2 + entry.ptr)) = om.page;
            if (n & 1)
                entry[n + 2 + 2] = 0;
            if (!EnterDict(bucketsP, ndicpages, entry.ptr, n + 1))
                return false;
        }
        // Sort the symbols
        qsort(objsymbols.tdata(), objsymbols.dim, (objsymbols[0]).sizeof, &NameCompare);
        // Add each of the symbols
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            OmfObjSymbol* os = objsymbols[i];
            ushort n = cast(ushort)strlen(os.name);
            if (n > 255)
            {
                entry[0] = 0xFF;
                entry[1] = 0;
                *cast(ushort*)(entry.ptr + 2) = n;
                memcpy(entry.ptr + 4, os.name, n);
                n += 3;
            }
            else
            {
                entry[0] = cast(ubyte)n;
                memcpy(entry.ptr + 1, os.name, n);
            }
            *(cast(ushort*)(n + 1 + entry.ptr)) = os.om.page;
            if ((n & 1) == 0)
                entry[n + 3] = 0;
            if (!EnterDict(bucketsP, ndicpages, entry.ptr, n))
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
    void WriteLibToBuffer(OutBuffer* libbuf)
    {
        /* Scan each of the object modules for symbols
         * to go into the dictionary
         */
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            OmfObjModule* om = objmodules[i];
            scanObjModule(om);
        }
        uint g_page_size = 16;
        /* Calculate page size so that the number of pages
         * fits in 16 bits. This is because object modules
         * are indexed by page number, stored as an unsigned short.
         */
        while (1)
        {
        Lagain:
            static if (LOG)
            {
                printf("g_page_size = %d\n", g_page_size);
            }
            uint offset = g_page_size;
            for (size_t i = 0; i < objmodules.dim; i++)
            {
                OmfObjModule* om = objmodules[i];
                uint page = offset / g_page_size;
                if (page > 0xFFFF)
                {
                    // Page size is too small, double it and try again
                    g_page_size *= 2;
                    goto Lagain;
                }
                offset += OMFObjSize(om.base, om.length, om.name);
                // Round the size of the file up to the next page size
                // by filling with 0s
                uint n = (g_page_size - 1) & offset;
                if (n)
                    offset += g_page_size - n;
            }
            break;
        }
        /* Leave one page of 0s at start as a dummy library header.
         * Fill it in later with the real data.
         */
        libbuf.fill0(g_page_size);
        /* Write each object module into the library
         */
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            OmfObjModule* om = objmodules[i];
            uint page = cast(uint)(libbuf.offset / g_page_size);
            assert(page <= 0xFFFF);
            om.page = cast(ushort)page;
            // Write out the object module om
            writeOMFObj(libbuf, om.base, om.length, om.name);
            // Round the size of the file up to the next page size
            // by filling with 0s
            uint n = (g_page_size - 1) & libbuf.offset;
            if (n)
                libbuf.fill0(g_page_size - n);
        }
        // File offset of start of dictionary
        uint offset = cast(uint)libbuf.offset;
        // Write dictionary header, then round it to a BUCKETPAGE boundary
        ushort size = (BUCKETPAGE - (cast(short)offset + 3)) & (BUCKETPAGE - 1);
        libbuf.writeByte(0xF1);
        libbuf.writeword(size);
        libbuf.fill0(size);
        // Create dictionary
        ubyte* bucketsP = null;
        ushort ndicpages;
        ushort padding = 32;
        for (;;)
        {
            ndicpages = numDictPages(padding);
            static if (LOG)
            {
                printf("ndicpages = %d\n", ndicpages);
            }
            // Allocate dictionary
            if (bucketsP)
                bucketsP = cast(ubyte*)realloc(bucketsP, ndicpages * BUCKETPAGE);
            else
                bucketsP = cast(ubyte*)malloc(ndicpages * BUCKETPAGE);
            assert(bucketsP);
            memset(bucketsP, 0, ndicpages * BUCKETPAGE);
            for (uint u = 0; u < ndicpages; u++)
            {
                // 'next available' slot
                bucketsP[u * BUCKETPAGE + HASHMOD] = (HASHMOD + 1) >> 1;
            }
            if (FillDict(bucketsP, ndicpages))
                break;
            padding += 16; // try again with more margins
        }
        // Write dictionary
        libbuf.write(bucketsP, ndicpages * BUCKETPAGE);
        if (bucketsP)
            free(bucketsP);
        // Create library header
        struct Libheader
        {
        align(1):
            ubyte recTyp;
            ushort recLen;
            uint trailerPosn;
            ushort ndicpages;
            ubyte flags;
            char* filler;
        }

        Libheader libHeader;
        memset(&libHeader, 0, (Libheader).sizeof);
        libHeader.recTyp = 0xF0;
        libHeader.recLen = 0x0D;
        libHeader.trailerPosn = offset + (3 + size);
        libHeader.recLen = cast(ushort)(g_page_size - 3);
        libHeader.ndicpages = ndicpages;
        libHeader.flags = 1; // always case sensitive
        // Write library header at start of buffer
        memcpy(libbuf.data, &libHeader, (libHeader).sizeof);
    }

    void error(const(char)* format, ...)
    {
        Loc loc;
        if (libfile)
        {
            loc.filename = libfile.name.toChars();
            loc.linnum = 0;
            loc.charnum = 0;
        }
        va_list ap;
        va_start(ap, format);
        .verror(loc, format, ap);
        va_end(ap);
    }

    Loc loc;
}

extern (C++) Library LibOMF_factory()
{
    return global.params.mscoff ? LibMSCoff_factory() : new LibOMF();
}

/*****************************************************************************/
/*****************************************************************************/
struct OmfObjModule
{
    ubyte* base; // where are we holding it in memory
    uint length; // in bytes
    ushort page; // page module starts in output file
    char* name; // module name
}

/*****************************************************************************/
/*****************************************************************************/
extern (C)
{
    int NameCompare(const(void*) p1, const(void*) p2)
    {
        return strcmp((*cast(OmfObjSymbol**)p1).name, (*cast(OmfObjSymbol**)p2).name);
    }
}

enum HASHMOD = 0x25;
enum BUCKETPAGE = 512;
enum BUCKETSIZE = (BUCKETPAGE - HASHMOD - 1);

/*******************************************
 * Write a single entry into dictionary.
 * Returns:
 *      false   failure
 */
extern (C++) static bool EnterDict(ubyte* bucketsP, ushort ndicpages, ubyte* entry, uint entrylen)
{
    ushort uStartIndex;
    ushort uStep;
    ushort uStartPage;
    ushort uPageStep;
    ushort uIndex;
    ushort uPage;
    ushort n;
    uint u;
    uint nbytes;
    ubyte* aP;
    ubyte* zP;
    aP = entry;
    zP = aP + entrylen; // point at last char in identifier
    uStartPage = 0;
    uPageStep = 0;
    uStartIndex = 0;
    uStep = 0;
    u = entrylen;
    while (u--)
    {
        uStartPage = cast(ushort)_rotl(uStartPage, 2) ^ (*aP | 0x20);
        uStep = cast(ushort)_rotr(uStep, 2) ^ (*aP++ | 0x20);
        uStartIndex = cast(ushort)_rotr(uStartIndex, 2) ^ (*zP | 0x20);
        uPageStep = cast(ushort)_rotl(uPageStep, 2) ^ (*zP-- | 0x20);
    }
    uStartPage %= ndicpages;
    uPageStep %= ndicpages;
    if (uPageStep == 0)
        uPageStep++;
    uStartIndex %= HASHMOD;
    uStep %= HASHMOD;
    if (uStep == 0)
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
            if (0 == aP[uIndex])
            {
                // n = next available position in this page
                n = aP[HASHMOD] << 1;
                assert(n > HASHMOD);
                // if off end of this page
                if (n + nbytes > BUCKETPAGE)
                {
                    aP[HASHMOD] = 0xFF;
                    break;
                    // next page
                }
                else
                {
                    aP[uIndex] = cast(ubyte)(n >> 1);
                    memcpy((aP + n), entry, nbytes);
                    aP[HASHMOD] += (nbytes + 1) >> 1;
                    if (aP[HASHMOD] == 0)
                        aP[HASHMOD] = 0xFF;
                    return true;
                }
            }
            uIndex += uStep;
            uIndex %= 0x25;
            /*if (uIndex > 0x25)
             uIndex -= 0x25;*/
            if (uIndex == uStartIndex)
                break;
        }
        uPage += uPageStep;
        if (uPage >= ndicpages)
            uPage -= ndicpages;
        if (uPage == uStartPage)
            break;
    }
    return false;
}
