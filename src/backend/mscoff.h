/* Microsoft COFF object file format */

#include <time.h>
#include <stdint.h>

#ifdef _MSC_VER
#pragma pack(push,1)
#elif defined(__DMC__)
#pragma ZTC align 1
#endif

/***********************************************/

struct BIGOBJ_HEADER
{
    uint16_t Sig1;                 // IMAGE_FILE_MACHINE_UNKNOWN
    uint16_t Sig2;                 // 0xFFFF
    uint16_t Version;              // 2
    uint16_t Machine;              // identifies type of target machine
    uint32_t TimeDateStamp;        // creation date, number of seconds since 1970
    uint8_t  UUID[16];             //  { '\xc7', '\xa1', '\xba', '\xd1', '\xee', '\xba', '\xa9', '\x4b',
                                   //    '\xaf', '\x20', '\xfa', '\xf6', '\x6a', '\xa4', '\xdc', '\xb8' };
    uint32_t unused[4];            // { 0, 0, 0, 0 }
    uint32_t NumberOfSections;     // number of sections
    uint32_t PointerToSymbolTable; // file offset of symbol table
    uint32_t NumberOfSymbols;      // number of entries in the symbol table
};

#define IMAGE_FILE_MACHINE_UNKNOWN 0            // applies to any machine type
#define IMAGE_FILE_MACHINE_I386    0x14C        // x86
#define IMAGE_FILE_MACHINE_AMD64   0x8664       // x86_64

#define IMAGE_FILE_RELOCS_STRIPPED              1
#define IMAGE_FILE_EXECUTABLE_IMAGE             2
#define IMAGE_FILE_LINE_NUMS_STRIPPED           4
#define IMAGE_FILE_LOCAL_SYMS_STRIPPED          8
#define IMAGE_FILE_AGGRESSIVE_WS_TRIM           0x10
#define IMAGE_FILE_LARGE_ADDRESS_AWARE          0x20
#define IMAGE_FILE_BYTES_REVERSED_LO            0x80
#define IMAGE_FILE_32BIT_MACHINE                0x100
#define IMAGE_FILE_DEBUG_STRIPPED               0x200
#define IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP      0x400
#define IMAGE_FILE_NET_RUN_FROM_SWAP            0x800
#define IMAGE_FILE_SYSTEM                       0x1000
#define IMAGE_FILE_DLL                          0x2000
#define IMAGE_FILE_UP_SYSTEM_ONLY               0x4000
#define IMAGE_FILE_BYTES_REVERSED_HI            0x8000

struct IMAGE_FILE_HEADER
{
    uint16_t Machine;
    uint16_t NumberOfSections;
    uint32_t TimeDateStamp;
    uint32_t PointerToSymbolTable;
    uint32_t NumberOfSymbols;
    uint16_t SizeOfOptionalHeader;
    uint16_t Characteristics;
};

/***********************************************/

#define IMAGE_SIZEOF_SHORT_NAME 8

struct IMAGE_SECTION_HEADER
{
    uint8_t Name[IMAGE_SIZEOF_SHORT_NAME];
    uint32_t VirtualSize;
    uint32_t VirtualAddress;
    uint32_t SizeOfRawData;
    uint32_t PointerToRawData;
    uint32_t PointerToRelocations;
    uint32_t PointerToLinenumbers;
    uint16_t NumberOfRelocations;
    uint16_t NumberOfLinenumbers;
    uint32_t Characteristics;
};

#define IMAGE_SCN_TYPE_NO_PAD           8       // obsolete
#define IMAGE_SCN_CNT_CODE              0x20    // code section
#define IMAGE_SCN_CNT_INITIALIZED_DATA  0x40
#define IMAGE_SCN_CNT_UNINITIALIZED_DATA        0x80
#define IMAGE_SCN_LNK_OTHER             0x100
#define IMAGE_SCN_LNK_INFO              0x200   // comments; for .drectve section
#define IMAGE_SCN_LNK_REMOVE            0x800   // do not put in image file
#define IMAGE_SCN_LNK_COMDAT            0x1000  // COMDAT section
#define IMAGE_SCN_GPREL                 0x8000  // data referenced through global pointer GP
#define IMAGE_SCN_MEM_PURGEABLE         0x20000
#define IMAGE_SCN_MEM_16BIT             0x20000
#define IMAGE_SCN_MEM_LOCKED            0x40000
#define IMAGE_SCN_MEM_PRELOAD           0x80000
#define IMAGE_SCN_ALIGN_1BYTES          0x100000
#define IMAGE_SCN_ALIGN_2BYTES          0x200000
#define IMAGE_SCN_ALIGN_4BYTES          0x300000
#define IMAGE_SCN_ALIGN_8BYTES          0x400000
#define IMAGE_SCN_ALIGN_16BYTES         0x500000
#define IMAGE_SCN_ALIGN_32BYTES         0x600000
#define IMAGE_SCN_ALIGN_64BYTES         0x700000
#define IMAGE_SCN_ALIGN_128BYTES        0x800000
#define IMAGE_SCN_ALIGN_256BYTES        0x900000
#define IMAGE_SCN_ALIGN_512BYTES        0xA00000
#define IMAGE_SCN_ALIGN_1024BYTES       0xB00000
#define IMAGE_SCN_ALIGN_2048BYTES       0xC00000
#define IMAGE_SCN_ALIGN_4096BYTES       0xD00000
#define IMAGE_SCN_ALIGN_8192BYTES       0xE00000
#define IMAGE_SCN_LNK_NRELOC_OVFL       0x1000000       // more than 0xFFFF relocations
#define IMAGE_SCN_MEM_DISCARDABLE       0x2000000       // can be discarded
#define IMAGE_SCN_MEM_NOT_CACHED        0x4000000       // cannot be cached
#define IMAGE_SCN_MEM_NOT_PAGED         0x8000000       // cannot be paged
#define IMAGE_SCN_MEM_SHARED            0x10000000      // can be shared
#define IMAGE_SCN_MEM_EXECUTE           0x20000000      // executable code
#define IMAGE_SCN_MEM_READ              0x40000000      // readable
#define IMAGE_SCN_MEM_WRITE             0x80000000      // writeable

/***********************************************/

#define SYMNMLEN        8

#define IMAGE_SYM_DEBUG                 -2
#define IMAGE_SYM_ABSOLUTE              -1
#define IMAGE_SYM_UNDEFINED             0

/* Values for n_sclass  */
#define IMAGE_SYM_CLASS_EXTERNAL        2
#define IMAGE_SYM_CLASS_STATIC          3
#define IMAGE_SYM_CLASS_LABEL           6
#define IMAGE_SYM_CLASS_FUNCTION        101
#define IMAGE_SYM_CLASS_FILE            103

struct SymbolTable32
{
    union
    {
        uint8_t Name[SYMNMLEN];
        struct
        {
            uint32_t Zeros;
            uint32_t Offset;
        };
    };
    uint32_t Value;
    int32_t SectionNumber;
    uint16_t Type;
    uint8_t StorageClass;
    uint8_t NumberOfAuxSymbols;
};

struct SymbolTable
{
    uint8_t Name[SYMNMLEN];
    uint32_t Value;
    int16_t SectionNumber;
    uint16_t Type;
    uint8_t StorageClass;
    uint8_t NumberOfAuxSymbols;
};

/***********************************************/

struct reloc
{
#pragma pack(1)
    unsigned r_vaddr;           // file offset of relocation
    unsigned r_symndx;          // symbol table index
    unsigned short r_type;      // IMAGE_REL_XXX kind of relocation to be performed

#define IMAGE_REL_AMD64_ABSOLUTE        0
#define IMAGE_REL_AMD64_ADDR64          1
#define IMAGE_REL_AMD64_ADDR32          2
#define IMAGE_REL_AMD64_ADDR32NB        3
#define IMAGE_REL_AMD64_REL32           4
#define IMAGE_REL_AMD64_REL32_1         5
#define IMAGE_REL_AMD64_REL32_2         6
#define IMAGE_REL_AMD64_REL32_3         7
#define IMAGE_REL_AMD64_REL32_4         8
#define IMAGE_REL_AMD64_REL32_5         9
#define IMAGE_REL_AMD64_SECTION         0xA
#define IMAGE_REL_AMD64_SECREL          0xB
#define IMAGE_REL_AMD64_SECREL7         0xC
#define IMAGE_REL_AMD64_TOKEN           0xD
#define IMAGE_REL_AMD64_SREL32          0xE
#define IMAGE_REL_AMD64_PAIR            0xF
#define IMAGE_REL_AMD64_SSPAN32         0x10

#define IMAGE_REL_I386_ABSOLUTE         0
#define IMAGE_REL_I386_DIR16            1
#define IMAGE_REL_I386_REL16            2
#define IMAGE_REL_I386_DIR32            6
#define IMAGE_REL_I386_DIR32NB          7
#define IMAGE_REL_I386_SEG12            9
#define IMAGE_REL_I386_SECTION          0xA
#define IMAGE_REL_I386_SECREL           0xB
#define IMAGE_REL_I386_TOKEN            0xC
#define IMAGE_REL_I386_SECREL7          0xD
#define IMAGE_REL_I386_REL32            0x14

#pragma pack()
};


/***********************************************/

struct lineno
{
    union
    {
        unsigned l_symndx;
        unsigned l_paddr;
    } l_addr;
    unsigned short l_lnno;
};


/***********************************************/

#pragma pack(1)
union auxent
{
#pragma pack(1)
    // Function definitions
    struct
    {   unsigned TagIndex;
        unsigned TotalSize;
        unsigned PointerToLinenumber;
        unsigned PointerToNextFunction;
        unsigned short Zeros;
    } x_fd;

    // .bf symbols
    struct
    {
#pragma pack(1)
        unsigned Unused;
        unsigned short Linenumber;
        char filler[6];
        unsigned PointerToNextFunction;
        unsigned short Zeros;
#pragma pack()
    } x_bf;

    // .ef symbols
    struct
    {   unsigned Unused;
        unsigned short Linenumber;
        unsigned short Zeros;
    } x_ef;

    // Weak externals
    struct
    {   unsigned TagIndex;
        unsigned Characteristics;
        unsigned short Zeros;
#define IMAGE_WEAK_EXTERN_SEARCH_NOLIBRARY
#define IMAGE_WEAK_EXTERN_SEARCH_LIBRARY
#define IMAGE_WEAK_EXTERN_SEARCH_ALIAS
    } x_weak;

    // Section definitions
    struct
    {
        unsigned length;
        unsigned short NumberOfRelocations;
        unsigned short NumberOfLinenumbers;
        unsigned CheckSum;
        unsigned short NumberLowPart;
        unsigned char Selection;
        unsigned char Unused;
        unsigned short NumberHighPart;
        unsigned short Zeros;
#define IMAGE_COMDAT_SELECT_NODUPLICATES        1
#define IMAGE_COMDAT_SELECT_ANY                 2
#define IMAGE_COMDAT_SELECT_SAME_SIZE           3
#define IMAGE_COMDAT_SELECT_EXACT_MATCH         4
#define IMAGE_COMDAT_SELECT_ASSOCIATIVE         5
#define IMAGE_COMDAT_SELECT_LARGEST             6
    } x_section;

    char filler[18];
#pragma pack()
};
#pragma pack()


/***********************************************/

#ifdef _MSC_VER
#pragma pack(pop)
#elif defined(__DMC__)
#pragma ZTC align
#endif
