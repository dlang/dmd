
/* Mach-O object file format */

#if __APPLE__

#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach-o/stab.h>
#include <mach-o/reloc.h>
//#include <mach-o/x86_64/reloc.h>

#ifndef S_DTRACE_DOF
        #define S_DTRACE_DOF                    15
#endif

#else

#include <stdint.h>

typedef int cpu_type_t;
typedef int cpu_subtype_t;
typedef int vm_prot_t;

struct mach_header
{
    uint32_t magic;
        #define MH_MAGIC 0xfeedface
        #define MH_CIGAM 0xcefaedfe
    cpu_type_t cputype;
        #define CPU_TYPE_I386   ((cpu_type_t)7)
        #define CPU_TYPE_X86_64 ((cpu_type_t)7 | 0x1000000)
        #define CPU_TYPE_POWERPC ((cpu_type_t)18)
        #define CPU_TYPE_POWERPC64 (CPU_TYPE_POWERPC | 0x1000000)
    cpu_subtype_t cpusubtype;
        #define CPU_SUBTYPE_POWERPC_ALL ((cpu_subtype_t)0)
        #define CPU_SUBTYPE_I386_ALL ((cpu_subtype_t)3)
    uint32_t filetype;
        #define MH_OBJECT       1
        #define MH_EXECUTE      2
        #define MH_BUNDLE       8
        #define MH_DYLIB        6
        #define MH_PRELOAD      5
        #define MH_CORE         4
        #define MH_DYLINKER     7
        #define MH_DSYM         10
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
        #define MH_NOUNDEFS             1
        #define MH_INCRLINK             2
        #define MH_DYLDLINK             4
        #define MH_TWOLEVEL             0x80
        #define MH_BINDATLOAD           8
        #define MH_PREBOUND             0x10
        #define MH_PREBINDABLE          0x800
        #define MH_NOFIXPREBINDING      0x400
        #define MH_ALLMODSBOUND         0x1000
        #define MH_CANONICAL            0x4000
        #define MH_SPLIT_SEGS           0x20
        #define MH_FORCE_FLAT           0x100
        #define MH_SUBSECTIONS_VIA_SYMBOLS      0x2000
        #define MH_NOMULTIDEFS          0x200
};

struct mach_header_64
{
    uint32_t magic;
        #define MH_MAGIC_64 0xfeedfacf
        #define MH_CIGAM_64 0xcffaedfe
    cpu_type_t cputype;
    cpu_subtype_t cpusubtype;
    uint32_t filetype;
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
    uint32_t reserved;
};

struct load_command
{
    uint32_t cmd;
        #define LC_SEGMENT      1
        #define LC_SYMTAB       2
        #define LC_DYSYMTAB     11
        #define LC_SEGMENT_64   0x19
    uint32_t cmdsize;
};

struct uuid_command
{
    uint32_t cmd;
    uint32_t cmdsize;
    uint8_t uuid[16];
};

struct segment_command
{
    uint32_t cmd;
    uint32_t cmdsize;
    char segname[16];
    uint32_t vmaddr;
    uint32_t vmsize;
    uint32_t fileoff;
    uint32_t filesize;
    vm_prot_t maxprot;
    vm_prot_t initprot;
    uint32_t nsects;
    uint32_t flags;
        #define SG_HIGHVM       1
        #define SG_FVMLIB       2
        #define SG_NORELOC      4
        #define SG_PROTECTED_VERSION_1  8
};

struct segment_command_64
{
    uint32_t cmd;
    uint32_t cmdsize;
    char segname[16];
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    uint64_t filesize;
    vm_prot_t maxprot;
    vm_prot_t initprot;
    uint32_t nsects;
    uint32_t flags;
};

struct section
{
    char sectname[16];
    char segname[16];
    uint32_t addr;
    uint32_t size;
    uint32_t offset;
    uint32_t align;
    uint32_t reloff;
    uint32_t nreloc;
    uint32_t flags;
        #define SECTION_TYPE 0xFF
        #define SECTION_ATTRIBUTES 0xFFFFFF00

        #define S_REGULAR               0
        #define S_ZEROFILL              1
        #define S_CSTRING_LITERALS      2
        #define S_4BYTE_LITERALS        3
        #define S_8BYTE_LITERALS        4
        #define S_LITERAL_POINTERS      5

        #define S_NON_LAZY_SYMBOL_POINTERS      6
        #define S_LAZY_SYMBOL_POINTERS          7
        #define S_SYMBOL_STUBS                  8
        #define S_MOD_INIT_FUNC_POINTERS        9
        #define S_MOD_TERM_FUNC_POINTERS        10
        #define S_COALESCED                     11
        #define S_GB_ZEROFILL                   12
        #define S_INTERPOSING                   13
        #define S_16BYTE_LITERALS               14
        #define S_DTRACE_DOF                    15

        #define S_THREAD_LOCAL_REGULAR          0x11 // template of initial values for TLVs
        #define S_THREAD_LOCAL_ZEROFILL         0x12 // template of initial values for TLVs
        #define S_THREAD_LOCAL_VARIABLES        0x13 // TLV descriptors

        #define SECTION_ATTRIBUTES_USR          0xFF000000
        #define S_ATTR_PURE_INSTRUCTIONS        0x80000000
        #define S_ATTR_NO_TOC                   0x40000000
        #define S_ATTR_STRIP_STATIC_SYMS        0x20000000
        #define S_ATTR_NO_DEAD_STRIP            0x10000000
        #define S_ATTR_LIVE_SUPPORT             0x8000000
        #define S_ATTR_SELF_MODIFYING_CODE      0x4000000
        #define S_ATTR_DEBUG                    0x2000000

        #define SECTION_ATTRIBUTES_SYS          0xFFFF00
        #define S_ATTR_SOME_INSTRUCTIONS        0x000400
        #define S_ATTR_EXT_RELOC                0x000200
        #define S_ATTR_LOC_RELOC                0x000100

    uint32_t reserved1;
    uint32_t reserved2;
};

struct section_64
{
    char sectname[16];
    char segname[16];
    uint64_t addr;
    uint64_t size;
    uint32_t offset;
    uint32_t align;
    uint32_t reloff;
    uint32_t nreloc;
    uint32_t flags;
    uint32_t reserved1;
    uint32_t reserved2;
    uint32_t reserved3;
};

struct twolevel_hints_command
{
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t offset;
    uint32_t nhints;
};

struct twolevel_hint
{
    uint32_t isub_image:8, itoc:24;
};

struct symtab_command
{
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t symoff;
    uint32_t nsyms;
    uint32_t stroff;
    uint32_t strsize;
};

struct nlist
{
    union
    {
        int32_t n_strx;
    } n_un;
    uint8_t n_type;
        #define N_EXT   1
        #define N_STAB  0xE0
        #define N_PEXT  0x10
        #define N_TYPE  0x0E
                #define N_UNDF  0
                #define N_ABS   2
                #define N_INDR  10
                #define N_PBUD  12
                #define N_SECT  14
    uint8_t n_sect;
    int16_t n_desc;
    uint32_t n_value;
};

struct nlist_64
{
    union
    {
        uint32_t n_strx;
    } n_un;
    uint8_t n_type;
    uint8_t n_sect;
    uint16_t n_desc;
    uint64_t n_value;
};

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
};

struct relocation_info
{
    int32_t r_address;
        #define R_SCATTERED 0x80000000
    uint32_t r_symbolnum:24,
        r_pcrel:1,
        r_length:2,
        r_extern:1,
        r_type:4;
            // for i386
            #define GENERIC_RELOC_VANILLA               0
            #define GENERIC_RELOC_PAIR                  1
            #define GENERIC_RELOC_SECTDIFF              2
            #define GENERIC_RELOC_PB_LA_PTR             3
            #define GENERIC_RELOC_LOCAL_SECTDIFF        4

            // for x86_64
            #define X86_64_RELOC_UNSIGNED               0
            #define X86_64_RELOC_SIGNED                 1
            #define X86_64_RELOC_BRANCH                 2
            #define X86_64_RELOC_GOT_LOAD               3
            #define X86_64_RELOC_GOT                    4
            #define X86_64_RELOC_SUBTRACTOR             5
            #define X86_64_RELOC_SIGNED_1               6
            #define X86_64_RELOC_SIGNED_2               7
            #define X86_64_RELOC_SIGNED_4               8
            #define X86_64_RELOC_TLV                    9 // for thread local variables
};

struct scattered_relocation_info
{
    #if 1 // LITTLE_ENDIAN for x86
        uint32_t r_address:24,
        r_type:4,
        r_length:2,
        r_pcrel:1,
        r_scattered:1;
        int32_t r_value;
    #else // BIG_ENDIAN
        uint32_t r_scattered:1,
        r_pcrel:1,
        r_length:2,
        r_type:4,
        r_address:24;
        int32_t r_value;
    #endif
};

#endif
