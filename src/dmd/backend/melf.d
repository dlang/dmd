
/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Translation to D of Linux's melf.h
 *
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/melf.d, backend/melf.d)
 */

module dmd.backend.melf;

/* ELF file format */

alias Elf32_Half  = ushort;
alias Elf32_Word  = uint;
alias Elf32_Sword = int;
alias Elf32_Addr  = uint;
alias Elf32_Off   = uint;
alias elf_u8_f32  = uint;

enum EI_NIDENT = 16;

nothrow:
@safe:

// EHident
        enum EI_MAG0         = 0;       /* Identification byte offset 0*/
        enum EI_MAG1         = 1;       /* Identification byte offset 1*/
        enum EI_MAG2         = 2;       /* Identification byte offset 2*/
        enum EI_MAG3         = 3;       /* Identification byte offset 3*/
            enum ELFMAG0     = 0x7f;    /* Magic number byte 0 */
            enum ELFMAG1     = 'E';     /* Magic number byte 1 */
            enum ELFMAG2     = 'L';     /* Magic number byte 2 */
            enum ELFMAG3     = 'F';     /* Magic number byte 3 */

        enum EI_CLASS        = 4;       /* File class byte offset 4 */
            enum ELFCLASSNONE = 0;      // invalid
            enum ELFCLASS32  = 1;       /* 32-bit objects */
            enum ELFCLASS64  = 2;       /* 64-bit objects */

        enum EI_DATA         = 5;       /* Data encoding byte offset 5 */
            enum ELFDATANONE = 0;       // invalid
            enum ELFDATA2LSB = 1;       /* 2's comp,lsb low address */
            enum ELFDATA2MSB = 2;       /* 2's comp,msb low address */

        enum EI_VERSION      = 6;       /* Header version byte offset 6 */
            //enum EV_CURRENT        = 1;       /* Current header format */

        enum EI_OSABI        = 7;       /* OS ABI  byte offset 7 */
            enum ELFOSABI_SYSV       = 0;       /* UNIX System V ABI */
            enum ELFOSABI_HPUX       = 1;       /* HP-UX */
            enum ELFOSABI_NETBSD     = 2;
            enum ELFOSABI_LINUX      = 3;
            enum ELFOSABI_FREEBSD    = 9;
            enum ELFOSABI_OPENBSD    = 12;
            enum ELFOSABI_ARM        = 97;      /* ARM */
            enum ELFOSABI_STANDALONE = 255;     /* Standalone/embedded */

        enum EI_ABIVERSION   = 8;   /* ABI version byte offset 8 */

        enum EI_PAD  = 9;           /* Byte to start of padding */

// e_type
        enum ET_NONE     = 0;       /* No specified file type */
        enum ET_REL      = 1;       /* Relocatable object file */
        enum ET_EXEC     = 2;       /* Executable file */
        enum ET_DYN      = 3;       /* Dynamic link object file */
        enum ET_CORE     = 4;       /* Core file */
        enum ET_LOPROC   = 0xff00;  /* Processor low index */
        enum ET_HIPROC   = 0xffff;  /* Processor hi index */

// e_machine
        enum EM_386      = 3;       /* Intel 80386 */
        enum EM_486      = 6;       /* Intel 80486 */
        enum EM_X86_64   = 62;      // Advanced Micro Devices X86-64 processor

// e_version
            enum EV_NONE     = 0;   // invalid version
            enum EV_CURRENT  = 1;   // Current file format

// e_ehsize
        enum EH_HEADER_SIZE = 0x34;

// e_phentsize
        enum EH_PHTENT_SIZE = 0x20;

// e_shentsize
        enum EH_SHTENT_SIZE = 0x28;

struct Elf32_Ehdr
    {
    ubyte[EI_NIDENT] EHident; /* Header identification info */
    Elf32_Half e_type;             /* Object file type */
    Elf32_Half e_machine;          /* Machine architecture */
    Elf32_Word e_version;              /* File format version */
    Elf32_Addr e_entry;                /* Entry point virtual address */
    Elf32_Off e_phoff;                /* Program header table(PHT)offset */
    Elf32_Off e_shoff;                /* Section header table(SHT)offset */
    Elf32_Word e_flags;                /* Processor-specific flags */
    Elf32_Half e_ehsize;               /* Size of ELF header (bytes) */
    Elf32_Half e_phentsize;            /* Size of PHT (bytes) */
    Elf32_Half e_phnum;                /* Number of PHT entries */
    Elf32_Half e_shentsize;            /* Size of SHT entry in bytes */
    Elf32_Half e_shnum;                /* Number of SHT entries */
    Elf32_Half e_shstrndx;             /* SHT index for string table */
  }


/* Section header.  */

// sh_type
        enum SHT_NULL         = 0;          /* SHT entry unused */
        enum SHT_PROGBITS     = 1;          /* Program defined data */
        enum SHT_SYMTAB       = 2;          /* Symbol table */
        enum SHT_STRTAB       = 3;          /* String table */
        enum SHT_RELA         = 4;          /* Relocations with addends */
        enum SHT_HASHTAB      = 5;          /* Symbol hash table */
        enum SHT_DYNAMIC      = 6;          /* String table for dynamic symbols */
        enum SHT_NOTE         = 7;          /* Notes */
        enum SHT_RESDATA      = 8;          /* Reserved data space */
        enum SHT_NOBITS       = SHT_RESDATA;
        enum SHT_REL          = 9;          /* Relocations no addends */
        enum SHT_RESTYPE      = 10;         /* Reserved section type*/
        enum SHT_DYNTAB       = 11;         /* Dynamic linker symbol table */
        enum SHT_INIT_ARRAY   = 14;         /* Array of constructors */
        enum SHT_FINI_ARRAY   = 15;         /* Array of destructors */
        enum SHT_GROUP        = 17;         /* Section group (COMDAT) */
        enum SHT_SYMTAB_SHNDX = 18;         /* Extended section indices */

// sh_flags
        enum SHF_WRITE       = (1 << 0);    /* Writable during execution */
        enum SHF_ALLOC       = (1 << 1);    /* In memory during execution */
        enum SHF_EXECINSTR   = (1 << 2);    /* Executable machine instructions*/
        enum SHF_MERGE       = 0x10;
        enum SHF_STRINGS     = 0x20;
        enum SHF_INFO_LINK   = 0x40;
        enum SHF_LINK_ORDER  = 0x80;
        enum SHF_OS_NONCONFORMING  = 0x100;
        enum SHF_GROUP       = 0x200;       // Member of a section group
        enum SHF_TLS         = 0x400;       /* Thread local */
        enum SHF_MASKPROC    = 0xf0000000;  /* Mask for processor-specific */

struct Elf32_Shdr
{
  Elf32_Word   sh_name;                /* String table offset for section name */
  Elf32_Word   sh_type;                /* Section type */
  Elf32_Word   sh_flags;               /* Section attribute flags */
  Elf32_Addr   sh_addr;                /* Starting virtual memory address */
  Elf32_Off    sh_offset;              /* Offset to section in file */
  Elf32_Word   sh_size;                /* Size of section */
  Elf32_Word   sh_link;                /* Index to optional related section */
  Elf32_Word   sh_info;                /* Optional extra section information */
  Elf32_Word   sh_addralign;           /* Required section alignment */
  Elf32_Word   sh_entsize;             /* Size of fixed size section entries */
}

// Special Section Header Table Indices
enum SHN_UNDEF       = 0;               /* Undefined section */
enum SHN_LORESERVE   = 0xff00;          /* Start of reserved indices */
enum SHN_LOPROC      = 0xff00;          /* Start of processor-specific */
enum SHN_HIPROC      = 0xff1f;          /* End of processor-specific */
enum SHN_LOOS        = 0xff20;          /* Start of OS-specific */
enum SHN_HIOS        = 0xff3f;          /* End of OS-specific */
enum SHN_ABS         = 0xfff1;          /* Absolute value for symbol references */
enum SHN_COMMON      = 0xfff2;          /* Symbol defined in common section */
enum SHN_XINDEX      = 0xffff;          /* Index is in extra table.  */
enum SHN_HIRESERVE   = 0xffff;          /* End of reserved indices */


/* Symbol Table */

   // st_info

        ubyte ELF32_ST_BIND(ubyte s) { return s >> 4; }
        ubyte ELF32_ST_TYPE(ubyte s) { return s & 0xf; }
        ubyte ELF32_ST_INFO(ubyte b, ubyte t) { return cast(ubyte)((b << 4) + (t & 0xf)); }

        enum STB_LOCAL       = 0;           /* Local symbol */
        enum STB_GLOBAL      = 1;           /* Global symbol */
        enum STB_WEAK        = 2;           /* Weak symbol */
        enum ST_NUM_BINDINGS = 3;           /* Number of defined types.  */
        enum STB_LOOS        = 10;          /* Start of OS-specific */
        enum STB_HIOS        = 12;          /* End of OS-specific */
        enum STB_LOPROC      = 13;          /* Start of processor-specific */
        enum STB_HIPROC      = 15;          /* End of processor-specific */

        enum STT_NOTYPE      = 0;           /* Symbol type is unspecified */
        enum STT_OBJECT      = 1;           /* Symbol is a data object */
        enum STT_FUNC        = 2;           /* Symbol is a code object */
        enum STT_SECTION     = 3;           /* Symbol associated with a section */
        enum STT_FILE        = 4;           /* Symbol's name is file name */
        enum STT_COMMON      = 5;
        enum STT_TLS         = 6;
        enum STT_NUM         = 5;           /* Number of defined types.  */
        enum STT_LOOS        = 11;          /* Start of OS-specific */
        enum STT_HIOS        = 12;          /* End of OS-specific */
        enum STT_LOPROC      = 13;          /* Start of processor-specific */
        enum STT_HIPROC      = 15;          /* End of processor-specific */

        enum STV_DEFAULT     = 0;           /* Default symbol visibility rules */
        enum STV_INTERNAL    = 1;           /* Processor specific hidden class */
        enum STV_HIDDEN      = 2;           /* Sym unavailable in other modules */
        enum STV_PROTECTED   = 3;           /* Not preemptible, not exported */


struct Elf32_Sym
{
    Elf32_Word st_name;                /* string table index for symbol name */
    Elf32_Addr st_value;               /* Associated symbol value */
    Elf32_Word st_size;                /* Symbol size */
    ubyte st_info;                     /* Symbol type and binding */
    ubyte st_other;                    /* Currently not defined */
    Elf32_Half st_shndx;       /* SHT index for symbol definition */
}


/* Relocation table entry without addend (in section of type SHT_REL).  */


// r_info

        // 386 Relocation types

        uint ELF32_R_SYM(uint i) { return i >> 8; }       /* Symbol idx */
        uint ELF32_R_TYPE(uint i) { return i & 0xff; }     /* Type of relocation */
        uint ELF32_R_INFO(uint i, uint t) { return ((i << 8) + (t & 0xff)); }

        enum R_386_NONE    = 0;              /* No reloc */
        enum R_386_32      = 1;              /* Symbol value 32 bit  */
        enum R_386_PC32    = 2;              /* PC relative 32 bit */
        enum R_386_GOT32   = 3;              /* 32 bit GOT entry */
        enum R_386_PLT32   = 4;              /* 32 bit PLT address */
        enum R_386_COPY    = 5;              /* Copy symbol at runtime */
        enum R_386_GLOB_DAT = 6;              /* Create GOT entry */
        enum R_386_JMP_SLOT = 7;              /* Create PLT entry */
        enum R_386_RELATIVE = 8;              /* Adjust by program base */
        enum R_386_GOTOFF  = 9;              /* 32 bit offset to GOT */
        enum R_386_GOTPC   = 10;             /* 32 bit PC relative offset to GOT */
        enum R_386_TLS_TPOFF = 14;
        enum R_386_TLS_IE    = 15;
        enum R_386_TLS_GOTIE = 16;
        enum R_386_TLS_LE    = 17;           /* negative offset relative to static TLS */
        enum R_386_TLS_GD    = 18;
        enum R_386_TLS_LDM   = 19;
        enum R_386_TLS_GD_32 = 24;
        enum R_386_TLS_GD_PUSH  = 25;
        enum R_386_TLS_GD_CALL  = 26;
        enum R_386_TLS_GD_POP   = 27;
        enum R_386_TLS_LDM_32   = 28;
        enum R_386_TLS_LDM_PUSH = 29;
        enum R_386_TLS_LDM_CALL = 30;
        enum R_386_TLS_LDM_POP  = 31;
        enum R_386_TLS_LDO_32   = 32;
        enum R_386_TLS_IE_32    = 33;
        enum R_386_TLS_LE_32    = 34;
        enum R_386_TLS_DTPMOD32 = 35;
        enum R_386_TLS_DTPOFF32 = 36;
        enum R_386_TLS_TPOFF32  = 37;

struct Elf32_Rel
{
    Elf32_Addr r_offset;               /* Address */
    Elf32_Word r_info;                 /* Relocation type and symbol index */
}

/* stabs debug records */

// DBtype
        enum DBT_UNDEF       = 0x00;       /* undefined symbol */
        enum DBT_EXT         = 0x01;       /* exernal modifier */
        enum DBT_ABS         = 0x02;       /* absolute */
        enum DBT_TEXT        = 0x04;       /* code text */
        enum DBT_DATA        = 0x06;       /* data */
        enum DBT_BSS         = 0x08;       /* BSS */
        enum DBT_INDR        = 0x0a;       /* indirect to another symbol */
        enum DBT_COMM        = 0x12;       /* common -visible after shr'd lib link */
        enum DBT_SETA        = 0x14;       /* Absolue set element */
        enum DBT_SETT        = 0x16;       /* code text segment set element */
        enum DBT_SETD        = 0x18;       /* data segment set element */
        enum DBT_SETB        = 0x1a;       /* BSS segment set element */
        enum DBT_SETV        = 0x1c;       /* Pointer to set vector */
        enum DBT_WARNING     = 0x1e;       /* print warning during link */
        enum DBT_FN          = 0x1f;       /* name of object file */

        enum DBT_GSYM        = 0x20;       /* global symbol */
        enum DBT_FUN         = 0x24;       /* function name */
        enum DBT_STSYM       = 0x26;       /* static data */
        enum DBT_LCSYM       = 0x28;       /* static bss */
        enum DBT_MAIN        = 0x2a;       /* main routine */
        enum DBT_RO          = 0x2c;       /* read only */
        enum DBT_OPT         = 0x3c;       /* target option? */
        enum DBT_REG         = 0x40;       /* register variable */
        enum DBT_TLINE       = 0x44;       /* text line number */
        enum DBT_DLINE       = 0x46;       /* dat line number */
        enum DBT_BLINE       = 0x48;       /* bss line number */
        enum DBT_STUN        = 0x62;       /* structure or union */
        enum DBT_SRCF        = 0x64;       /* source file */
        enum DBT_AUTO        = 0x80;       /* stack variable */
        enum DBT_TYPE        = 0x80;       /* type definition */
        enum DBT_INCS        = 0x84;       /* include file start */
        enum DBT_PARAM       = 0xa0;       /* parameter */
        enum DBT_INCE        = 0xa2;       /* include file end */


struct elf_stab
{
    Elf32_Word DBstring;               /* string table index for the symbol */
    elf_u8_f32  DBtype;                 /* type of the symbol */
    elf_u8_f32  DBmisc;                 /* misc. info */
    Elf32_Half DBdesc;                 /* description field */
    Elf32_Word DBvalu;                 /* symbol value */
}


/* Program header.  */

// PHtype
        enum PHT_NULL       = 0;         /* SHT entry unused */

struct Elf32_Phdr
{
  Elf32_Word   PHtype;                 /* Program type */
  Elf32_Off   PHoff;                  /* Offset to segment in file */
  Elf32_Addr   PHvaddr;                /* Starting virtual memory address */
  Elf32_Addr   PHpaddr;                /* Starting absolute memory address */
  Elf32_Word   PHfilesz;               /* Size of file image */
  Elf32_Word   PHmemsz;                /* Size of memory image */
  Elf32_Word   PHflags;                /* Program attribute flags */
  Elf32_Word   PHalign;                /* Program loading alignment */
}



/* Legal values for sh_flags (section flags).  */

/***************************** 64 bit Elf *****************************************/

alias Elf64_Addr   = ulong;
alias Elf64_Off    = ulong;
alias Elf64_Xword  = ulong;
alias Elf64_Sxword = long;
alias Elf64_Sword  = int;
alias Elf64_Word   = uint;
alias Elf64_Half   = ushort;

struct Elf64_Ehdr
{
    ubyte[EI_NIDENT] EHident; /* Header identification info */
    Elf64_Half  e_type;
    Elf64_Half  e_machine;
    Elf64_Word  e_version;
    Elf64_Addr  e_entry;
    Elf64_Off   e_phoff;
    Elf64_Off   e_shoff;
    Elf64_Word  e_flags;
    Elf64_Half  e_ehsize;
    Elf64_Half  e_phentsize;
    Elf64_Half  e_phnum;
    Elf64_Half  e_shentsize;
    Elf64_Half  e_shnum;
    Elf64_Half  e_shstrndx;
}

struct Elf64_Shdr
{
    Elf64_Word  sh_name;
    Elf64_Word  sh_type;
    Elf64_Xword sh_flags;
    Elf64_Addr  sh_addr;
    Elf64_Off   sh_offset;
    Elf64_Xword sh_size;
    Elf64_Word  sh_link;
    Elf64_Word  sh_info;
    Elf64_Xword sh_addralign;
    Elf64_Xword sh_entsize;
}

struct Elf64_Phdr
{
    Elf64_Word  p_type;
    Elf64_Word  p_flags;
    Elf64_Off   p_offset;
    Elf64_Addr  p_vaddr;
    Elf64_Addr  p_paddr;
    Elf64_Xword p_filesz;
    Elf64_Xword p_memsz;
    Elf64_Xword p_align;
}

struct Elf64_Sym
{
    Elf64_Word  st_name;
    ubyte       st_info;
    ubyte       st_other;
    Elf64_Half  st_shndx;
    Elf64_Addr  st_value;
    Elf64_Xword st_size;
}

ubyte ELF64_ST_BIND(ubyte s) { return ELF32_ST_BIND(s); }
ubyte ELF64_ST_TYPE(ubyte s) { return ELF32_ST_TYPE(s); }
ubyte ELF64_ST_INFO(ubyte b, ubyte t) { return ELF32_ST_INFO(b,t); }

// r_info
        uint ELF64_R_SYM(ulong i)  { return cast(Elf64_Word)(i>>32); }
        uint ELF64_R_TYPE(ulong i) { return cast(Elf64_Word)(i & 0xFFFF_FFFF); }
        ulong ELF64_R_INFO(ulong s, ulong t) { return ((cast(Elf64_Xword)s)<<32)|cast(Elf64_Word)t; }

        // X86-64 Relocation types

        enum R_X86_64_NONE      = 0;     // -- No relocation
        enum R_X86_64_64        = 1;     // 64 Direct 64 bit
        enum R_X86_64_PC32      = 2;     // 32 PC relative 32 bit signed
        enum R_X86_64_GOT32     = 3;     // 32 32 bit GOT entry
        enum R_X86_64_PLT32     = 4;     // 32 bit PLT address
        enum R_X86_64_COPY      = 5;     // -- Copy symbol at runtime
        enum R_X86_64_GLOB_DAT  = 6;     // 64 Create GOT entry
        enum R_X86_64_JUMP_SLOT = 7;     // 64 Create PLT entry
        enum R_X86_64_RELATIVE  = 8;     // 64 Adjust by program base
        enum R_X86_64_GOTPCREL  = 9;     // 32 32 bit signed pc relative offset to GOT
        enum R_X86_64_32       = 10;     // 32 Direct 32 bit zero extended
        enum R_X86_64_32S      = 11;     // 32 Direct 32 bit sign extended
        enum R_X86_64_16       = 12;     // 16 Direct 16 bit zero extended
        enum R_X86_64_PC16     = 13;     // 16 16 bit sign extended pc relative
        enum R_X86_64_8        = 14;     //  8 Direct 8 bit sign extended
        enum R_X86_64_PC8      = 15;     //  8 8 bit sign extended pc relative
        enum R_X86_64_DTPMOD64 = 16;     // 64 ID of module containing symbol
        enum R_X86_64_DTPOFF64 = 17;     // 64 Offset in TLS block
        enum R_X86_64_TPOFF64  = 18;     // 64 Offset in initial TLS block
        enum R_X86_64_TLSGD    = 19;     // 32 PC relative offset to GD GOT block
        enum R_X86_64_TLSLD    = 20;     // 32 PC relative offset to LD GOT block
        enum R_X86_64_DTPOFF32 = 21;     // 32 Offset in TLS block
        enum R_X86_64_GOTTPOFF = 22;     // 32 PC relative offset to IE GOT entry
        enum R_X86_64_TPOFF32  = 23;     // 32 Offset in initial TLS block
        enum R_X86_64_PC64     = 24;     // 64
        enum R_X86_64_GOTOFF64 = 25;     // 64
        enum R_X86_64_GOTPC32  = 26;     // 32
        enum R_X86_64_GNU_VTINHERIT = 250;    // GNU C++ hack
        enum R_X86_64_GNU_VTENTRY   = 251;    // GNU C++ hack

struct Elf64_Rel
{
    Elf64_Addr  r_offset;
    Elf64_Xword r_info;

}

struct Elf64_Rela
{
    Elf64_Addr   r_offset;
    Elf64_Xword  r_info;
    Elf64_Sxword r_addend;
}

// Section Group Flags
enum GRP_COMDAT   = 1;
enum GRP_MASKOS   = 0x0ff0_0000;
enum GRP_MASKPROC = 0xf000_0000;


