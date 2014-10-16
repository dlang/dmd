/**
 * Copyright: Copyright Digital Mars 2010.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jacob Carlborg
 * Version: Initial created: Feb 20, 2010
 */

/*          Copyright Digital Mars 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.osx.mach.loader;

version (OSX):
extern (C):

struct mach_header
{
    uint magic;
    int  cputype;
    int  cpusubtype;
    uint filetype;
    uint ncmds;
    uint sizeofcmds;
    uint flags;
}

struct mach_header_64
{
    uint magic;
    int  cputype;
    int  cpusubtype;
    uint filetype;
    uint ncmds;
    uint sizeofcmds;
    uint flags;
    uint reserved;
}

enum uint MH_MAGIC      = 0xfeedface;
enum uint MH_CIGAM      = 0xcefaedfe;
enum uint MH_MAGIC_64   = 0xfeedfacf;
enum uint MH_CIGAM_64   = 0xcffaedfe;

enum SEG_PAGEZERO       = "__PAGEZERO";
enum SEG_TEXT           = "__TEXT";
enum SECT_TEXT          = "__text";
enum SECT_FVMLIB_INIT0  = "__fvmlib_init0";
enum SECT_FVMLIB_INIT1  = "__fvmlib_init1";
enum SEG_DATA           = "__DATA";
enum SECT_DATA          = "__data";
enum SECT_BSS           = "__bss";
enum SECT_COMMON        = "__common";
enum SEG_OBJC           = "__OBJC";
enum SECT_OBJC_SYMBOLS  = "__symbol_table";
enum SECT_OBJC_MODULES  = "__module_info";
enum SECT_OBJC_STRINGS  = "__selector_strs";
enum SECT_OBJC_REFS     = "__selector_refs";
enum SEG_ICON           = "__ICON";
enum SECT_ICON_HEADER   = "__header";
enum SECT_ICON_TIFF     = "__tiff";
enum SEG_LINKEDIT       = "__LINKEDIT";
enum SEG_UNIXSTACK      = "__UNIXSTACK";
enum SEG_IMPORT         = "__IMPORT";

struct section
{
    char[16] sectname;
    char[16] segname;
    uint     addr;
    uint     size;
    uint     offset;
    uint     align_;
    uint     reloff;
    uint     nreloc;
    uint     flags;
    uint     reserved1;
    uint     reserved2;
}

struct section_64
{
    char[16] sectname;
    char[16] segname;
    ulong    addr;
    ulong    size;
    uint     offset;
    uint     align_;
    uint     reloff;
    uint     nreloc;
    uint     flags;
    uint     reserved1;
    uint     reserved2;
    uint     reserved3;
}

