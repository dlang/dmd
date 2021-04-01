/** Microsoft COFF object file format
 *
 * Source: $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/mscoff.d, backend/_mscoff.d)
 */

module dmd.backend.mscoff;

// Online documentation: https://dlang.org/phobos/dmd_backend_mscoff.html

@safe:
align (1):

/***********************************************/

struct BIGOBJ_HEADER
{
    ushort Sig1;                 // IMAGE_FILE_MACHINE_UNKNOWN
    ushort Sig2;                 // 0xFFFF
    ushort Version;              // 2
    ushort Machine;              // identifies type of target machine
    uint TimeDateStamp;          // creation date, number of seconds since 1970
    ubyte[16] UUID;              //  { '\xc7', '\xa1', '\xba', '\xd1', '\xee', '\xba', '\xa9', '\x4b',
                                 //    '\xaf', '\x20', '\xfa', '\xf6', '\x6a', '\xa4', '\xdc', '\xb8' };
    uint[4] unused;              // { 0, 0, 0, 0 }
    uint NumberOfSections;       // number of sections
    uint PointerToSymbolTable;   // file offset of symbol table
    uint NumberOfSymbols;        // number of entries in the symbol table
}

enum
{
    IMAGE_FILE_MACHINE_UNKNOWN            = 0,           // applies to any machine type
    IMAGE_FILE_MACHINE_I386               = 0x14C,       // x86
    IMAGE_FILE_MACHINE_AMD64              = 0x8664,      // x86_64

    IMAGE_FILE_RELOCS_STRIPPED            = 1,
    IMAGE_FILE_EXECUTABLE_IMAGE           = 2,
    IMAGE_FILE_LINE_NUMS_STRIPPED         = 4,
    IMAGE_FILE_LOCAL_SYMS_STRIPPED        = 8,
    IMAGE_FILE_AGGRESSIVE_WS_TRIM         = 0x10,
    IMAGE_FILE_LARGE_ADDRESS_AWARE        = 0x20,
    IMAGE_FILE_BYTES_REVERSED_LO          = 0x80,
    IMAGE_FILE_32BIT_MACHINE              = 0x100,
    IMAGE_FILE_DEBUG_STRIPPED             = 0x200,
    IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP    = 0x400,
    IMAGE_FILE_NET_RUN_FROM_SWAP          = 0x800,
    IMAGE_FILE_SYSTEM                     = 0x1000,
    IMAGE_FILE_DLL                        = 0x2000,
    IMAGE_FILE_UP_SYSTEM_ONLY             = 0x4000,
    IMAGE_FILE_BYTES_REVERSED_HI          = 0x8000,
}

struct IMAGE_FILE_HEADER
{
    ushort Machine;
    ushort NumberOfSections;
    uint TimeDateStamp;
    uint PointerToSymbolTable;
    uint NumberOfSymbols;
    ushort SizeOfOptionalHeader;
    ushort Characteristics;
}

/***********************************************/

enum IMAGE_SIZEOF_SHORT_NAME = 8;

struct IMAGE_SECTION_HEADER
{
    ubyte[IMAGE_SIZEOF_SHORT_NAME] Name;
    uint VirtualSize;
    uint VirtualAddress;
    uint SizeOfRawData;
    uint PointerToRawData;
    uint PointerToRelocations;
    uint PointerToLinenumbers;
    ushort NumberOfRelocations;
    ushort NumberOfLinenumbers;
    uint Characteristics;
}

enum
{
    IMAGE_SCN_TYPE_NO_PAD           = 8,       // obsolete
    IMAGE_SCN_CNT_CODE              = 0x20,    // code section
    IMAGE_SCN_CNT_INITIALIZED_DATA  = 0x40,
    IMAGE_SCN_CNT_UNINITIALIZED_DATA = 0x80,
    IMAGE_SCN_LNK_OTHER             = 0x100,
    IMAGE_SCN_LNK_INFO              = 0x200,   // comments; for .drectve section
    IMAGE_SCN_LNK_REMOVE            = 0x800,   // do not put in image file
    IMAGE_SCN_LNK_COMDAT            = 0x1000,  // COMDAT section
    IMAGE_SCN_GPREL                 = 0x8000,  // data referenced through global pointer GP
    IMAGE_SCN_MEM_PURGEABLE         = 0x20000,
    IMAGE_SCN_MEM_16BIT             = 0x20000,
    IMAGE_SCN_MEM_LOCKED            = 0x40000,
    IMAGE_SCN_MEM_PRELOAD           = 0x80000,
    IMAGE_SCN_ALIGN_1BYTES          = 0x100000,
    IMAGE_SCN_ALIGN_2BYTES          = 0x200000,
    IMAGE_SCN_ALIGN_4BYTES          = 0x300000,
    IMAGE_SCN_ALIGN_8BYTES          = 0x400000,
    IMAGE_SCN_ALIGN_16BYTES         = 0x500000,
    IMAGE_SCN_ALIGN_32BYTES         = 0x600000,
    IMAGE_SCN_ALIGN_64BYTES         = 0x700000,
    IMAGE_SCN_ALIGN_128BYTES        = 0x800000,
    IMAGE_SCN_ALIGN_256BYTES        = 0x900000,
    IMAGE_SCN_ALIGN_512BYTES        = 0xA00000,
    IMAGE_SCN_ALIGN_1024BYTES       = 0xB00000,
    IMAGE_SCN_ALIGN_2048BYTES       = 0xC00000,
    IMAGE_SCN_ALIGN_4096BYTES       = 0xD00000,
    IMAGE_SCN_ALIGN_8192BYTES       = 0xE00000,
    IMAGE_SCN_LNK_NRELOC_OVFL       = 0x1000000,     // more than 0xFFFF relocations
    IMAGE_SCN_MEM_DISCARDABLE       = 0x2000000,     // can be discarded
    IMAGE_SCN_MEM_NOT_CACHED        = 0x4000000,     // cannot be cached
    IMAGE_SCN_MEM_NOT_PAGED         = 0x8000000,     // cannot be paged
    IMAGE_SCN_MEM_SHARED            = 0x10000000,    // can be shared
    IMAGE_SCN_MEM_EXECUTE           = 0x20000000,    // executable code
    IMAGE_SCN_MEM_READ              = 0x40000000,    // readable
    IMAGE_SCN_MEM_WRITE             = 0x80000000,    // writeable
}

/***********************************************/

enum SYMNMLEN = 8;

enum
{
    IMAGE_SYM_DEBUG                 = -2,
    IMAGE_SYM_ABSOLUTE              = -1,
    IMAGE_SYM_UNDEFINED             = 0,

/* Values for n_sclass  */
    IMAGE_SYM_CLASS_EXTERNAL        = 2,
    IMAGE_SYM_CLASS_STATIC          = 3,
    IMAGE_SYM_CLASS_LABEL           = 6,
    IMAGE_SYM_CLASS_FUNCTION        = 101,
    IMAGE_SYM_CLASS_FILE            = 103,
}

struct SymbolTable32
{
    union
    {
        ubyte[SYMNMLEN] Name;
        struct
        {
            uint Zeros;
            uint Offset;
        }
    }
    uint Value;
    int SectionNumber;
    ushort Type;
    ubyte StorageClass;
    ubyte NumberOfAuxSymbols;
}

struct SymbolTable
{
    ubyte[SYMNMLEN] Name;
    uint Value;
    short SectionNumber;
    ushort Type;
    ubyte StorageClass;
    ubyte NumberOfAuxSymbols;
}

/***********************************************/

struct reloc
{
  align (1):
    uint r_vaddr;           // file offset of relocation
    uint r_symndx;          // symbol table index
    ushort r_type;          // IMAGE_REL_XXX kind of relocation to be performed
}

enum
{
    IMAGE_REL_AMD64_ABSOLUTE        = 0,
    IMAGE_REL_AMD64_ADDR64          = 1,
    IMAGE_REL_AMD64_ADDR32          = 2,
    IMAGE_REL_AMD64_ADDR32NB        = 3,
    IMAGE_REL_AMD64_REL32           = 4,
    IMAGE_REL_AMD64_REL32_1         = 5,
    IMAGE_REL_AMD64_REL32_2         = 6,
    IMAGE_REL_AMD64_REL32_3         = 7,
    IMAGE_REL_AMD64_REL32_4         = 8,
    IMAGE_REL_AMD64_REL32_5         = 9,
    IMAGE_REL_AMD64_SECTION         = 0xA,
    IMAGE_REL_AMD64_SECREL          = 0xB,
    IMAGE_REL_AMD64_SECREL7         = 0xC,
    IMAGE_REL_AMD64_TOKEN           = 0xD,
    IMAGE_REL_AMD64_SREL32          = 0xE,
    IMAGE_REL_AMD64_PAIR            = 0xF,
    IMAGE_REL_AMD64_SSPAN32         = 0x10,

    IMAGE_REL_I386_ABSOLUTE         = 0,
    IMAGE_REL_I386_DIR16            = 1,
    IMAGE_REL_I386_REL16            = 2,
    IMAGE_REL_I386_DIR32            = 6,
    IMAGE_REL_I386_DIR32NB          = 7,
    IMAGE_REL_I386_SEG12            = 9,
    IMAGE_REL_I386_SECTION          = 0xA,
    IMAGE_REL_I386_SECREL           = 0xB,
    IMAGE_REL_I386_TOKEN            = 0xC,
    IMAGE_REL_I386_SECREL7          = 0xD,
    IMAGE_REL_I386_REL32            = 0x14,
}

/***********************************************/

struct lineno
{
    union U
    {
        uint l_symndx;
        uint l_paddr;
    }
    U l_addr;
    ushort l_lnno;
}


/***********************************************/

union auxent
{
  align (1):
    // Function definitions
    struct FD
    {   uint TagIndex;
        uint TotalSize;
        uint PointerToLinenumber;
        uint PointerToNextFunction;
        ushort Zeros;
    }
    FD x_fd;

    // .bf symbols
    struct BF
    {
      align (1):
        uint Unused;
        ushort Linenumber;
        char[6] filler;
        uint PointerToNextFunction;
        ushort Zeros;
    }
    BF x_bf;

    // .ef symbols
    struct EF
    {   uint Unused;
        ushort Linenumber;
        ushort Zeros;
    }
    EF x_ef;

    // Weak externals
    struct WE
    {   uint TagIndex;
        uint Characteristics;
        ushort Zeros;
        // IMAGE_WEAK_EXTERN_SEARCH_NOLIBRARY
        // IMAGE_WEAK_EXTERN_SEARCH_LIBRARY
        // IMAGE_WEAK_EXTERN_SEARCH_ALIAS
    }
    WE x_weak;

    // Section definitions
    struct S
    {
        uint length;
        ushort NumberOfRelocations;
        ushort NumberOfLinenumbers;
        uint CheckSum;
        ushort NumberLowPart;
        ubyte Selection;
        ubyte Unused;
        ushort NumberHighPart;
        ushort Zeros;
    }
    S x_section;

    char[18] filler;
}

// auxent.x_section.Zeros
enum
{
    IMAGE_COMDAT_SELECT_NODUPLICATES        = 1,
    IMAGE_COMDAT_SELECT_ANY                 = 2,
    IMAGE_COMDAT_SELECT_SAME_SIZE           = 3,
    IMAGE_COMDAT_SELECT_EXACT_MATCH         = 4,
    IMAGE_COMDAT_SELECT_ASSOCIATIVE         = 5,
    IMAGE_COMDAT_SELECT_LARGEST             = 6,
}

/***********************************************/

