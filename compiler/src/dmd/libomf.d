/**
 * A library in the OMF format, a legacy format for 32-bit Windows.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/libomf.d, _libomf.d)
 * Documentation:  https://dlang.org/phobos/dmd_libomf.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/libomf.d
 */

module dmd.libomf;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;
import core.bitop;

import dmd.globals;
import dmd.utils;
import dmd.lib;

import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.rmem;
import dmd.common.outbuffer;
import dmd.root.string;
import dmd.root.stringtable;

import dmd.scanomf;

// Entry point (only public symbol in this module).
extern (C++) Library LibOMF_factory()
{
    return new LibOMF();
}

private: // for the remainder of this module

enum LOG = false;

struct OmfObjSymbol
{
    char* name;
    OmfObjModule* om;

    /// Predicate for `Array.sort`for name comparison
    static int name_pred (scope const OmfObjSymbol** ppe1, scope const OmfObjSymbol** ppe2) nothrow @nogc pure
    {
        return strcmp((**ppe1).name, (**ppe2).name);
    }
}

alias OmfObjModules = Array!(OmfObjModule*);
alias OmfObjSymbols = Array!(OmfObjSymbol*);

final class LibOMF : Library
{
    OmfObjModules objmodules; // OmfObjModule[]
    OmfObjSymbols objsymbols; // OmfObjSymbol[]
    StringTable!(OmfObjSymbol*) tab;

    extern (D) this()
    {
        tab._init(14_000);
    }

    /***************************************
     * Add object module or library to the library.
     * Examine the buffer to see which it is.
     * If the buffer is NULL, use module_name as the file name
     * and load the file.
     */
    override void addObject(const(char)[] module_name, const ubyte[] buffer)
    {
        static if (LOG)
        {
            printf("LibOMF::addObject(%.*s)\n", cast(int)module_name.length,
                   module_name.ptr);
        }

        void corrupt(int reason)
        {
            error("corrupt OMF object module %.*s %d",
                  cast(int)module_name.length, module_name.ptr, reason);
        }

        auto buf = buffer.ptr;
        auto buflen = buffer.length;
        if (!buf)
        {
            assert(module_name.length, "No module nor buffer provided to `addObject`");
            // read file and take buffer ownership
            auto data = readFile(Loc.initial, module_name).extractSlice();
            buf = data.ptr;
            buflen = data.length;
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
        else if (lh.recTyp == '!' && memcmp(lh, "!<arch>\n".ptr, 8) == 0)
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
            om.page = cast(ushort)((om.base - pstart) / g_page_size);
            om.length = cast(uint)length;
            /* Determine the name of the module
             */
            if (firstmodule && module_name && !islibrary)
            {
                // Remove path and extension
                om.name = FileName.removeExt(FileName.name(module_name));
            }
            else
            {
                /* Use THEADR name as module name,
                 * removing path and extension.
                 */
                om.name = FileName.removeExt(FileName.name(name.toDString()));
            }
            firstmodule = false;
            this.objmodules.push(om);
        }

        if (scanOmfLib(&addOmfObjModule, cast(void*)buf, buflen, g_page_size))
            return corrupt(__LINE__);
    }

    /*****************************************************************************/

    void addSymbol(OmfObjModule* om, const(char)[] name, int pickAny = 0)
    {
        assert(name.length == strlen(name.ptr));
        static if (LOG)
        {
            printf("LibOMF::addSymbol(%.*s, %.*s, %d)\n",
                cast(int)om.name.length, om.name.ptr,
                cast(int)name.length, name.ptr, pickAny);
        }
        if (auto s = tab.insert(name, null))
        {
            auto os = new OmfObjSymbol();
            os.name = cast(char*)Mem.check(strdup(name.ptr));
            os.om = om;
            s.value = os;
            objsymbols.push(os);
        }
        else
        {
            // already in table
            if (!pickAny)
            {
                const s2 = tab.lookup(name);
                assert(s2);
                const os = s2.value;
                error("multiple definition of %.*s: %.*s and %.*s: %s",
                    cast(int)om.name.length, om.name.ptr,
                    cast(int)name.length, name.ptr,
                    cast(int)os.om.name.length, os.om.name.ptr, os.name);
            }
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
            this.addSymbol(om, name, pickAny);
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
        foreach (s; objsymbols)
        {
            symSize += (strlen(s.name) + 4) & ~1;
        }
        foreach (om; objmodules)
        {
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
        __gshared uint* primes =
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
        foreach (om; objmodules)
        {
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
        objsymbols.sort!(OmfObjSymbol.name_pred);
        // Add each of the symbols
        foreach (os; objsymbols)
        {
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
        foreach (om; objmodules)
        {
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
            foreach (om; objmodules)
            {
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
        foreach (om; objmodules)
        {
            uint page = cast(uint)(libbuf.length / g_page_size);
            assert(page <= 0xFFFF);
            om.page = cast(ushort)page;
            // Write out the object module om
            writeOMFObj(libbuf, om.base, om.length, om.name.ptr);
            // Round the size of the file up to the next page size
            // by filling with 0s
            uint n = (g_page_size - 1) & libbuf.length;
            if (n)
                libbuf.fill0(g_page_size - n);
        }
        // File offset of start of dictionary
        uint offset = cast(uint)libbuf.length;
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
                bucketsP = cast(ubyte*)Mem.check(realloc(bucketsP, ndicpages * BUCKETPAGE));
            else
                bucketsP = cast(ubyte*)Mem.check(malloc(ndicpages * BUCKETPAGE));
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
        libbuf.write(bucketsP[0 .. ndicpages * BUCKETPAGE]);
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
        memcpy(cast(void*)(*libbuf)[].ptr, &libHeader, (libHeader).sizeof);
    }
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

enum HASHMOD = 0x25;
enum BUCKETPAGE = 512;
enum BUCKETSIZE = (BUCKETPAGE - HASHMOD - 1);

/*******************************************
 * Write a single entry into dictionary.
 * Returns:
 *      false   failure
 */
bool EnterDict(ubyte* bucketsP, ushort ndicpages, ubyte* entry, uint entrylen)
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
        uStartPage  = rol!(ushort)(uStartPage, 2)  ^ (*aP   | 0x20);
        uStep       = ror!(ushort)(uStep, 2)       ^ (*aP++ | 0x20);
        uStartIndex = ror!(ushort)(uStartIndex, 2) ^ (*zP   | 0x20);
        uPageStep   = rol!(ushort)(uPageStep, 2)   ^ (*zP-- | 0x20);
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
