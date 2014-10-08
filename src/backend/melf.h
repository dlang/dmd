
#if __linux__

#include <elf.h>

#else

#include <stdint.h>

/* ELF file format */

typedef uint16_t Elf32_Half;
typedef uint32_t Elf32_Word;
typedef int32_t  Elf32_Sword;
typedef uint32_t Elf32_Addr;
typedef uint32_t Elf32_Off;
typedef uint32_t elf_u8_f32;

#define  EI_NIDENT 16
typedef struct
    {
    unsigned char EHident[EI_NIDENT]; /* Header identification info */
        #define EI_MAG0         0           /* Identification byte offset 0*/
        #define EI_MAG1         1           /* Identification byte offset 1*/
        #define EI_MAG2         2           /* Identification byte offset 2*/
        #define EI_MAG3         3           /* Identification byte offset 3*/
            #define ELFMAG0             0x7f    /* Magic number byte 0 */
            #define ELFMAG1             'E'     /* Magic number byte 1 */
            #define ELFMAG2             'L'     /* Magic number byte 2 */
            #define ELFMAG3             'F'     /* Magic number byte 3 */

        #define EI_CLASS        4       /* File class byte offset 4 */
            #define ELFCLASSNONE 0      // invalid
            #define ELFCLASS32  1       /* 32-bit objects */
            #define ELFCLASS64  2       /* 64-bit objects */

        #define EI_DATA         5       /* Data encoding byte offset 5 */
            #define ELFDATANONE 0       // invalid
            #define ELFDATA2LSB 1       /* 2's comp,lsb low address */
            #define ELFDATA2MSB 2       /* 2's comp,msb low address */

        #define EI_VERSION      6           /* Header version byte offset 6 */
            //#define EV_CURRENT        1       /* Current header format */

        #define EI_OSABI        7           /* OS ABI  byte offset 7 */
            #define ELFOSABI_SYSV       0       /* UNIX System V ABI */
            #define ELFOSABI_HPUX       1       /* HP-UX */
            #define ELFOSABI_NETBSD     2
            #define ELFOSABI_LINUX      3
            #define ELFOSABI_FREEBSD    9
            #define ELFOSABI_OPENBSD    12
            #define ELFOSABI_ARM        97      /* ARM */
            #define ELFOSABI_STANDALONE 255     /* Standalone/embedded */

        #define EI_ABIVERSION   8           /* ABI version byte offset 8 */

        #define EI_PAD  9           /* Byte to start of padding */

    Elf32_Half e_type;             /* Object file type */
        #define ET_NONE     0       /* No specified file type */
        #define ET_REL      1       /* Relocatable object file */
        #define ET_EXEC     2       /* Executable file */
        #define ET_DYN      3       /* Dynamic link object file */
        #define ET_CORE     4       /* Core file */
        #define ET_LOPROC   0xff00  /* Processor low index */
        #define ET_HIPROC   0xffff  /* Processor hi index */

    Elf32_Half e_machine;          /* Machine architecture */
        #define EM_386      3       /* Intel 80386 */
        #define EM_486      6       /* Intel 80486 */
        #define EM_X86_64   62      // Advanced Micro Devices X86-64 processor

    Elf32_Word e_version;              /* File format version */
            #define EV_NONE     0       // invalid version
            #define EV_CURRENT  1       // Current file format

    Elf32_Addr e_entry;                /* Entry point virtual address */
    Elf32_Off e_phoff;                /* Program header table(PHT)offset */
    Elf32_Off e_shoff;                /* Section header table(SHT)offset */
    Elf32_Word e_flags;                /* Processor-specific flags */
    Elf32_Half e_ehsize;               /* Size of ELF header (bytes) */
        #define EH_HEADER_SIZE 0x34
    Elf32_Half e_phentsize;            /* Size of PHT (bytes) */
        #define EH_PHTENT_SIZE 0x20
    Elf32_Half e_phnum;                /* Number of PHT entries */
    Elf32_Half e_shentsize;            /* Size of SHT entry in bytes */
        #define EH_SHTENT_SIZE 0x28
    Elf32_Half e_shnum;                /* Number of SHT entries */
    Elf32_Half e_shstrndx;             /* SHT index for string table */
  } Elf32_Ehdr;

/* Section header.  */

typedef struct
{
  Elf32_Word   sh_name;                /* String table offset for section name */
  Elf32_Word   sh_type;                /* Section type */
        #define SHT_NULL         0          /* SHT entry unused */
        #define SHT_PROGBITS     1          /* Program defined data */
        #define SHT_SYMTAB       2          /* Symbol table */
        #define SHT_STRTAB       3          /* String table */
        #define SHT_RELA         4          /* Relocations with addends */
        #define SHT_HASHTAB      5          /* Symbol hash table */
        #define SHT_DYNAMIC      6          /* String table for dynamic symbols */
        #define SHT_NOTE         7          /* Notes */
        #define SHT_RESDATA      8          /* Reserved data space */
        #define SHT_NOBITS       SHT_RESDATA
        #define SHT_REL          9          /* Relocations no addends */
        #define SHT_RESTYPE      10         /* Reserved section type*/
        #define SHT_DYNTAB       11         /* Dynamic linker symbol table */
        #define SHT_GROUP        17         /* Section group (COMDAT) */
        #define SHT_SYMTAB_SHNDX 18         /* Extended section indeces */
  Elf32_Word   sh_flags;               /* Section attribute flags */
        #define SHF_WRITE       (1 << 0)    /* Writable during execution */
        #define SHF_ALLOC       (1 << 1)    /* In memory during execution */
        #define SHF_EXECINSTR   (1 << 2)    /* Executable machine instructions*/
        #define SHF_GROUP       (1 << 9)    /* Member of a section group */
        #define SHF_TLS         (1 << 10)   /* Thread local */
        #define SHF_MASKPROC    0xf0000000  /* Mask for processor-specific */
  Elf32_Addr   sh_addr;                /* Starting virtual memory address */
  Elf32_Off   sh_offset;              /* Offset to section in file */
  Elf32_Word   sh_size;                /* Size of section */
  Elf32_Word   sh_link;                /* Index to optional related section */
  Elf32_Word   sh_info;                /* Optional extra section information */
  Elf32_Word   sh_addralign;           /* Required section alignment */
  Elf32_Word   sh_entsize;             /* Size of fixed size section entries */
} Elf32_Shdr;

// Special Section Header Table Indices
#define SHN_UNDEF       0               /* Undefined section */
#define SHN_LORESERVE   0xff00          /* Start of reserved indices */
#define SHN_LOPROC      0xff00          /* Start of processor-specific */
#define SHN_HIPROC      0xff1f          /* End of processor-specific */
#define SHN_LOOS        0xff20          /* Start of OS-specific */
#define SHN_HIOS        0xff3f          /* End of OS-specific */
#define SHN_ABS         0xfff1          /* Absolute value for symbol references */
#define SHN_COMMON      0xfff2          /* Symbol defined in common section */
#define SHN_XINDEX      0xffff          /* Index is in extra table.  */
#define SHN_HIRESERVE   0xffff          /* End of reserved indices */

/* Symbol Table */

typedef struct
{
    Elf32_Word st_name;                /* string table index for symbol name */
    Elf32_Addr st_value;               /* Associated symbol value */
    Elf32_Word st_size;                /* Symbol size */
    unsigned char st_info;              /* Symbol type and binding */
        #define ELF32_ST_BIND(s) ((s)>>4)
        #define ELF32_ST_TYPE(s) ((s)&0xf)
        #define ELF32_ST_INFO(b,t) (((b) << 4) + ((t) & 0xf))

        #define STB_LOCAL       0           /* Local symbol */
        #define STB_GLOBAL      1           /* Global symbol */
        #define STB_WEAK        2           /* Weak symbol */
        #define ST_NUM_BINDINGS 3           /* Number of defined types.  */
        #define STB_LOOS        10          /* Start of OS-specific */
        #define STB_HIOS        12          /* End of OS-specific */
        #define STB_LOPROC      13          /* Start of processor-specific */
        #define STB_HIPROC      15          /* End of processor-specific */

        #define STT_NOTYPE      0           /* Symbol type is unspecified */
        #define STT_OBJECT      1           /* Symbol is a data object */
        #define STT_FUNC        2           /* Symbol is a code object */
        #define STT_SECTION     3           /* Symbol associated with a section */
        #define STT_FILE        4           /* Symbol's name is file name */
        #define STT_COMMON      5
        #define STT_TLS         6
        #define STT_NUM         5           /* Number of defined types.  */
        #define STT_LOOS        11          /* Start of OS-specific */
        #define STT_HIOS        12          /* End of OS-specific */
        #define STT_LOPROC      13          /* Start of processor-specific */
        #define STT_HIPROC      15          /* End of processor-specific */


    unsigned char st_other;     /* Currently not defined */
    Elf32_Half st_shndx;       /* SHT index for symbol definition */
} Elf32_Sym;


/* Relocation table entry without addend (in section of type SHT_REL).  */

typedef struct
{
    Elf32_Addr r_offset;               /* Address */
    Elf32_Word r_info;                 /* Relocation type and symbol index */
        #define ELF32_R_SYM(i) ((i) >> 8)       /* Symbol idx */
        #define ELF32_R_TYPE(i)((i) & 0xff)     /* Type of relocation */
        #define ELF32_R_INFO(i, t) (((i) << 8) + ((t) & 0xff))

        #define R_386_NONE    0               /* No reloc */
        #define R_386_32      1               /* Symbol value 32 bit  */
        #define R_386_PC32    2               /* PC relative 32 bit */
        #define R_386_GOT32   3               /* 32 bit GOT entry */
        #define R_386_PLT32   4               /* 32 bit PLT address */
        #define R_386_COPY    5               /* Copy symbol at runtime */
        #define R_386_GLOB_DAT 6               /* Create GOT entry */
        #define R_386_JMP_SLOT 7               /* Create PLT entry */
        #define R_386_RELATIVE 8               /* Adjust by program base */
        #define R_386_GOTOFF  9               /* 32 bit offset to GOT */
        #define R_386_GOTPC   10              /* 32 bit PC relative offset to GOT */
        #define R_386_TLS_TPOFF 14
        #define R_386_TLS_IE    15
        #define R_386_TLS_GOTIE 16
        #define R_386_TLS_LE    17            /* negative offset relative to static TLS */
        #define R_386_TLS_GD    18
        #define R_386_TLS_LDM   19
        #define R_386_TLS_GD_32 24
        #define R_386_TLS_GD_PUSH  25
        #define R_386_TLS_GD_CALL  26
        #define R_386_TLS_GD_POP   27
        #define R_386_TLS_LDM_32   28
        #define R_386_TLS_LDM_PUSH 29
        #define R_386_TLS_LDM_CALL 30
        #define R_386_TLS_LDM_POP  31
        #define R_386_TLS_LDO_32   32
        #define R_386_TLS_IE_32    33
        #define R_386_TLS_LE_32    34
        #define R_386_TLS_DTPMOD32 35
        #define R_386_TLS_DTPOFF32 36
        #define R_386_TLS_TPOFF32  37
} Elf32_Rel;

/* stabs debug records */

typedef struct
{
    Elf32_Word DBstring;               /* string table index for the symbol */
    elf_u8_f32  DBtype;                 /* type of the symbol */
        #define DBT_UNDEF       0x00        /* undefined symbol */
        #define DBT_EXT         0x01        /* exernal modifier */
        #define DBT_ABS         0x02        /* absolute */
        #define DBT_TEXT        0x04        /* code text */
        #define DBT_DATA        0x06        /* data */
        #define DBT_BSS         0x08        /* BSS */
        #define DBT_INDR        0x0a        /* indirect to another symbol */
        #define DBT_COMM        0x12        /* common -visible after shr'd lib link */
        #define DBT_SETA        0x14        /* Absolue set element */
        #define DBT_SETT        0x16        /* code text segment set element */
        #define DBT_SETD        0x18        /* data segment set element */
        #define DBT_SETB        0x1a        /* BSS segment set element */
        #define DBT_SETV        0x1c        /* Pointer to set vector */
        #define DBT_WARNING     0x1e        /* print warning during link */
        #define DBT_FN          0x1f        /* name of object file */

        #define DBT_GSYM        0x20        /* global symbol */
        #define DBT_FUN         0x24        /* function name */
        #define DBT_STSYM       0x26        /* static data */
        #define DBT_LCSYM       0x28        /* static bss */
        #define DBT_MAIN        0x2a        /* main routine */
        #define DBT_RO          0x2c        /* read only */
        #define DBT_OPT         0x3c        /* target option? */
        #define DBT_REG         0x40        /* register variable */
        #define DBT_TLINE       0x44        /* text line number */
        #define DBT_DLINE       0x46        /* dat line number */
        #define DBT_BLINE       0x48        /* bss line number */
        #define DBT_STUN        0x62        /* structure or union */
        #define DBT_SRCF        0x64        /* source file */
        #define DBT_AUTO        0x80        /* stack variable */
        #define DBT_TYPE        0x80        /* type definition */
        #define DBT_INCS        0x84        /* include file start */
        #define DBT_PARAM       0xa0        /* parameter */
        #define DBT_INCE        0xa2        /* include file end */
    elf_u8_f32  DBmisc;                 /* misc. info */
    Elf32_Half DBdesc;                 /* description field */
    Elf32_Word DBvalu;                 /* symbol value */
} elf_stab;


/* Program header.  */

typedef struct
{
  Elf32_Word   PHtype;                 /* Program type */
        #define PHT_NULL         0          /* SHT entry unused */
  Elf32_Off   PHoff;                  /* Offset to segment in file */
  Elf32_Addr   PHvaddr;                /* Starting virtual memory address */
  Elf32_Addr   PHpaddr;                /* Starting absolute memory address */
  Elf32_Word   PHfilesz;               /* Size of file image */
  Elf32_Word   PHmemsz;                /* Size of memory image */
  Elf32_Word   PHflags;                /* Program attribute flags */
  Elf32_Word   PHalign;                /* Program loading alignment */
} Elf32_Phdr;



/* Legal values for sh_flags (section flags).  */

/***************************** 64 bit Elf *****************************************/

typedef uint64_t Elf64_Addr;
typedef uint64_t Elf64_Off;
typedef uint64_t Elf64_Xword;
typedef int64_t  Elf64_Sxword;
typedef int32_t  Elf64_Sword;
typedef uint32_t Elf64_Word;
typedef uint16_t Elf64_Half;

typedef struct
{
    unsigned char EHident[EI_NIDENT]; /* Header identification info */
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
} Elf64_Ehdr;

typedef struct {
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
} Elf64_Shdr;

typedef struct {
    Elf64_Word  p_type;
    Elf64_Word  p_flags;
    Elf64_Off   p_offset;
    Elf64_Addr  p_vaddr;
    Elf64_Addr  p_paddr;
    Elf64_Xword p_filesz;
    Elf64_Xword p_memsz;
    Elf64_Xword p_align;
} Elf64_Phdr;

typedef struct {
    Elf64_Word  st_name;
    unsigned char st_info;
    unsigned char st_other;
    Elf64_Half  st_shndx;
    Elf64_Addr  st_value;
    Elf64_Xword st_size;
} Elf64_Sym;

#define ELF64_ST_BIND(s) ELF32_ST_BIND(s)
#define ELF64_ST_TYPE(s) ELF32_ST_TYPE(s)
#define ELF64_ST_INFO(b,t) ELF32_ST_INFO(b,t)

typedef struct {
    Elf64_Addr  r_offset;
    Elf64_Xword r_info;
        #define ELF64_R_SYM(i) ((Elf64_Word)((i)>>32))
        #define ELF64_R_TYPE(i) ((Elf64_Word)(i & 0xFFFFFFFF))
        #define ELF64_R_INFO(s,t) ((((Elf64_Xword)(s))<<32)|(Elf64_Word)(t))

        // X86-64 Relocation types

        #define R_X86_64_NONE      0     // -- No relocation
        #define R_X86_64_64        1     // 64 Direct 64 bit
        #define R_X86_64_PC32      2     // 32 PC relative 32 bit signed
        #define R_X86_64_GOT32     3     // 32 32 bit GOT entry
        #define R_X86_64_PLT32     4     // 32 bit PLT address
        #define R_X86_64_COPY      5     // -- Copy symbol at runtime
        #define R_X86_64_GLOB_DAT  6     // 64 Create GOT entry
        #define R_X86_64_JUMP_SLOT 7     // 64 Create PLT entry
        #define R_X86_64_RELATIVE  8     // 64 Adjust by program base
        #define R_X86_64_GOTPCREL  9     // 32 32 bit signed pc relative offset to GOT
        #define R_X86_64_32       10     // 32 Direct 32 bit zero extended
        #define R_X86_64_32S      11     // 32 Direct 32 bit sign extended
        #define R_X86_64_16       12     // 16 Direct 16 bit zero extended
        #define R_X86_64_PC16     13     // 16 16 bit sign extended pc relative
        #define R_X86_64_8        14     //  8 Direct 8 bit sign extended
        #define R_X86_64_PC8      15     //  8 8 bit sign extended pc relative
        #define R_X86_64_DTPMOD64 16     // 64 ID of module containing symbol
        #define R_X86_64_DTPOFF64 17     // 64 Offset in TLS block
        #define R_X86_64_TPOFF64  18     // 64 Offset in initial TLS block
        #define R_X86_64_TLSGD    19     // 32 PC relative offset to GD GOT block
        #define R_X86_64_TLSLD    20     // 32 PC relative offset to LD GOT block
        #define R_X86_64_DTPOFF32 21     // 32 Offset in TLS block
        #define R_X86_64_GOTTPOFF 22     // 32 PC relative offset to IE GOT entry
        #define R_X86_64_TPOFF32  23     // 32 Offset in initial TLS block
        #define R_X86_64_PC64     24     // 64
        #define R_X86_64_GOTOFF64 25     // 64
        #define R_X86_64_GOTPC32  26     // 32
        #define R_X86_64_GNU_VTINHERIT 250    // GNU C++ hack
        #define R_X86_64_GNU_VTENTRY   251    // GNU C++ hack
} Elf64_Rel;

typedef struct {
    Elf64_Addr   r_offset;
    Elf64_Xword  r_info;
    Elf64_Sxword r_addend;
} Elf64_Rela;

#endif
