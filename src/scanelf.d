/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _scanelf.d)
 */

module ddmd.scanelf;

version (linux)
    import core.sys.linux.elf;
else version (FreeBSD)
    import core.sys.freebsd.sys.elf;
else version (Solaris)
    import core.sys.solaris.elf;

import core.stdc.string;
import core.checkedint;

import ddmd.globals;
import ddmd.errors;

enum LOG = false;

/*****************************************
 * Reads an object module from base[] and passes the names
 * of any exported symbols to (*pAddSymbol)().
 * Params:
 *      pAddSymbol =  function to pass the names to
 *      base =        array of contents of object module
 *      module_name = name of the object module (used for error messages)
 *      loc =         location to use for error printing
 */
void scanElfObjModule(void delegate(const(char)[] name, int pickAny) pAddSymbol,
        const(ubyte)[] base, const(char)* module_name, Loc loc)
{
    static if (LOG)
    {
        printf("scanElfObjModule(%s)\n", module_name);
    }

    void corrupt(int reason)
    {
        error(loc, "corrupt ELF object module %s %d", module_name, reason);
    }

    if (base.length < Elf32_Ehdr.sizeof)
        return corrupt(__LINE__); // must be at least large enough for ELF32
    static immutable ubyte[4] elf = [0x7F, 'E', 'L', 'F']; // ELF file signature
    if (base[0 .. elf.length] != elf[])
        return corrupt(__LINE__);

    if (base[EI_VERSION] != EV_CURRENT)
    {
        return error(loc, "ELF object module %s has EI_VERSION = %d, should be %d",
            module_name, base[EI_VERSION], EV_CURRENT);
    }
    if (base[EI_DATA] != ELFDATA2LSB)
    {
        return error(loc, "ELF object module %s is byte swapped and unsupported", module_name);
    }
    if (base[EI_CLASS] != ELFCLASS32 && base[EI_CLASS] != ELFCLASS64)
    {
        return error(loc, "ELF object module %s is unrecognized class %d", module_name, base[EI_CLASS]);
    }

    void scanELF(uint model)()
    {
        static if (model == 32)
        {
            alias ElfXX_Ehdr = Elf32_Ehdr;
            alias ElfXX_Shdr = Elf32_Shdr;
            alias ElfXX_Sym = Elf32_Sym;
        }
        else
        {
            static assert(model == 64);
            alias ElfXX_Ehdr = Elf64_Ehdr;
            alias ElfXX_Shdr = Elf64_Shdr;
            alias ElfXX_Sym = Elf64_Sym;
        }

        if (base.length < ElfXX_Ehdr.sizeof)
            return corrupt(__LINE__);

        const eh = cast(const(ElfXX_Ehdr)*) base.ptr;
        if (eh.e_type != ET_REL)
            return error(loc, "ELF object module %s is not relocatable", module_name);
        if (eh.e_version != EV_CURRENT)
            return corrupt(__LINE__);

        bool overflow;
        const end = addu(eh.e_shoff, mulu(eh.e_shentsize, eh.e_shnum, overflow), overflow);
        if (overflow || end > base.length)
            return corrupt(__LINE__);

        /* For each Section
         */
        const sections = (cast(const(ElfXX_Shdr)*)(base.ptr + eh.e_shoff))[0 .. eh.e_shnum];
        foreach (ref const section; sections)
        {
            if (section.sh_type != SHT_SYMTAB)
                continue;

            bool checkShdrXX(const ref ElfXX_Shdr shdr)
            {
                bool overflow;
                return addu(shdr.sh_offset, shdr.sh_size, overflow) > base.length || overflow;
            }

            if (checkShdrXX(section))
                return corrupt(__LINE__);

            /* sh_link gives the particular string table section
             * used for the symbol names.
             */
            if (section.sh_link >= eh.e_shnum)
                return corrupt(__LINE__);

            const string_section = &sections[section.sh_link];
            if (string_section.sh_type != SHT_STRTAB)
                return corrupt(__LINE__);

            if (checkShdrXX(*string_section))
                return corrupt(__LINE__);

            const string_tab = (cast(const(char)[])base)
                [cast(size_t)string_section.sh_offset ..
                 cast(size_t)(string_section.sh_offset + string_section.sh_size)];

            /* Get the array of symbols this section refers to
             */
            const symbols = (cast(ElfXX_Sym*)(base.ptr + cast(size_t)section.sh_offset))
                [0 .. cast(size_t)(section.sh_size / ElfXX_Sym.sizeof)];

            foreach (ref const sym; symbols)
            {
                const stb = sym.st_info >> 4;
                if (stb != STB_GLOBAL && stb != STB_WEAK || sym.st_shndx == SHN_UNDEF)
                    continue; // it's extern

                if (sym.st_name >= string_tab.length)
                    return corrupt(__LINE__);

                const name = &string_tab[sym.st_name];
                //printf("sym st_name = x%x\n", sym.st_name);
                const pend = memchr(name, 0, string_tab.length - sym.st_name);
                if (!pend)       // if didn't find terminating 0 inside the string section
                    return corrupt(__LINE__);
                pAddSymbol(name[0 .. pend - name], 1);
            }
        }
    }

    if (base[EI_CLASS] == ELFCLASS32)
    {
        scanELF!32;
    }
    else
    {
        assert(base[EI_CLASS] == ELFCLASS64);
        scanELF!64;
    }
}
