// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.scanmach;

import core.stdc.string;
import core.stdc.stdint;
import core.sys.osx.mach.loader;
import ddmd.globals;
import ddmd.errors;

enum LOG = false;

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
extern (C++) void scanMachObjModule(void* pctx, void function(void* pctx, char* name, int pickAny) pAddSymbol, void* base, size_t buflen, const(char)* module_name, Loc loc)
{
    static if (LOG)
    {
        printf("scanMachObjModule(%s)\n", module_name);
    }
    ubyte* buf = cast(ubyte*)base;
    int reason = 0;
    uint32_t ncmds;
    mach_header* header = cast(mach_header*)buf;
    mach_header_64* header64 = null;
    /* First do sanity checks on object file
     */
    if (buflen < mach_header.sizeof)
    {
        reason = __LINE__;
    Lcorrupt:
        error(loc, "Mach-O object module %s corrupt, %d", module_name, reason);
        return;
    }
    if (header.magic == MH_MAGIC)
    {
        if (header.cputype != CPU_TYPE_I386)
        {
            error(loc, "Mach-O object module %s has cputype = %d, should be %d", module_name, header.cputype, CPU_TYPE_I386);
            return;
        }
        if (header.filetype != MH_OBJECT)
        {
            error(loc, "Mach-O object module %s has file type = %d, should be %d", module_name, header.filetype, MH_OBJECT);
            return;
        }
        if (buflen < mach_header.sizeof + header.sizeofcmds)
        {
            reason = __LINE__;
            goto Lcorrupt;
        }
        ncmds = header.ncmds;
    }
    else if (header.magic == MH_MAGIC_64)
    {
        header64 = cast(mach_header_64*)buf;
        if (buflen < mach_header_64.sizeof)
            goto Lcorrupt;
        if (header64.cputype != CPU_TYPE_X86_64)
        {
            error(loc, "Mach-O object module %s has cputype = %d, should be %d", module_name, header64.cputype, CPU_TYPE_X86_64);
            return;
        }
        if (header64.filetype != MH_OBJECT)
        {
            error(loc, "Mach-O object module %s has file type = %d, should be %d", module_name, header64.filetype, MH_OBJECT);
            return;
        }
        if (buflen < mach_header_64.sizeof + header64.sizeofcmds)
        {
            reason = __LINE__;
            goto Lcorrupt;
        }
        ncmds = header64.ncmds;
    }
    else
    {
        reason = __LINE__;
        goto Lcorrupt;
    }
    segment_command* segment_commands = null;
    segment_command_64* segment_commands64 = null;
    symtab_command* symtab_commands = null;
    dysymtab_command* dysymtab_commands = null;
    // Commands immediately follow mach_header
    char* commands = cast(char*)buf + (header.magic == MH_MAGIC_64 ? mach_header_64.sizeof : mach_header.sizeof);
    for (uint32_t i = 0; i < ncmds; i++)
    {
        load_command* command = cast(load_command*)commands;
        //printf("cmd = 0x%02x, cmdsize = %u\n", command->cmd, command->cmdsize);
        switch (command.cmd)
        {
        case LC_SEGMENT:
            segment_commands = cast(segment_command*)command;
            break;
        case LC_SEGMENT_64:
            segment_commands64 = cast(segment_command_64*)command;
            break;
        case LC_SYMTAB:
            symtab_commands = cast(symtab_command*)command;
            break;
        case LC_DYSYMTAB:
            dysymtab_commands = cast(dysymtab_command*)command;
            break;
        default:
            break;
        }
        commands += command.cmdsize;
    }
    if (symtab_commands)
    {
        // Get pointer to string table
        char* strtab = cast(char*)buf + symtab_commands.stroff;
        if (buflen < symtab_commands.stroff + symtab_commands.strsize)
        {
            reason = __LINE__;
            goto Lcorrupt;
        }
        if (header.magic == MH_MAGIC_64)
        {
            // Get pointer to symbol table
            nlist_64* symtab = cast(nlist_64*)(cast(char*)buf + symtab_commands.symoff);
            if (buflen < symtab_commands.symoff + symtab_commands.nsyms * nlist_64.sizeof)
            {
                reason = __LINE__;
                goto Lcorrupt;
            }
            // For each symbol
            for (int i = 0; i < symtab_commands.nsyms; i++)
            {
                nlist_64* s = symtab + i;
                char* name = strtab + s.n_strx;
                if (s.n_type & N_STAB)
                {
                    // values in /usr/include/mach-o/stab.h
                    //printf(" N_STAB");
                }
                else
                {
                    version (none)
                    {
                        if (s.n_type & N_PEXT)
                        {
                        }
                        if (s.n_type & N_EXT)
                        {
                        }
                    }
                    switch (s.n_type & N_TYPE)
                    {
                    case N_UNDF:
                        if (s.n_type & N_EXT && s.n_value != 0) // comdef
                            (*pAddSymbol)(pctx, name, 1);
                        break;
                    case N_ABS:
                        break;
                    case N_SECT:
                        if (s.n_type & N_EXT) /*&& !(s->n_desc & N_REF_TO_WEAK)*/
                            (*pAddSymbol)(pctx, name, 1);
                        break;
                    case N_PBUD:
                        break;
                    case N_INDR:
                        break;
                    default:
                        break;
                    }
                }
            }
        }
        else
        {
            // Get pointer to symbol table
            nlist* symtab = cast(nlist*)(cast(char*)buf + symtab_commands.symoff);
            if (buflen < symtab_commands.symoff + symtab_commands.nsyms * nlist.sizeof)
            {
                reason = __LINE__;
                goto Lcorrupt;
            }
            // For each symbol
            for (int i = 0; i < symtab_commands.nsyms; i++)
            {
                nlist* s = symtab + i;
                char* name = strtab + s.n_strx;
                if (s.n_type & N_STAB)
                {
                    // values in /usr/include/mach-o/stab.h
                    //printf(" N_STAB");
                }
                else
                {
                    version (none)
                    {
                        if (s.n_type & N_PEXT)
                        {
                        }
                        if (s.n_type & N_EXT)
                        {
                        }
                    }
                    switch (s.n_type & N_TYPE)
                    {
                    case N_UNDF:
                        if (s.n_type & N_EXT && s.n_value != 0) // comdef
                            (*pAddSymbol)(pctx, name, 1);
                        break;
                    case N_ABS:
                        break;
                    case N_SECT:
                        if (s.n_type & N_EXT) /*&& !(s->n_desc & N_REF_TO_WEAK)*/
                            (*pAddSymbol)(pctx, name, 1);
                        break;
                    case N_PBUD:
                        break;
                    case N_INDR:
                        break;
                    default:
                        break;
                    }
                }
            }
        }
    }
}

enum CPU_TYPE_I386 = 7;
enum CPU_TYPE_X86_64 = CPU_TYPE_I386 | 0x1000000;

enum MH_OBJECT = 0x1;

struct segment_command
{
    uint32_t cmd;
    uint32_t cmdsize;
    char[16] segname;
    uint32_t vmaddr;
    uint32_t vmsize;
    uint32_t fileoff;
    uint32_t filesize;
    int32_t  maxprot;
    int32_t  initprot;
    uint32_t nsects;
    uint32_t flags;
}

struct segment_command_64
{
    uint32_t cmd;
    uint32_t cmdsize;
    char[16] segname;
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    uint64_t filesize;
    int32_t  maxprot;
    int32_t  initprot;
    uint32_t nsects;
    uint32_t flags;
}

struct symtab_command
{
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t symoff;
    uint32_t nsyms;
    uint32_t stroff;
    uint32_t strsize;
}

struct dysymtab_command
{
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t ilocalsym;
    uint32_t nlocalsym;
    uint32_t iextdefsym;
    uint32_t nextdefsym;
    uint32_t iundefsym;
    uint32_t nundefsym;
    uint32_t tocoff;
    uint32_t ntoc;
    uint32_t modtaboff;
    uint32_t nmodtab;
    uint32_t extrefsymoff;
    uint32_t nextrefsyms;
    uint32_t indirectsymoff;
    uint32_t nindirectsyms;
    uint32_t extreloff;
    uint32_t nextrel;
    uint32_t locreloff;
    uint32_t nlocrel;
}

enum LC_SEGMENT    = 1;
enum LC_SYMTAB     = 2;
enum LC_DYSYMTAB   = 11;
enum LC_SEGMENT_64 = 0x19;

struct load_command
{
    uint32_t cmd;
    uint32_t cmdsize;
}

enum N_EXT  = 1;
enum N_STAB = 0xE0;
enum N_PEXT = 0x10;
enum N_TYPE = 0x0E;
enum N_UNDF = 0;
enum N_ABS  = 2;
enum N_INDR = 10;
enum N_PBUD = 12;
enum N_SECT = 14;

struct nlist
{
    int32_t n_strx;
    uint8_t n_type;
    uint8_t n_sect;
    int16_t n_desc;
    uint32_t n_value;
};

struct nlist_64
{
    uint32_t n_strx;
    uint8_t n_type;
    uint8_t n_sect;
    uint16_t n_desc;
    uint64_t n_value;
}
