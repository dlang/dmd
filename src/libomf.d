/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _libomf.d)
 */

module ddmd.libomf;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;

import ddmd.globals;
import ddmd.utils;
import ddmd.lib;

import ddmd.root.array;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.stringtable;

import ddmd.scanomf;

enum LOG = false;

struct OmfObjSymbol
{
    char* name;
    OmfObjModule* om;
}

alias OmfObjModules = Array!(OmfObjModule*);
alias OmfObjSymbols = Array!(OmfObjSymbol*);

extern (C) uint _rotl(uint value, int shift);
extern (C) uint _rotr(uint value, int shift);

final class LibOMF : Library
{
    OmfObjModules objmodules; // OmfObjModule[]
    OmfObjSymbols objsymbols; // OmfObjSymbol[]
    StringTable tab;

    extern (D) this()
    {
        tab._init(14000);
    }

    /***************************************
     * Add object module or library to the library.
     * Examine the buffer to see which it is.
     * If the buffer is NULL, use module_name as the file name
     * and load the file.
     */
    override void addObject(const(char)* module_name, const ubyte[] buffer)
    {
        static if (LOG)
        {
            printf("LibOMF::addObject(%s)\n", module_name ? module_name : "");
        }

        void corrupt(int reason)
        {
            error("corrupt OMF object module %s %d", module_name, reason);
        }

        auto buf = buffer.ptr;
        auto buflen = buffer.length;
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
            return corrupt(__LINE__);
        const lh = cast(const(LibHeader)*)buf;
        if (lh.recTyp == 0xF0)
        {
            /* OMF library
             * The modules are all at buf[g_page_size .. lh.lSymSeek]
             */
            islibrary = 1;
            g_page_size = lh.pagesize + 3;
            buf = cast(ubyte*)(pstart + g_page_size);
            if (lh.lSymSeek > buflen || g_page_size > buflen)
                return corrupt(__LINE__);
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
        bool firstmodule = true;

        void addOmfObjModule(char* name, void* base, size_t length)
        {
            auto om = new OmfObjModule();
            om.base = cast(ubyte*)base;
            om.page = om.page = cast(ushort)((om.base - pstart) / g_page_size);
            om.length = cast(uint)length;
            /* Determine the name of the module
             */
            if (firstmodule && module_name && !islibrary)
            {
                // Remove path and extension
                auto n = strdup(FileName.name(module_name));
                om.name = n[0 .. strlen(n)];
                char* ext = cast(char*)FileName.ext(n);
                if (ext)
                    ext[-1] = 0;
            }
            else
            {
                /* Use THEADR name as module name,
                 * removing path and extension.
                 */
                auto n = strdup(FileName.name(name));
                om.name = n[0 .. strlen(n)];
                char* ext = cast(char*)FileName.ext(n);
                if (ext)
                    ext[-1] = 0;
            }
            firstmodule = false;
            this.objmodules.push(om);
        }

        if (scanOmfLib(&addOmfObjModule, cast(void*)buf, buflen, g_page_size))
            return corrupt(__LINE__);
    }

    /*****************************************************************************/

    void addSymbol(OmfObjModule* om, const(char)* name, int pickAny = 0)
    {
        static if (LOG)
        {
            printf("LibOMF::addSymbol(%s, %s, %d)\n", om.name.ptr, name, pickAny);
        }
        const namelen = strlen(name);
        StringValue* s = tab.insert(name, namelen, null);
        if (!s)
        {
            // already in table
            if (!pickAny)
            {
                const s2 = tab.lookup(name, namelen);
                assert(s2);
                const os = cast(const(OmfObjSymbol)*)s2.ptrvalue;
                error("multiple definition of %s: %s and %s: %s", om.name.ptr, name, os.om.name.ptr, os.name);
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
            printf("LibMSCoff::scanObjModule(%s)\n", om.name.ptr);
        }

        extern (D) void addSymbol(const(char)[] name, int pickAny)
        {
            this.addSymbol(om, name.ptr, pickAny);
        }

        scanOmfObjModule(&addSymbol, om.base[0 .. om.length], om.name.ptr, loc);
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
            size_t len = om.name.length;
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
            //521,523,541,547,
            0
        ];
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
        // max size that will fit in dictionary
        enum LIBIDMAX = (512 - 0x25 - 3 - 4);
        ubyte[4 + LIBIDMAX + 2 + 1] entry;
        //printf("FillDict()\n");
        // Add each of the module names
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            OmfObjModule* om = objmodules[i];
            ushort n = cast(ushort)om.name.length;
            if (n > 255)
            {
                entry[0] = 0xFF;
                entry[1] = 0;
                *cast(ushort*)(entry.ptr + 2) = cast(ushort)(n + 1);
                memcpy(entry.ptr + 4, om.name.ptr, n);
                n += 3;
            }
            else
            {
                entry[0] = cast(ubyte)(1 + n);
                memcpy(entry.ptr + 1, om.name.ptr, n);
            }
            entry[n + 1] = '!';
            *(cast(ushort*)(n + 2 + entry.ptr)) = om.page;
            if (n & 1)
                entry[n + 2 + 2] = 0;
            if (!EnterDict(bucketsP, ndicpages, entry.ptr, n + 1))
                return false;
        }
        // Sort the symbols
        qsort(objsymbols.tdata(), objsymbols.dim, (objsymbols[0]).sizeof, cast(_compare_fp_t)&NameCompare);
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
    protected override void WriteLibToBuffer(OutBuffer* libbuf)
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
                offset += OMFObjSize(om.base, om.length, om.name.ptr);
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
            writeOMFObj(libbuf, om.base, om.length, om.name.ptr);
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
            uint filler;
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
}

extern (C++) Library LibOMF_factory()
{
    return new LibOMF();
}

/*****************************************************************************/
/*****************************************************************************/
struct OmfObjModule
{
    ubyte* base; // where are we holding it in memory
    uint length; // in bytes
    ushort page; // page module starts in output file
    const(char)[] name; // module name, with terminating 0
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
