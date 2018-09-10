
module dmd.backend.melf;

        // 386 Relocation types

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

