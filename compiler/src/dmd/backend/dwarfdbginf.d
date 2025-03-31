/**
 * Emit Dwarf symbolic debug info
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/dwarfdbginf.d, backend/dwarfdbginf.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/dwarfdbginf.d
 */


/*
Some generic information for debug info on macOS:

The linker on macOS will remove any debug info, i.e. every section with the
`S_ATTR_DEBUG` flag, this includes everything in the `__DWARF` section.
Because of this, it is not possible to get filenames and line numbers for
backtraces from the executable alone.

Normally the linker removes all the debug info but adds a reference to the
object files. The debugger can then read the object files to get filename and
line number information. It's also possible to use an additional tool that
generates a separate `.dSYM` file. This file can then later be deployed with the
application if debug info is needed when the application is deployed.

Support in core.runtime for getting filename and line number for backtraces
from these `.dSYM` files will need to be investigated.
See: https://issues.dlang.org/show_bug.cgi?id=20510
*/

module dmd.backend.dwarfdbginf;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.errno;

import dmd.backend.cc;
import dmd.backend.cdef;

version(Windows)
{
    nothrow
    private extern (C) char* _getcwd(char* buffer, size_t maxlen);
    alias getcwd = _getcwd;
    nothrow
    private extern (C) int* _errno();   // not the multi-threaded version
}
else version (Posix)
{
    import core.sys.posix.unistd : getcwd;
}
else
    static assert(0);

static if (1)
{
    import dmd.backend.aarray;
    import dmd.backend.barray;
    import dmd.backend.code;
    import dmd.backend.x86.code_x86;
    import dmd.backend.drtlsym : getRtlsymPersonality;
    import dmd.backend.dwarf;
    import dmd.backend.dwarf2;
    import dmd.backend.mem;
    import dmd.backend.dlist;
    import dmd.backend.el;
    import dmd.backend.elfobj : addSegmentToComdat;
    import dmd.backend.machobj : getsegment2;
    import dmd.backend.global;
    import dmd.backend.obj;
    import dmd.backend.oper;
    import dmd.backend.symtab;
    import dmd.backend.ty;
    import dmd.backend.type;

    import dmd.backend.melf;
    import dmd.backend.mach;

    import dmd.common.outbuffer;


    nothrow:

    __gshared
    {
        //static if (MACHOBJ)
            int except_table_seg = UNKNOWN; // __gcc_except_tab segment
            int except_table_num = 0;       // sequence number for GCC_except_table%d symbols
            int eh_frame_seg = UNKNOWN;     // __eh_frame segment
            Symbol* eh_frame_sym = null;    // past end of __eh_frame

        uint CIE_offset_unwind;     // CIE offset for unwind data
        uint CIE_offset_no_unwind;  // CIE offset for no unwind data


        private Barray!(Symbol*) resetSyms;        // Keep pointers to reset symbols
    }

    /***********************************
     * Determine if generating a eh_frame with full
     * unwinding information.
     * This decision is done on a per-function basis.
     * Returns:
     *      true if unwinding needs to be done
     */
    bool doUnwindEhFrame()
    {
        if (funcsym_p.Sfunc.Fflags3 & Feh_none)
        {
            return (config.exe & (EX_FREEBSD | EX_FREEBSD64 | EX_OPENBSD | EX_OPENBSD64 | EX_DRAGONFLYBSD64)) != 0;
        }

        /* FreeBSD fails when having some frames as having unwinding info and some not.
         * (It hangs in unittests for std.datetime.)
         * g++ on FreeBSD does not generate mixed frames, while g++ on OSX and Linux does.
         */
        assert(!(cgstate.usednteh & ~(EHtry | EHcleanup)));
        return (cgstate.usednteh & (EHtry | EHcleanup)) ||
               (config.exe & (EX_FREEBSD | EX_FREEBSD64 | EX_OPENBSD | EX_OPENBSD64 | EX_DRAGONFLYBSD64)) && config.useExceptions;
    }

        SYMIDX MAP_SEG2SYMIDX(int seg) { return SegData[seg].SDsymidx; }


    int OFFSET_FAC() { return REGSIZE(); }

    int dwarf_getsegment(const(char)* name, int align_, int flags)
    {
        if (config.objfmt == OBJ_ELF)
            return Obj.getsegment(name, null, flags, 0, align_ * 4);
        if (config.objfmt == OBJ_MACH)
            return Obj.getsegment(name, "__DWARF", align_ * 2, flags);
        assert(0);
    }

    int dwarf_getsegment_alloc(const(char)* name, const(char)* suffix, int align_)
    {
        return Obj.getsegment(name, suffix, SHT_PROGBITS, SHF_ALLOC, align_ * 4);
    }

    int dwarf_except_table_alloc(Symbol* s)
    {
        //printf("dwarf_except_table_alloc('%s')\n", s.Sident.ptr);
        if (config.objfmt == OBJ_ELF)
        {
            /* If `s` is in a COMDAT, then this table needs to go into
             * a unique section, which then gets added to the COMDAT group
             * associated with `s`.
             */
            seg_data* pseg = SegData[s.Sseg];
            if (pseg.SDassocseg)
            {
                const(char)* suffix = s.Sident.ptr; // cpp_mangle(s);
                segidx_t tableseg = Obj.getsegment(".gcc_except_table.", suffix, SHT_PROGBITS, SHF_ALLOC|SHF_GROUP, 1);
                addSegmentToComdat(tableseg, s.Sseg);
                return tableseg;
            }
            else
                return dwarf_getsegment_alloc(".gcc_except_table", null, 1);
        }
        else if (config.objfmt == OBJ_MACH)
        {
            return getsegment2(except_table_seg, "__gcc_except_tab", "__TEXT", 2, S_REGULAR);
        }
        else
            assert(0);
    }

    int dwarf_eh_frame_alloc()
    {
        if (config.objfmt == OBJ_ELF)
            return dwarf_getsegment_alloc(".eh_frame", null, I64 ? 2 : 1);
        if (config.objfmt == OBJ_MACH)
        {
            int seg = getsegment2(eh_frame_seg, "__eh_frame", "__TEXT", I64 ? 3 : 2,
                S_COALESCED | S_ATTR_NO_TOC | S_ATTR_STRIP_STATIC_SYMS | S_ATTR_LIVE_SUPPORT);
            /* Generate symbol for it to use for fixups
             */
            if (!eh_frame_sym)
            {
                type* t = tspvoid;
                t.Tcount++;
                type_setmangle(&t, Mangle.syscall);         // no leading '_' for mangled name
                eh_frame_sym = symbol_name("EH_frame0", SC.static_, t);
                Obj.pubdef(seg, eh_frame_sym, 0);
                symbol_keep(eh_frame_sym);
            }
            return seg;
        }
        assert(0);
    }

    // machobj.c
    enum RELaddr = 0;       // straight address
    enum RELrel  = 1;       // relative to location to be fixed up

    void dwarf_addrel(int seg, targ_size_t offset, int targseg, targ_size_t val = 0)
    {
        if (config.objfmt == OBJ_ELF)
            Obj.addrel(seg, offset, I64 ? R_X86_64_32 : R_386_32, cast(int)MAP_SEG2SYMIDX(targseg), val);
        else if (config.objfmt == OBJ_MACH)
            Obj.addrel(seg, offset, cast(Symbol*) null, targseg, RELaddr, cast(int)val);
        else
            assert(0);
    }

    void dwarf_addrel64(int seg, targ_size_t offset, int targseg, targ_size_t val)
    {
        if (config.objfmt == OBJ_ELF)
            Obj.addrel(seg, offset, R_X86_64_64, cast(int)MAP_SEG2SYMIDX(targseg), val);
        else if (config.objfmt == OBJ_MACH)
            Obj.addrel(seg, offset, null, targseg, RELaddr, cast(uint)val);
        else
            assert(0);
    }

    void dwarf_appreladdr(int seg, OutBuffer* buf, int targseg, targ_size_t val)
    {
        if (I64)
        {
            if (config.objfmt == OBJ_ELF)
            {
                dwarf_addrel64(seg, buf.length(), targseg, val);
                buf.write64(0);
            }
            else if (config.objfmt == OBJ_MACH)
            {
                dwarf_addrel64(seg, buf.length(), targseg, 0);
                buf.write64(val);
            }
            else
                assert(0);
        }
        else
        {
            dwarf_addrel(seg, buf.length(), targseg, 0);
            buf.write32(cast(uint)val);
        }
    }

    void dwarf_apprel32(int seg, OutBuffer* buf, int targseg, targ_size_t val)
    {
        dwarf_addrel(seg, buf.length(), targseg, I64 ? val : 0);
        buf.write32(I64 ? 0 : cast(uint)val);
    }

    void append_addr(OutBuffer* buf, targ_size_t addr)
    {
        if (I64)
            buf.write64(addr);
        else
            buf.write32(cast(uint)addr);
    }


    /************************  DWARF DEBUG OUTPUT ********************************/

    // Dwarf Symbolic Debugging Information

    // CFA = value of the stack pointer at the call site in the previous frame

    struct CFA_reg
    {
        int offset;                 // offset from CFA
    }

    // Current CFA state for .debug_frame
    struct CFA_state
    {
        size_t location;
        int reg;                    // CFA register number
        int offset;                 // CFA register offset
        CFA_reg[97] regstates;      // register states
    }

    /***********************
     * Convert CPU register number to Dwarf register number.
     * Params:
     *      reg = CPU register
     * Returns:
     *      dwarf register
     */
    int dwarf_regno(int reg)
    {
        if (I32)
        {
            if (config.objfmt == OBJ_MACH)
            {
                    if (reg == BP || reg == SP)
                        reg ^= BP ^ SP;     // swap EBP and ESP register values for OSX (!)
            }
            return reg;
        }
        else if (config.target_cpu == TARGET_AArch64)
        {   // https://github.com/ARM-software/abi-aa/blob/main/aadwarf64/aadwarf64.rst#dwarf-register-names
            return (reg < 32) ? reg : reg - 32 + 64;
        }
        else if (I64)
        {
            /* See https://software.intel.com/sites/default/files/article/402129/mpx-linux64-abi.pdf
             * Figure 3.3.8 pg. 62
             * R8..15    :  8..15
             * XMM0..15  : 17..32
             * ST0..7    : 33..40
             * MM0..7    : 41..48
             * XMM16..31 : 67..82
             */
            static immutable int[8] to_amd64_reg_map =
            // AX CX DX BX SP BP SI DI
            [   0, 2, 1, 3, 7, 6, 4, 5 ];
            return reg < 8 ? to_amd64_reg_map[reg] : reg;
        }
        else
            assert(0);
    }

    private __gshared
    {
        CFA_state CFA_state_init_32 =       // initial CFA state as defined by CIE
        {   0,                // location
            -1,               // register
            4,                // offset
            [   { 0 },        // 0: EAX
                { 0 },        // 1: ECX
                { 0 },        // 2: EDX
                { 0 },        // 3: EBX
                { 0 },        // 4: ESP
                { 0 },        // 5: EBP
                { 0 },        // 6: ESI
                { 0 },        // 7: EDI
                { -4 },       // 8: EIP
            ]
        };

        CFA_state CFA_state_init_64 =       // initial CFA state as defined by CIE
        {   0,                // location
            -1,               // register
            8,                // offset
            [   { 0 },        // 0: RAX
                { 0 },        // 1: RBX
                { 0 },        // 2: RCX
                { 0 },        // 3: RDX
                { 0 },        // 4: RSI
                { 0 },        // 5: RDI
                { 0 },        // 6: RBP
                { 0 },        // 7: RSP
                { 0 },        // 8: R8
                { 0 },        // 9: R9
                { 0 },        // 10: R10
                { 0 },        // 11: R11
                { 0 },        // 12: R12
                { 0 },        // 13: R13
                { 0 },        // 14: R14
                { 0 },        // 15: R15
                { -8 },       // 16: RIP
            ]
        };

        CFA_state CFA_state_current;     // current CFA state
        OutBuffer cfa_buf;               // CFA instructions
    }

    /***********************************
     * Set the location, i.e. the offset from the start
     * of the function. It must always be greater than
     * the current location.
     * Params:
     *      location = offset from the start of the function
     */
    void dwarf_CFA_set_loc(uint location)
    {
        assert(location >= CFA_state_current.location);
        uint inc = cast(uint)(location - CFA_state_current.location);
        if (inc <= 63)
            cfa_buf.writeByte(DW_CFA_advance_loc + inc);
        else if (inc <= 255)
        {   cfa_buf.writeByte(DW_CFA_advance_loc1);
            cfa_buf.writeByte(inc);
        }
        else if (inc <= 0xFFFF)
        {   cfa_buf.writeByte(DW_CFA_advance_loc2);
            cfa_buf.write16(inc);
        }
        else
        {   cfa_buf.writeByte(DW_CFA_advance_loc4);
            cfa_buf.write32(inc);
        }
        CFA_state_current.location = location;
    }

    /*******************************************
     * Set the frame register, and its offset.
     * Params:
     *      reg = machine register
     *      offset = offset from frame register
     */
    void dwarf_CFA_set_reg_offset(int reg, int offset)
    {
        int dw_reg = dwarf_regno(reg);
        if (dw_reg != CFA_state_current.reg)
        {
            if (offset == CFA_state_current.offset)
            {
                cfa_buf.writeByte(DW_CFA_def_cfa_register);
                cfa_buf.writeuLEB128(dw_reg);
            }
            else if (offset < 0)
            {
                cfa_buf.writeByte(DW_CFA_def_cfa_sf);
                cfa_buf.writeuLEB128(dw_reg);
                cfa_buf.writesLEB128(offset / -OFFSET_FAC);
            }
            else
            {
                cfa_buf.writeByte(DW_CFA_def_cfa);
                cfa_buf.writeuLEB128(dw_reg);
                cfa_buf.writeuLEB128(offset);
            }
        }
        else if (offset < 0)
        {
            cfa_buf.writeByte(DW_CFA_def_cfa_offset_sf);
            cfa_buf.writesLEB128(offset / -OFFSET_FAC);
        }
        else
        {
            cfa_buf.writeByte(DW_CFA_def_cfa_offset);
            cfa_buf.writeuLEB128(offset);
        }
        CFA_state_current.reg = dw_reg;
        CFA_state_current.offset = offset;
    }

    /***********************************************
     * Set reg to be at offset from frame register.
     * Params:
     *      reg = machine register
     *      offset = offset from frame register
     */
    void dwarf_CFA_offset(int reg, int offset)
    {
        int dw_reg = dwarf_regno(reg);
        if (CFA_state_current.regstates[dw_reg].offset != offset)
        {
            if (offset <= 0)
            {
                cfa_buf.writeByte(DW_CFA_offset + dw_reg);
                cfa_buf.writeuLEB128(offset / -OFFSET_FAC);
            }
            else
            {
                cfa_buf.writeByte(DW_CFA_offset_extended_sf);
                cfa_buf.writeuLEB128(dw_reg);
                cfa_buf.writesLEB128(offset / -OFFSET_FAC);
            }
        }
        CFA_state_current.regstates[dw_reg].offset = offset;
    }

    /**************************************
     * Set total size of arguments pushed on the stack.
     * Params:
     *      sz = total size
     */
    void dwarf_CFA_args_size(size_t sz)
    {
        cfa_buf.writeByte(DW_CFA_GNU_args_size);
        cfa_buf.writeuLEB128(cast(uint)sz);
    }

    struct Section
    {
        segidx_t seg = 0;
        IDXSEC secidx = 0;
        OutBuffer* buf = null;
        const(char)* name;
        int flags = 0;

        nothrow this (const(char)* n)
        {
            name = n;
            if (config.objfmt == OBJ_MACH)
                flags = S_REGULAR | S_ATTR_DEBUG;
            else
                flags = SHT_PROGBITS;
        }
        /* Allocate and initialize Section
         */
        nothrow void initialize()
        {
            const segidx_t segi = dwarf_getsegment(name, 0, flags);
            seg = segi;
            secidx = SegData[segi].SDshtidx;
            buf = SegData[segi].SDbuf;
            buf.reserve(1000);
        }
    }


    private __gshared
    {

        Section debug_pubnames;
        Section debug_aranges;
        Section debug_ranges;
        Section debug_loc;
        Section debug_abbrev;
        Section debug_info;
        Section debug_str;
        Section debug_line;

        const(char*) debug_frame_name()
        {
            if (config.objfmt == OBJ_MACH)
                return "__debug_frame";
            if (config.objfmt == OBJ_ELF)
                return ".debug_frame";
            return null;
        }


        /* DWARF 7.5.3: "Each declaration begins with an unsigned LEB128 number
         * representing the abbreviation code itself."
         */
        uint abbrevcode = 1;
        AApair* abbrev_table;
        int hasModname;    // 1 if has DW_TAG_module

        // .debug_info
        AAchars* infoFileName_table;

        AApair* type_table;
        AApair* functype_table;  // not sure why this cannot be combined with type_table
        OutBuffer* functypebuf;

        // .debug_line
        size_t linebuf_filetab_end;
        size_t lineHeaderLengthOffset;
        AAchars* lineDirectories;

        const byte line_base = -5;
        const ubyte line_range = 14;
        const ubyte opcode_base = 13;

        public uint[TYMAX] typidx_tab;
    }

    void machDebugSectionsInit()
    {
        debug_pubnames = Section("__debug_pubnames");
        debug_aranges  = Section("__debug_aranges");
        debug_ranges   = Section("__debug_ranges");
        debug_loc      = Section("__debug_loc");
        debug_abbrev   = Section("__debug_abbrev");
        debug_info     = Section("__debug_info");
        debug_str      = Section("__debug_str");
        debug_line     = Section("__debug_line");
    }
    void elfDebugSectionsInit()
    {
        debug_pubnames = Section(".debug_pubnames");
        debug_aranges  = Section(".debug_aranges");
        debug_ranges   = Section(".debug_ranges");
        debug_loc      = Section(".debug_loc");
        debug_abbrev   = Section(".debug_abbrev");
        debug_info     = Section(".debug_info");
        debug_str      = Section(".debug_str");
        debug_line     = Section(".debug_line");
    }

    /*****************************************
     * Replace the bytes in `buf` from the `offset` by `data`.
     *
     * Params:
     *      buf = buffer where `data` will be written
     *      offset = offset of the bytes in `buf` to replace
     *      data = bytes to write
     */
    extern(D) void rewrite(T)(OutBuffer* buf, size_t offset, T data)
    {
        *(cast(T*)&buf.buf[offset]) = data;
    }

    alias rewrite32 = rewrite!uint;
    alias rewrite64 = rewrite!ulong;

    /*****************************************
     * Append .debug_frame header to buf.
     * Params:
     *      buf = write raw data here
     */
    void writeDebugFrameHeader(OutBuffer* buf)
    {
        void writeDebugFrameHeader(ubyte dversion)()
        {
            struct DebugFrameHeader
            {
              align (1):
                uint length;
                uint CIE_id = 0xFFFFFFFF;
                ubyte version_ = dversion;
                ubyte augmentation;
                static if (dversion >= 4)
                {
                    ubyte address_size = 4;
                    ubyte segment_selector_size;
                }
                ubyte code_alignment_factor = 1;
                ubyte data_alignment_factor = 0x80;
                ubyte return_address_register = 8;
                ubyte[11] opcodes =
                [
                    DW_CFA_def_cfa, 4, 4,   // r4,4 [r7,8]
                    DW_CFA_offset + 8, 1,   // r8,1 [r16,1]
                    DW_CFA_nop, DW_CFA_nop,
                    DW_CFA_nop, DW_CFA_nop, // 64 padding
                    DW_CFA_nop, DW_CFA_nop, // 64 padding
                ];
            }
            static if (dversion == 3)
                static assert(DebugFrameHeader.sizeof == 24);
            else static if (dversion == 4)
                static assert(DebugFrameHeader.sizeof == 26);
            else
                static assert(0);

            auto dfh = DebugFrameHeader.init;
            dfh.data_alignment_factor -= OFFSET_FAC;

            if (I64)
            {
                dfh.length = DebugFrameHeader.sizeof - 4;
                dfh.return_address_register = 16;           // (-8)
                dfh.opcodes[1] = 7;                         // RSP
                dfh.opcodes[2] = 8;
                dfh.opcodes[3] = DW_CFA_offset + 16;        // RIP
            }
            else
            {
                dfh.length = DebugFrameHeader.sizeof - 8;
            }

            buf.writen(&dfh, dfh.length + 4);
        }

        if (config.dwarf == 3)
            writeDebugFrameHeader!3();
        else
            writeDebugFrameHeader!4();
    }

    /*****************************************
     * Append .eh_frame header to buf.
     * Almost identical to .debug_frame
     * Params:
     *      dfseg = SegData[] index for .eh_frame
     *      buf = write raw data here
     *      personality = "__dmd_personality_v0"
     *      ehunwind = will have EH unwind table
     * Returns:
     *      offset of start of this header
     * See_Also:
     *      https://refspecs.linuxfoundation.org/LSB_3.0.0/LSB-PDA/LSB-PDA/ehframechpt.html
     */
    private uint writeEhFrameHeader(IDXSEC dfseg, OutBuffer* buf, Symbol* personality, bool ehunwind)
    {
        /* Augmentation string:
         *  z = first character, means Augmentation Data field is present
         *  eh = EH Data field is present
         *  P = Augmentation Data contains 2 args:
         *          1. encoding of 2nd arg
         *          2. address of personality routine
         *  L = Augmentation Data contains 1 arg:
         *          1. the encoding used for Augmentation Data in FDE
         *      Augmentation Data in FDE:
         *          1. address of LSDA (gcc_except_table)
         *  R = Augmentation Data contains 1 arg:
         *          1. encoding of addresses in FDE
         * Non-EH code: "zR"
         * EH code: "zPLR"
         */

        const bool AArch64 = config.target_cpu == TARGET_AArch64;
        const uint startsize = cast(uint)buf.length();

        // Length of CIE, not including padding
        const uint cielen = 4 + 4 + 1 +
            (ehunwind ? 5 : 3) +
            1 + 1 + 1 +
            (ehunwind ? 8 : 2) +
            (AArch64 ? 3 : 5);

        const uint pad = -cielen & (AArch64 ? 3 : (I64 ? 7 : 3));  // pad to addressing unit size boundary
        const uint length = cielen + pad - 4;

        buf.reserve(length + 4);
        buf.write32(length);       // length of CIE, not including length and extended length fields
        buf.write32(0);            // CIE ID
        buf.writeByten(1);         // version_
        if (ehunwind)
            buf.write("zPLR".ptr, 5);  // Augmentation String
        else
            buf.writen("zR".ptr, 3);
        // not present: EH Data: 4 bytes for I32, 8 bytes for I64
        buf.writeByten(AArch64 ? 4 : 1);                // code alignment factor
        buf.writeByten(cast(ubyte)(0x80 - OFFSET_FAC)); // data alignment factor (I64 ? -8 : -4)
        buf.writeByten(AArch64 ? 30 : (I64 ? 16 : 8));  // return address register
        if (ehunwind)
        {
            ubyte personality_pointer_encoding = 0;
            ubyte LSDA_pointer_encoding = 0;
            ubyte address_pointer_encoding = 0;
            if (config.objfmt == OBJ_ELF)
            {
                personality_pointer_encoding = config.flags3 & CFG3pic
                            ? DW_EH_PE_indirect | DW_EH_PE_pcrel | DW_EH_PE_sdata4
                            : DW_EH_PE_absptr | DW_EH_PE_udata4;
                LSDA_pointer_encoding = config.flags3 & CFG3pic
                            ? DW_EH_PE_pcrel | DW_EH_PE_sdata4
                            : DW_EH_PE_absptr | DW_EH_PE_udata4;
                address_pointer_encoding =
                            DW_EH_PE_pcrel | DW_EH_PE_sdata4;
            }
            else if (config.objfmt == OBJ_MACH)
            {
                personality_pointer_encoding =
                            DW_EH_PE_indirect | DW_EH_PE_pcrel | DW_EH_PE_sdata4;
                LSDA_pointer_encoding =
                            DW_EH_PE_pcrel | DW_EH_PE_ptr;
                address_pointer_encoding =
                            DW_EH_PE_pcrel | DW_EH_PE_ptr;
            }
            buf.writeByten(7);                                  // Augmentation Length
            buf.writeByten(personality_pointer_encoding);       // P: personality routine address encoding
            /* MACHOBJ 64: pcrel 1 length 2 extern 1 RELOC_GOT
             *         32: [4] address x0013 pcrel 0 length 2 value xfc type 4 RELOC_LOCAL_SECTDIFF
             *             [5] address x0000 pcrel 0 length 2 value xc7 type 1 RELOC_PAIR
             */
            if (config.objfmt == OBJ_ELF)
                elf_dwarf_reftoident(dfseg, buf.length(), personality, 0);
            else
                mach_dwarf_reftoident(dfseg, buf.length(), personality, 0);
            buf.writeByten(LSDA_pointer_encoding);              // L: address encoding for LSDA in FDE
            buf.writeByten(address_pointer_encoding);           // R: encoding of addresses in FDE
        }
        else
        {
            buf.writeByten(1);                                  // Augmentation Length

            if (config.objfmt == OBJ_ELF)
                    buf.writeByten(DW_EH_PE_pcrel | DW_EH_PE_sdata4);   // R: encoding of addresses in FDE
            else if (config.objfmt == OBJ_MACH)
                    buf.writeByten(DW_EH_PE_pcrel | DW_EH_PE_ptr);      // R: encoding of addresses in FDE
        }

        // Set CFA beginning state at function entry point
        if (I64)
        {
            if (AArch64)
            {
                buf.writeByten(DW_CFA_def_cfa);        // DEF_CFA r31,0   RSP is at offset 0
                buf.writeByten(31);                    // r31 is RSP
                buf.writeByten(0);
            }
            else
            {
                buf.writeByten(DW_CFA_def_cfa);        // DEF_CFA r7,8   RSP is at offset 8
                buf.writeByten(7);                     // r7 is RSP
                buf.writeByten(8);

                buf.writeByten(DW_CFA_offset + 16);    // OFFSET r16,1   RIP is at -8*1[RSP]
                buf.writeByten(1);
            }
        }
        else
        {
            buf.writeByten(DW_CFA_def_cfa);        // DEF_CFA ESP,4
            buf.writeByten(cast(ubyte)dwarf_regno(SP));
            buf.writeByten(4);

            buf.writeByten(DW_CFA_offset + 8);     // OFFSET r8,1
            buf.writeByten(1);
        }

        for (uint i = 0; i < pad; ++i)
            buf.writeByten(DW_CFA_nop);

        assert(startsize + length + 4 == buf.length());
        return startsize;
    }

    /*********************************************
     * Generate function's Frame Description Entry into .debug_frame
     * Params:
     *      dfseg = SegData[] index for .debug_frame
     *      sfunc = the function
     */
    void writeDebugFrameFDE(IDXSEC dfseg, Symbol* sfunc)
    {
        if (I64)
        {
            static struct DebugFrameFDE64
            {
              align (1):
                uint length;
                uint CIE_pointer;
                ulong initial_location;
                ulong address_range;
            }
            static assert(DebugFrameFDE64.sizeof == 24);

            __gshared DebugFrameFDE64 debugFrameFDE64 =
            {
                20,             // length
                0,              // CIE_pointer
                0,              // initial_location
                0,              // address_range
            };

            // Pad to 8 byte boundary
            for (uint n = (-cfa_buf.length() & 7); n; n--)
                cfa_buf.writeByte(DW_CFA_nop);

            debugFrameFDE64.length = 20 + cast(uint)cfa_buf.length();
            debugFrameFDE64.address_range = sfunc.Ssize;
            // Do we need this?
            //debugFrameFDE64.initial_location = sfunc.Soffset;

            OutBuffer* debug_frame_buf = SegData[dfseg].SDbuf;
            uint debug_frame_buf_offset = cast(uint)debug_frame_buf.length();
            debug_frame_buf.reserve(1000);
            debug_frame_buf.writen(&debugFrameFDE64,debugFrameFDE64.sizeof);
            debug_frame_buf.write(cfa_buf[]);

            if (config.objfmt == OBJ_ELF)
                // Absolute address for debug_frame, relative offset for eh_frame
                dwarf_addrel(dfseg,debug_frame_buf_offset + 4,dfseg,0);

            dwarf_addrel64(dfseg,debug_frame_buf_offset + 8,sfunc.Sseg,0);
        }
        else
        {
            static struct DebugFrameFDE32
            {
              align (1):
                uint length;
                uint CIE_pointer;
                uint initial_location;
                uint address_range;
            }
            static assert(DebugFrameFDE32.sizeof == 16);

            __gshared DebugFrameFDE32 debugFrameFDE32 =
            {
                12,             // length
                0,              // CIE_pointer
                0,              // initial_location
                0,              // address_range
            };

            // Pad to 4 byte boundary
            for (uint n = (-cfa_buf.length() & 3); n; n--)
                cfa_buf.writeByte(DW_CFA_nop);

            debugFrameFDE32.length = 12 + cast(uint)cfa_buf.length();
            debugFrameFDE32.address_range = cast(uint)sfunc.Ssize;
            // Do we need this?
            //debugFrameFDE32.initial_location = sfunc.Soffset;

            OutBuffer* debug_frame_buf = SegData[dfseg].SDbuf;
            uint debug_frame_buf_offset = cast(uint)debug_frame_buf.length();
            debug_frame_buf.reserve(1000);
            debug_frame_buf.writen(&debugFrameFDE32,debugFrameFDE32.sizeof);
            debug_frame_buf.write(cfa_buf[]);

            if (config.objfmt == OBJ_ELF)
                // Absolute address for debug_frame, relative offset for eh_frame
                dwarf_addrel(dfseg,debug_frame_buf_offset + 4,dfseg,0);

            dwarf_addrel(dfseg,debug_frame_buf_offset + 8,sfunc.Sseg,0);
        }
    }

    /*********************************************
     * Append function's FDE (Frame Description Entry) to .eh_frame
     * Params:
     *      dfseg = SegData[] index for .eh_frame
     *      sfunc = the function
     *      ehunwind = will have EH unwind table
     *      CIE_offset = offset of enclosing CIE
     */
    void writeEhFrameFDE(IDXSEC dfseg, Symbol* sfunc, bool ehunwind, uint CIE_offset)
    {
        OutBuffer* buf = SegData[dfseg].SDbuf;
        const uint startsize = cast(uint)buf.length();

        Symbol* fdesym;
        if (config.objfmt == OBJ_MACH)
        {
            /* Create symbol named "funcname.eh" for the start of the FDE
             */
            const size_t len = strlen(getSymName(sfunc));
            char* name = cast(char*)malloc(len + 3 + 1);
            if (!name)
                err_nomem();
            memcpy(name, getSymName(sfunc), len);
            memcpy(name + len, ".eh".ptr, 3 + 1);
            fdesym = symbol_name(name[0 .. len + 3], SC.global, tspvoid);
            Obj.pubdef(dfseg, fdesym, startsize);
            symbol_keep(fdesym);
            free(name);
        }

        if (sfunc.ty() & mTYnaked)
        {
            /* Do not have info on naked functions. Assume they are set up as:
             *   push RBP
             *   mov  RSP,RSP
             */
            int off = 2 * REGSIZE;
            dwarf_CFA_set_loc(1);
            dwarf_CFA_set_reg_offset(SP, off);
            dwarf_CFA_offset(BP, -off);
            dwarf_CFA_set_loc(I64 ? 4 : 3);
            dwarf_CFA_set_reg_offset(BP, off);
        }

        // Length of FDE, not including padding
        uint fdelen = 0;
        if (config.objfmt == OBJ_ELF)
        {
            fdelen = 4 + 4
                + 4 + 4
                + (ehunwind ? 5 : 1) + cast(uint)cfa_buf.length();
        }
        else if (config.objfmt == OBJ_MACH)
        {
            fdelen = 4 + 4
                + (I64 ? 8 + 8 : 4 + 4)                         // PC_Begin + PC_Range
                + (ehunwind ? (I64 ? 9 : 5) : 1) + cast(uint)cfa_buf.length();
        }
        const uint pad = -fdelen & (I64 ? 7 : 3);      // pad to addressing unit size boundary
        const uint length = fdelen + pad - 4;

        buf.reserve(length + 4);
        buf.write32(length);                               // Length (no Extended Length)
        buf.write32((startsize + 4) - CIE_offset);         // CIE Pointer

        int fixup = 0;
        if (config.objfmt == OBJ_ELF)
        {
            fixup = I64 ? R_X86_64_PC32 : R_386_PC32;
            if (config.target_cpu == TARGET_AArch64)
                fixup = R_AARCH64_PREL32;
            buf.write32(cast(uint)(I64 ? 0 : sfunc.Soffset));             // address of function
            Obj.addrel(dfseg, startsize + 8, fixup, cast(int)MAP_SEG2SYMIDX(sfunc.Sseg), sfunc.Soffset);
            //Obj.reftoident(dfseg, startsize + 8, sfunc, 0, CFpc32 | CFoff); // PC_begin
            buf.write32(cast(uint)sfunc.Ssize);                         // PC Range
        }
        if (config.objfmt == OBJ_MACH)
        {
            dwarf_eh_frame_fixup(dfseg, buf.length(), sfunc, 0, fdesym);

            if (I64)
                buf.write64(sfunc.Ssize);                     // PC Range
            else
                buf.write32(cast(uint)sfunc.Ssize);           // PC Range
        }

        if (ehunwind)
        {
            int etseg = dwarf_except_table_alloc(sfunc);
            if (config.objfmt == OBJ_ELF)
            {
                buf.writeByten(4);                             // Augmentation Data Length
                buf.write32(I64 ? 0 : sfunc.Sfunc.LSDAoffset); // address of LSDA (".gcc_except_table")
                if (config.flags3 & CFG3pic)
                {
                    Obj.addrel(dfseg, buf.length() - 4, fixup, cast(int)MAP_SEG2SYMIDX(etseg), sfunc.Sfunc.LSDAoffset);
                }
                else
                    dwarf_addrel(dfseg, buf.length() - 4, etseg, sfunc.Sfunc.LSDAoffset);      // and the fixup
            }
            if (config.objfmt == OBJ_MACH)
            {
                buf.writeByten(I64 ? 8 : 4);                   // Augmentation Data Length
                dwarf_eh_frame_fixup(dfseg, buf.length(), sfunc.Sfunc.LSDAsym, 0, fdesym);
            }
        }
        else
            buf.writeByten(0);                             // Augmentation Data Length

        buf.write(cfa_buf[]);

        for (uint i = 0; i < pad; ++i)
            buf.writeByten(DW_CFA_nop);

        assert(startsize + length + 4 == buf.length());
    }

    void dwarf_initfile(const(char)* filename)
    {
        dwarf_initfile(filename ? filename[0 .. strlen(filename)] : null);
    }

    extern(D) void dwarf_initfile(const(char)[] filename)
    {
        if (config.ehmethod == EHmethod.EH_DWARF)
        {
            if (config.objfmt == OBJ_MACH)
            {
                except_table_seg = UNKNOWN;
                except_table_num = 0;
                eh_frame_seg = UNKNOWN;
                eh_frame_sym = null;
            }
            CIE_offset_unwind = ~0;
            CIE_offset_no_unwind = ~0;
            //dwarf_except_table_alloc();
            dwarf_eh_frame_alloc();
        }
        if (!config.fulltypes)
            return;
        if (config.ehmethod == EHmethod.EH_DM)
        {
            int flags = 0;
            if (config.objfmt == OBJ_MACH)
                flags = S_ATTR_DEBUG;
            if (config.objfmt == OBJ_ELF)
                flags = SHT_PROGBITS;

            int seg = dwarf_getsegment(debug_frame_name, 1, flags);
            OutBuffer* buf = SegData[seg].SDbuf;
            buf.reserve(1000);
            writeDebugFrameHeader(buf);
        }

        /* ======================================== */

        foreach (s; resetSyms)
            symbol_reset(*s);
        resetSyms.reset();

        /* *********************************************************************
         *                          String Table
         ******************************************************************** */
        {
            debug_str.initialize();
            //OutBuffer* debug_str_buf = debug_str.buf;
        }

        /* *********************************************************************
         *                2.17.3 Non-Contiguous Address Ranges
         ******************************************************************** */
        {
            debug_ranges.initialize();
        }

        /* *********************************************************************
         *                         2.6.6 Location Lists
         ******************************************************************** */
        {
            debug_loc.initialize();
        }

        /* *********************************************************************
         *                  6.2.4 The Line Number Program Header
         ******************************************************************** */
        {
            if (infoFileName_table)
            {
                infoFileName_table.destroy();
                infoFileName_table = null;
            }
            if (lineDirectories)
            {
                lineDirectories.destroy();
                lineDirectories = null;
            }

            debug_line.initialize();

            void writeDebugLineHeader(ushort hversion)()
            {
                struct DebugLineHeader
                {
                align (1):
                    uint length;
                    ushort version_= hversion;
                    static if (hversion >= 5)
                    {
                        ubyte address_size = 4;
                        ubyte segment_selector_size;
                    }
                    uint header_length;
                    ubyte minimum_instruction_length = 1;
                    static if (hversion >= 4)
                    {
                        ubyte maximum_operations_per_instruction = 1;
                    }
                    bool default_is_stmt = true;
                    byte line_base = .line_base;
                    ubyte line_range = .line_range;
                    ubyte opcode_base = .opcode_base;
                    ubyte[12] standard_opcode_lengths =
                    [
                        0,      // DW_LNS_copy
                        1,      // DW_LNS_advance_pc
                        1,      // DW_LNS_advance_line
                        1,      // DW_LNS_set_file
                        1,      // DW_LNS_set_column
                        0,      // DW_LNS_negate_stmt
                        0,      // DW_LNS_set_basic_block
                        0,      // DW_LNS_const_add_pc
                        1,      // DW_LNS_fixed_advance_pc
                        0,      // DW_LNS_set_prologue_end
                        0,      // DW_LNS_set_epilogue_begin
                        1,      // DW_LNS_set_isa
                    ];
                    static if (hversion >= 5)
                    {
                        ubyte directory_entry_format_count = directory_entry_format.sizeof / 2;
                        ubyte[2] directory_entry_format =
                        [
                            DW_LNCT_path,   DW_FORM_string,
                        ];
                    }
                }

                static if (hversion == 3)
                    static assert(DebugLineHeader.sizeof == 27);
                else static if (hversion == 4)
                    static assert(DebugLineHeader.sizeof == 28);
                else static if (hversion == 5)
                    static assert(DebugLineHeader.sizeof == 33);
                else
                    static assert(0);

                auto lineHeader = DebugLineHeader.init;

                // 6.2.5.2 Standard Opcodes
                static assert(DebugLineHeader.standard_opcode_lengths.length == opcode_base - 1);

                static if (hversion >= 5)
                {
                    if (I64)
                    {
                        lineHeader.address_size = 8;
                    }
                }
                lineHeaderLengthOffset = lineHeader.header_length.offsetof;

                debug_line.buf.writen(&lineHeader, lineHeader.sizeof);
            }

            if (config.dwarf == 3)
                writeDebugLineHeader!3();
            else if (config.dwarf == 4)
                writeDebugLineHeader!4();
            else
                writeDebugLineHeader!5();


            if (config.dwarf >= 5)
            {
                /*
                 * In DWARF Version 5, the current compilation file name is
                 * explicitly present and has index 0.
                 */
                dwarf_line_addfile(filename.ptr);
                dwarf_line_add_directory(filename.ptr);
            }

            linebuf_filetab_end = debug_line.buf.length();
            // remaining fields in dwarf_termfile()
        }

        /* *********************************************************************
         *                     7.5.3 Abbreviations Tables
         ******************************************************************** */
        {
            debug_abbrev.initialize();
            abbrevcode = 1;

            // Free only if starting another file. Waste of time otherwise.
            if (abbrev_table)
            {
                abbrev_table.destroy();
                abbrev_table = null;
            }

            static immutable ubyte[21] abbrevHeader =
            [
                1,                      // abbreviation code
                DW_TAG_compile_unit, DW_CHILDREN_yes,
                DW_AT_producer,      DW_FORM_string,
                DW_AT_language,      DW_FORM_data1,
                DW_AT_name,          DW_FORM_string,
                DW_AT_comp_dir,      DW_FORM_string,
                DW_AT_low_pc,        DW_FORM_addr,
                DW_AT_entry_pc,      DW_FORM_addr,
                DW_AT_ranges,        DW_FORM_data4,
                DW_AT_stmt_list,     DW_FORM_data4,
                0,                   0,
            ];

            debug_abbrev.buf.write(abbrevHeader.ptr,abbrevHeader.sizeof);
        }

        /* *********************************************************************
         *             7.5.1.1 Full and Partial Compilation Unit Headers
         ******************************************************************** */
        {
            debug_info.initialize();

            void writeCompilationUnitHeader(ubyte hversion)()
            {
                struct CompilationUnitHeader
                {
                align(1):
                    uint length;
                    ushort version_ = hversion;
                    static if (hversion >= 5)
                    {
                        ubyte unit_type = DW_UT_compile;
                        ubyte address_size = 4;
                    }
                    uint debug_abbrev_offset;
                    static if (hversion < 5)
                    {
                        ubyte address_size = 4;
                    }
                }

                static if (hversion == 3 || hversion == 4)
                    static assert(CompilationUnitHeader.sizeof == 11);
                else static if (hversion == 5)
                    static assert(CompilationUnitHeader.sizeof == 12);
                else
                    static assert(0);

                auto cuh = CompilationUnitHeader.init;

                if (I64)
                    cuh.address_size = 8;

                debug_info.buf.writen(&cuh, cuh.sizeof);

                if (config.objfmt == OBJ_ELF)
                    dwarf_addrel(debug_info.seg, CompilationUnitHeader.debug_abbrev_offset.offsetof, debug_abbrev.seg);
            }

            if (config.dwarf == 3)
                writeCompilationUnitHeader!3();
            else if (config.dwarf == 4)
                writeCompilationUnitHeader!4();
            else
                writeCompilationUnitHeader!5();

            debug_info.buf.writeuLEB128(1);                   // abbreviation code

            debug_info.buf.write("Digital Mars D ");
            debug_info.buf.writeStringz(config._version);     // DW_AT_producer
            // DW_AT_language
            auto language = (config.fulltypes == CVDWARF_D) ? DW_LANG_D : DW_LANG_C89;
            /* if source file has .c or .i extension, emit C debug info
             */
            if (filename.length >= 2 &&
                filename[$ - 2] == '.' &&
                (filename[$ - 1] == 'c' || filename[$ - 1] == 'i'))
                language = DW_LANG_C89;
            debug_info.buf.writeByte(language);

            debug_info.buf.writeStringz(filename);             // DW_AT_name

            char* cwd = getcwd(null, 0);
            debug_info.buf.writeStringz(cwd);                  // DW_AT_comp_dir as DW_FORM_string
            free(cwd);

            append_addr(debug_info.buf, 0);               // DW_AT_low_pc
            append_addr(debug_info.buf, 0);               // DW_AT_entry_pc

            if (config.objfmt == OBJ_ELF)
                dwarf_addrel(debug_info.seg,debug_info.buf.length(),debug_ranges.seg);

            debug_info.buf.write32(0);                        // DW_AT_ranges

            if (config.objfmt == OBJ_ELF)
                dwarf_addrel(debug_info.seg,debug_info.buf.length(),debug_line.seg);

            debug_info.buf.write32(0);                        // DW_AT_stmt_list

            memset(typidx_tab.ptr, 0, typidx_tab.sizeof);
        }

        /* *********************************************************************
         *                        6.1.1 Lookup by Name
         ******************************************************************** */
        {
            debug_pubnames.initialize();
            int seg = debug_pubnames.seg;

            debug_pubnames.buf.write32(0);             // unit_length
            debug_pubnames.buf.write16(2);           // version_

            if (config.objfmt == OBJ_ELF)
                dwarf_addrel(seg,debug_pubnames.buf.length(),debug_info.seg);

            debug_pubnames.buf.write32(0);             // debug_info_offset
            debug_pubnames.buf.write32(0);             // debug_info_length
        }

        /* *********************************************************************
         *                      6.1.2 Lookup by Address
         ******************************************************************** */
        {
            debug_aranges.initialize();

            void writeAddressRangeHeader(ushort hversion)()
            {
                struct AddressRangeHeader
                {
                align(1):
                    uint length;
                    ushort version_ = hversion;
                    uint debug_info_offset;
                    ubyte address_size = 4;
                    ubyte segment_size;
                    uint padding;
                }
                static if (hversion == 2)
                    static assert(AddressRangeHeader.sizeof == 16);
                else
                    static assert(0);

                auto arh = AddressRangeHeader.init;

                if (I64)
                    arh.address_size = 8;

                debug_aranges.buf.writen(&arh, arh.sizeof);

                if (config.objfmt == OBJ_ELF)
                    dwarf_addrel(debug_aranges.seg, AddressRangeHeader.debug_info_offset.offsetof, debug_info.seg);
            }

            writeAddressRangeHeader!2();
        }
    }

    /*************************************
     * Add a directory to `lineDirectories`
     */
    uint dwarf_line_add_directory(const(char)* path)
    {
        assert(path);
        return addToAAchars(lineDirectories, retrieveDirectory(path));
    }

    /*************************************
     * Add a file to `infoFileName_table`
     */
    uint dwarf_line_addfile(const(char)* path)
    {
        assert(path);
        return addToAAchars(infoFileName_table, path[0 .. strlen(path)]);
    }

    /*************************************
     * Adds `str` to `aachars`, and assigns a new index if none
     *
     * Params:
     *      aachars = AAchars where to add `str`
     *      str = string to add to `aachars`
     */
    extern(D) uint addToAAchars(ref AAchars* aachars, const(char)[] str)
    {
        if (!aachars)
        {
            aachars = AAchars.create();
        }

        uint* pidx = aachars.get(str);
        if (!*pidx)                 // if no idx assigned yet
        {
            *pidx = cast(uint) aachars.length(); // assign newly computed idx
        }
        return* pidx;
    }

    /**
     * Extracts the directory from `path`.
     *
     * Params:
     *      path = Full path containing the filename and the directory
     * Returns:
     *      The directory name
     */
    extern(D) const(char)[] retrieveDirectory(const(char)* path)
    {
        assert(path);
        // Retrieve directory from path
        char* lastSep = strrchr(cast(char*) path, DIRCHAR);
        return lastSep ? path[0 .. lastSep - path] : ".";
    }

    void dwarf_initmodule(const(char)* filename, const(char)* modname)
    {
        dwarf_initmodule(filename ? filename[0 .. strlen(filename)] : null,
                         modname ? modname[0 .. strlen(modname)] : null);
    }

    extern(D) void dwarf_initmodule(const(char)[] filename, const(char)[] modname)
    {
        if (modname)
        {
            static immutable ubyte[6] abbrevModule =
            [
                DW_TAG_module, DW_CHILDREN_no,
                DW_AT_name,    DW_FORM_string, // module name
                0,             0,
            ];
            abbrevcode++;
            debug_abbrev.buf.writeuLEB128(abbrevcode);
            debug_abbrev.buf.write(abbrevModule.ptr, abbrevModule.sizeof);
            debug_info.buf.writeuLEB128(abbrevcode);      // abbreviation code
            debug_info.buf.writeStringz(modname);          // DW_AT_name
            //hasModname = 1;
        }
        else
            hasModname = 0;
    }

    void dwarf_termmodule()
    {
        if (hasModname)
            debug_info.buf.writeByte(0);  // end of DW_TAG_module's children
    }

    /*************************************
     * Finish writing Dwarf debug info to object file.
     */
    void dwarf_termfile()
    {
        //printf("dwarf_termfile()\n");

        /* *********************************************************************
         *      6.2.4 The Line Number Program Header - Remaining fields
         ******************************************************************** */
        {
            // assert we haven't emitted anything
            assert(debug_line.buf.length() == linebuf_filetab_end);

            // Put out line number info

            // file_names
            uint last_filenumber = 0;
            const(char)* last_filename = null;
            for (uint seg = 1; seg < SegData.length; seg++)
            {
                for (uint i = 0; i < SegData[seg].SDlinnum_data.length; i++)
                {
                    linnum_data* ld = &SegData[seg].SDlinnum_data[i];
                    const(char)* filename;

                    filename = ld.filename;

                    if (last_filename == filename)
                    {
                        ld.filenumber = last_filenumber;
                    }
                    else
                    {
                        ld.filenumber = dwarf_line_addfile(filename);
                        dwarf_line_add_directory(filename);

                        last_filenumber = ld.filenumber;
                        last_filename = filename;
                    }
                }
            }

            if (config.dwarf >= 5)
            {
                debug_line.buf.writeuLEB128(lineDirectories ? cast(uint) lineDirectories.length() : 0);   // directories_count
            }

            if (lineDirectories)
            {
                // include_directories
                auto dirkeys = lineDirectories.keys();
                if (dirkeys)
                {
                    foreach (id; 1 .. lineDirectories.length() + 1)
                    {
                        foreach (const(char)[] dir; dirkeys)
                        {
                            // Directories must be written in the correct order, to match file_name indexes
                            if (dwarf_line_add_directory(dir.ptr) == id)
                            {
                                //printf("%d: %s\n", dwarf_line_add_directory(dir), dir);
                                debug_line.buf.writeStringz(dir);
                                break;
                            }
                        }
                    }
                    free(dirkeys.ptr);
                    dirkeys = null;
                }
            }

            if (config.dwarf < 5)
            {
                debug_line.buf.writeByte(0);   // end of include_directories
            }
            else
            {
                struct FileNameEntryFormat
                {
                    ubyte count = format.sizeof / 2;
                    ubyte[4] format =
                    [
                        DW_LNCT_path,               DW_FORM_string,
                        DW_LNCT_directory_index,    DW_FORM_data1,
                    ];
                }
                auto file_name_entry_format = FileNameEntryFormat.init;
                debug_line.buf.write(&file_name_entry_format, file_name_entry_format.sizeof);

                debug_line.buf.writeuLEB128(infoFileName_table ? cast(uint) infoFileName_table.length() : 0);  // file_names_count
            }

            if (infoFileName_table)
            {
                // file_names
                auto filekeys = infoFileName_table.keys();
                if (filekeys)
                {
                    foreach (id; 1 .. infoFileName_table.length() + 1)
                    {
                        foreach (const(char)[] filename; filekeys)
                        {
                            // Filenames must be written in the correct order, to match the AAchars' idx order
                            if (id == dwarf_line_addfile(filename.ptr))
                            {
                                debug_line.buf.writeStringz(filename.ptr.filespecname);

                                auto index = dwarf_line_add_directory(filename.ptr);
                                assert(index != 0);
                                if (config.dwarf >= 5)
                                    --index; // Minus 1 because it must be an index, not a element number
                                // directory table index.
                                debug_line.buf.writeByte(index);
                                if (config.dwarf < 5)
                                {
                                    debug_line.buf.writeByte(0);      // mtime
                                    debug_line.buf.writeByte(0);      // length
                                }
                                break;
                            }
                        }
                    }
                    free(filekeys.ptr);
                    filekeys = null;
                }
            }

            if (config.dwarf < 5)
                debug_line.buf.writeByte(0);              // end of file_names

            rewrite32(debug_line.buf, lineHeaderLengthOffset, cast(uint) (debug_line.buf.length() - lineHeaderLengthOffset - 4));
        }

        for (uint seg = 1; seg < SegData.length; seg++)
        {
            seg_data* sd = SegData[seg];
            uint addressmax = 0;
            uint linestart = ~0;

            if (!sd.SDlinnum_data.length)
                continue;

            //printf("sd = %x, SDlinnum_count = %d\n", sd, sd.SDlinnum_count);
            for (int i = 0; i < sd.SDlinnum_data.length; i++)
            {   linnum_data* ld = &sd.SDlinnum_data[i];

                // Set address to start of segment with DW_LNE_set_address
                debug_line.buf.writeByte(0);
                debug_line.buf.writeByte(_tysize[TYnptr] + 1);
                debug_line.buf.writeByte(DW_LNE_set_address);

                dwarf_appreladdr(debug_line.seg,debug_line.buf,seg,0);

                // Dwarf2 6.2.2 State machine registers
                uint address = 0;       // instruction address
                uint file = ld.filenumber;
                uint line = 1;          // line numbers beginning with 1

                debug_line.buf.writeByte(DW_LNS_set_file);
                debug_line.buf.writeuLEB128(file);

                for (int j = 0; j < ld.linoff.length; j++)
                {   int lininc = ld.linoff[j].lineNumber - line;
                    int addinc = ld.linoff[j].offset - address;

                    //printf("\tld[%d] line = %d offset = x%x lininc = %d addinc = %d\n", j, ld.linoff[j].lineNumber, ld.linoff[j].offset, lininc, addinc);

                    //assert(addinc >= 0);
                    if (addinc < 0)
                        continue;
                    if (j && lininc == 0 && !(addinc && j + 1 == ld.linoff.length))
                        continue;
                    line += lininc;
                    if (line < linestart)
                        linestart = line;
                    address += addinc;
                    if (address >= addressmax)
                        addressmax = address + 1;
                    if (lininc >= line_base && lininc < line_base + line_range)
                    {
                        uint opcode = lininc - line_base +
                            line_range * addinc + opcode_base;

                        // special opcode
                        if (opcode <= 255)
                        {
                            debug_line.buf.writeByte(opcode);
                            continue;
                        }
                    }
                    if (lininc)
                    {
                        debug_line.buf.writeByte(DW_LNS_advance_line);
                        debug_line.buf.writesLEB128(cast(int)lininc);
                    }
                    if (addinc)
                    {
                        debug_line.buf.writeByte(DW_LNS_advance_pc);
                        debug_line.buf.writeuLEB128(cast(uint)addinc);
                    }
                    if (lininc || addinc)
                        debug_line.buf.writeByte(DW_LNS_copy);
                }

                // Write DW_LNS_advance_pc to cover the function prologue
                debug_line.buf.writeByte(DW_LNS_advance_pc);
                debug_line.buf.writeuLEB128(cast(uint)(sd.SDbuf.length() - address));

                // Write DW_LNE_end_sequence
                debug_line.buf.writeByte(0);
                debug_line.buf.writeByte(1);
                debug_line.buf.writeByte(1);

                // reset linnum_data
                ld.linoff.reset();
            }
        }

        rewrite32(debug_line.buf, 0, cast(uint) debug_line.buf.length() - 4);

        /* ================================================= */

        debug_abbrev.buf.writeByte(0);

        /* ================================================= */

        // debug_info
        {
            debug_info.buf.writeByte(0);    // ending abbreviation code
            rewrite32(debug_info.buf, 0, cast(uint) debug_info.buf.length() - 4); // rewrites the unit length
        }


        /* ================================================= */

        // Terminate by offset field containing 0
        debug_pubnames.buf.write32(0);

        // Plug final sizes into header
        *cast(uint*)debug_pubnames.buf.buf = cast(uint)debug_pubnames.buf.length() - 4;
        *cast(uint*)(debug_pubnames.buf.buf + 10) = cast(uint)debug_info.buf.length();

        /* ================================================= */

        // Terminate by address/length fields containing 0
        append_addr(debug_aranges.buf, 0);
        append_addr(debug_aranges.buf, 0);

        // Plug final sizes into header
        *cast(uint*)debug_aranges.buf.buf = cast(uint)debug_aranges.buf.length() - 4;

        /* ================================================= */

        // Terminate by beg address/end address fields containing 0
        append_addr(debug_ranges.buf, 0);
        append_addr(debug_ranges.buf, 0);

        /* ================================================= */

        // Free only if starting another file. Waste of time otherwise.
        if (type_table)
        {
            type_table.destroy();
            type_table = null;
        }
        if (functype_table)
        {
            functype_table.destroy();
            functype_table = null;
        }
        if (functypebuf)
            functypebuf.reset();
    }

    /*****************************************
     * Start of code gen for function.
     */
    void dwarf_func_start(Symbol* sfunc)
    {
        //printf("dwarf_func_start(%s)\n", sfunc.Sident.ptr);
        if (config.target_cpu == TARGET_AArch64)
        {
            memset(&CFA_state_current,0,CFA_state.sizeof);
            CFA_state_current.offset   = 4;
            CFA_state_current.reg      = 31;      // SP
            CFA_state_current.regstates[32].offset = -8; // PC
        }
        else
        {
            if (I16 || I32)
                CFA_state_current = CFA_state_init_32;
            else if (I64)
                CFA_state_current = CFA_state_init_64;
            else
                assert(0);
            CFA_state_current.reg = dwarf_regno(SP);
            assert(CFA_state_current.offset == OFFSET_FAC);
        }
        cfa_buf.reset();
    }

    /*****************************************
     * End of code gen for function.
     */
    void dwarf_func_term(Symbol* sfunc)
    {
        //printf("dwarf_func_term(sfunc = '%s')\n", sfunc.Sident.ptr);

        if (config.ehmethod == EHmethod.EH_DWARF)
        {
            bool ehunwind = doUnwindEhFrame();

            IDXSEC dfseg = dwarf_eh_frame_alloc();

            OutBuffer* buf = SegData[dfseg].SDbuf;
            buf.reserve(1000);

            uint* poffset = ehunwind ? &CIE_offset_unwind : &CIE_offset_no_unwind;
            if (*poffset == ~0)
                *poffset = writeEhFrameHeader(dfseg, buf, getRtlsymPersonality(), ehunwind);

            writeEhFrameFDE(dfseg, sfunc, ehunwind, *poffset);
        }
        if (!config.fulltypes)
            return;

        if (sfunc.Sflags & SFLnodebug)
            return;
        const(char)* filename = sfunc.Sfunc.Fstartline.Sfilename;
        if (!filename)
            return;

        uint funcabbrevcode;

        if (ehmethod(sfunc) == EHmethod.EH_DM)
        {
            int flags = 0;
            if (config.objfmt == OBJ_MACH)
                flags = S_ATTR_DEBUG;
            else if (config.objfmt == OBJ_ELF)
                flags = SHT_PROGBITS;

            IDXSEC dfseg = dwarf_getsegment(debug_frame_name, 1, flags);
            writeDebugFrameFDE(dfseg, sfunc);
        }

        IDXSEC seg = sfunc.Sseg;
        seg_data* sd = SegData[seg];

        int filenum = dwarf_line_addfile(filename);

        uint ret_type = dwarf_typidx(sfunc.Stype.Tnext);
        if (tybasic(sfunc.Stype.Tnext.Tty) == TYvoid)
            ret_type = 0;

        // See if there are any parameters
        int haveparameters = 0;
        uint formalcode = 0;
        uint variablecode = 0;

        DWARFAbbrev dwarfabbrev;

        foreach (sa; globsym[])
        {
            if (sa.Sflags & SFLnodebug) continue;

            static immutable uint[14] formal_var_abbrev_suffix =
            [
                DW_AT_name,       DW_FORM_string,
                DW_AT_type,       DW_FORM_ref4,
                DW_AT_artificial, DW_FORM_flag,
                DW_AT_decl_file,   DW_FORM_data1,
                DW_AT_decl_line,   DW_FORM_udata,
                DW_AT_decl_column, DW_FORM_udata,
                DW_AT_location,    DW_FORM_block1,
            ];

            switch (sa.Sclass)
            {
                case SC.parameter:
                case SC.regpar:
                case SC.fastpar:
                    // discard index
                    cast(void)dwarf_typidx(sa.Stype);
                    if (!formalcode)
                    {
                        dwarfabbrev.append(DW_TAG_formal_parameter, DW_CHILDREN_no);
                        formalcode = dwarfabbrev.awrite!formal_var_abbrev_suffix;
                    }
                    haveparameters = DW_CHILDREN_yes;
                    break;

                case SC.auto_:
                case SC.bprel:
                case SC.register:
                case SC.pseudo:
                    // discard index
                    cast(void)dwarf_typidx(sa.Stype);
                    if (!variablecode)
                    {
                        dwarfabbrev.append(DW_TAG_variable, DW_CHILDREN_no);
                        variablecode = dwarfabbrev.awrite!formal_var_abbrev_suffix;
                    }
                    haveparameters = DW_CHILDREN_yes;
                    break;

                default:
                    break;
            }
        }

        dwarfabbrev.append(DW_TAG_subprogram, haveparameters);
        if (haveparameters == DW_CHILDREN_yes)
            dwarfabbrev.append(DW_AT_sibling, DW_FORM_ref4);

        dwarfabbrev.append(
            config.dwarf >= 4
                ? DW_AT_linkage_name
                : DW_AT_MIPS_linkage_name,
            DW_FORM_string
        );

        if (ret_type)
            dwarfabbrev.append(DW_AT_type, DW_FORM_ref4);

        if (sfunc.Sclass == SC.global)
            dwarfabbrev.append(DW_AT_external, DW_FORM_flag);

        if (sfunc.Sfunc.Fflags3 & Fmain)
        {
            if (config.dwarf >= 4)
            {
                dwarfabbrev.append(DW_AT_main_subprogram, DW_FORM_flag_present);
                if (config.flags2 & CFG2genmain)
                    dwarfabbrev.append(DW_AT_artificial, DW_FORM_flag_present);
            } else {
                if (config.flags2 & CFG2genmain)
                    dwarfabbrev.append(DW_AT_artificial, DW_FORM_flag);
            }
        }
        if (config.dwarf >= 5 && sfunc.Sflags & SFLexit)
            dwarfabbrev.append(DW_AT_noreturn, DW_FORM_flag_present);

        if (sfunc.Sfunc.Fflags3 & Fpure)
            dwarfabbrev.append(
                DW_AT_pure,
                config.dwarf >= 4
                    ? DW_FORM_flag_present
                    : DW_FORM_flag
            );

        funcabbrevcode = dwarfabbrev.awrite!([
            DW_AT_name, DW_FORM_string,
            DW_AT_decl_file, DW_FORM_data1,
            DW_AT_decl_line, DW_FORM_udata,
            DW_AT_decl_column, DW_FORM_udata,
            DW_AT_low_pc, DW_FORM_addr,
            DW_AT_high_pc, DW_FORM_addr,
            DW_AT_frame_base, DW_FORM_data4,
        ]);

        uint idxsibling = 0;
        uint siblingoffset;

        uint infobuf_offset = cast(uint)debug_info.buf.length();
        debug_info.buf.writeuLEB128(funcabbrevcode); // abbreviation code
        if (haveparameters == DW_CHILDREN_yes)
        {
            siblingoffset = cast(uint)debug_info.buf.length();
            debug_info.buf.write32(idxsibling);                       // DW_AT_sibling
        }

        const(char)* name = getSymName(sfunc);

        debug_info.buf.writeStringz(sfunc.Sident.ptr);                 // DW_AT_MIPS_linkage_name
        if (ret_type)
            debug_info.buf.write32(ret_type);                         // DW_AT_type

        if (sfunc.Sclass == SC.global)
            debug_info.buf.writeByte(1);                              // DW_AT_external

        if (config.dwarf < 4
            && sfunc.Sfunc.Fflags3 & Fmain
            && config.flags2 & CFG2genmain)
            debug_info.buf.writeByte(true);                           // DW_AT_artificial
        if (config.dwarf < 4 && sfunc.Sfunc.Fflags3 & Fpure)
            debug_info.buf.writeByte(true);                           // DW_AT_pure

        debug_info.buf.writeStringz(name);                             // DW_AT_name
        debug_info.buf.writeByte(filenum);                            // DW_AT_decl_file
        debug_info.buf.writeuLEB128(sfunc.Sfunc.Fstartline.Slinnum);  // DW_AT_decl_line
        debug_info.buf.writeuLEB128(sfunc.Sfunc.Fstartline.Scharnum); // DW_AT_decl_column

        // DW_AT_low_pc and DW_AT_high_pc
        dwarf_appreladdr(debug_info.seg, debug_info.buf, seg, cgstate.funcoffset);
        dwarf_appreladdr(debug_info.seg, debug_info.buf, seg, cgstate.funcoffset + sfunc.Ssize);

        // DW_AT_frame_base
        if (config.objfmt == OBJ_ELF)
            dwarf_apprel32(debug_info.seg, debug_info.buf, debug_loc.seg, debug_loc.buf.length());
        else
            // 64-bit DWARF relocations don't work for OSX64 codegen
            debug_info.buf.write32(cast(uint)debug_loc.buf.length());

        if (haveparameters)
        {
            foreach (sa; globsym[])
            {
                if (sa.Sflags & SFLnodebug)
                    continue;

                uint vcode;

                switch (sa.Sclass)
                {
                    case SC.parameter:
                    case SC.regpar:
                    case SC.fastpar:
                        vcode = formalcode;
                        goto L1;
                    case SC.auto_:
                    case SC.register:
                    case SC.pseudo:
                    case SC.bprel:
                        vcode = variablecode;
                    L1:
                    {
                        uint soffset;
                        uint tidx = dwarf_typidx(sa.Stype);

                        debug_info.buf.writeuLEB128(vcode);           // abbreviation code
                        debug_info.buf.writeStringz(getSymName(sa));   // DW_AT_name
                        debug_info.buf.write32(tidx);                 // DW_AT_type
                        debug_info.buf.writeByte(sa.Sflags & SFLartifical ? 1 : 0); // DW_FORM_tag
                        debug_info.buf.writeByte(filenum);            // DW_AT_decl_file
                        debug_info.buf.writeuLEB128(sa.lposscopestart.Slinnum);   // DW_AT_decl_line
                        debug_info.buf.writeuLEB128(sa.lposscopestart.Scharnum);   // DW_AT_decl_column
                        soffset = cast(uint)debug_info.buf.length();
                        debug_info.buf.writeByte(2);                  // DW_FORM_block1
                        if (sa.Sfl == FL.reg || sa.Sclass == SC.pseudo)
                        {
                            // BUG: register pairs not supported in Dwarf?
                            debug_info.buf.writeByte(DW_OP_reg0 + sa.Sreglsw);
                        }
                        else if (sa.Sscope && vcode == variablecode)
                        {
                            assert(sa.Sscope.Stype.Tnext && sa.Sscope.Stype.Tnext.Tty == TYstruct);

                            /* find member offset in closure */
                            targ_size_t memb_off = 0;
                            struct_t* st = sa.Sscope.Stype.Tnext.Ttag.Sstruct; // Sscope is __closptr
                            foreach (sl; ListRange(st.Sfldlst))
                            {
                                Symbol* sf = list_symbol(sl);
                                if (sf.Sclass == SC.member)
                                {
                                    if(strcmp(sa.Sident.ptr, sf.Sident.ptr) == 0)
                                    {
                                        memb_off = sf.Smemoff;
                                        goto L2;
                                    }
                                }
                            }
                        L2:
                            targ_size_t closptr_off = sa.Sscope.Soffset; // __closptr offset
                            //printf("dwarf closure: sym: %s, closptr: %s, ptr_off: %lli, memb_off: %lli\n",
                            //    sa.Sident.ptr, sa.Sscope.Sident.ptr, closptr_off, memb_off);

                            debug_info.buf.writeByte(DW_OP_fbreg);
                            debug_info.buf.writesLEB128(cast(uint)(cgstate.Auto.size + cgstate.BPoff - cgstate.Para.size + closptr_off)); // closure pointer offset from frame base
                            debug_info.buf.writeByte(DW_OP_deref);
                            debug_info.buf.writeByte(DW_OP_plus_uconst);
                            debug_info.buf.writeuLEB128(cast(uint)memb_off); // closure variable offset
                        }
                        else
                        {
                            debug_info.buf.writeByte(DW_OP_fbreg);
                            if (sa.Sclass == SC.regpar ||
                                sa.Sclass == SC.parameter)
                                debug_info.buf.writesLEB128(cast(int)sa.Soffset);
                            else if (sa.Sclass == SC.fastpar)
                                debug_info.buf.writesLEB128(cast(int)(cgstate.Fast.size + cgstate.BPoff - cgstate.Para.size + sa.Soffset));
                            else if (sa.Sclass == SC.bprel)
                                debug_info.buf.writesLEB128(cast(int)(-cgstate.Para.size + sa.Soffset));
                            else
                                debug_info.buf.writesLEB128(cast(int)(cgstate.Auto.size + cgstate.BPoff - cgstate.Para.size + sa.Soffset));
                        }
                        debug_info.buf.buf[soffset] = cast(ubyte)(debug_info.buf.length() - soffset - 1);
                        break;
                    }
                    default:
                        break;
                }
            }
            debug_info.buf.writeByte(0);              // end of parameter children

            idxsibling = cast(uint)debug_info.buf.length();
            *cast(uint*)(debug_info.buf.buf + siblingoffset) = idxsibling;
        }

        /* ============= debug_pubnames =========================== */

        debug_pubnames.buf.write32(infobuf_offset);
        debug_pubnames.buf.writeStringz(name);

        /* ============= debug_aranges =========================== */

        if (sd.SDaranges_offset)
            // Extend existing entry size
            *cast(ulong*)(debug_aranges.buf.buf + sd.SDaranges_offset + _tysize[TYnptr]) = cgstate.funcoffset + sfunc.Ssize;
        else
        {   // Add entry
            sd.SDaranges_offset = cast(uint)debug_aranges.buf.length();
            // address of start of .text segment
            dwarf_appreladdr(debug_aranges.seg, debug_aranges.buf, seg, 0);
            // size of .text segment
            append_addr(debug_aranges.buf, cgstate.funcoffset + sfunc.Ssize);
        }

        /* ============= debug_ranges =========================== */

        /* Each function gets written into its own segment,
         * indicate this by adding to the debug_ranges
         */
        // start of function and end of function
        dwarf_appreladdr(debug_ranges.seg, debug_ranges.buf, seg, cgstate.funcoffset);
        dwarf_appreladdr(debug_ranges.seg, debug_ranges.buf, seg, cgstate.funcoffset + sfunc.Ssize);

        /* ============= debug_loc =========================== */

        assert(cgstate.Para.size >= 2 * REGSIZE);
        assert(cgstate.Para.size < 63); // avoid sLEB128 encoding
        ushort op_size = 0x0002;
        ushort loc_op;

        // set the entry for this function in .debug_loc segment
        // after call
        dwarf_appreladdr(debug_loc.seg, debug_loc.buf, seg, cgstate.funcoffset + 0);
        dwarf_appreladdr(debug_loc.seg, debug_loc.buf, seg, cgstate.funcoffset + 1);

        loc_op = cast(ushort)(((cgstate.Para.size - REGSIZE) << 8) | (DW_OP_breg0 + dwarf_regno(SP)));
        debug_loc.buf.write32(loc_op << 16 | op_size);

        // after push EBP
        dwarf_appreladdr(debug_loc.seg, debug_loc.buf, seg, cgstate.funcoffset + 1);
        dwarf_appreladdr(debug_loc.seg, debug_loc.buf, seg, cgstate.funcoffset + 3);

        loc_op = cast(ushort)(((cgstate.Para.size) << 8) | (DW_OP_breg0 + dwarf_regno(SP)));
        debug_loc.buf.write32(loc_op << 16 | op_size);

        // after mov EBP, ESP
        dwarf_appreladdr(debug_loc.seg, debug_loc.buf, seg, cgstate.funcoffset + 3);
        dwarf_appreladdr(debug_loc.seg, debug_loc.buf, seg, cgstate.funcoffset + sfunc.Ssize);

        loc_op = cast(ushort)(((cgstate.Para.size) << 8) | (DW_OP_breg0 + dwarf_regno(BP)));
        debug_loc.buf.write32(loc_op << 16 | op_size);

        // 2 zero addresses to end loc_list
        append_addr(debug_loc.buf, 0);
        append_addr(debug_loc.buf, 0);
    }


    /******************************************
     * Write out symbol table for current function.
     */

    void dwarf_outsym(Symbol* s)
    {
        //printf("dwarf_outsym('%s')\n",s.Sident.ptr);
        //symbol_print(s);

        symbol_debug(s);

        if (s.Sflags & SFLnodebug)
            return;

        type* t = s.Stype;
        type_debug(t);
        tym_t tym = tybasic(t.Tty);
        if (tyfunc(tym) && s.Sclass != SC.typedef_)
            return;

        uint code;
        uint typidx;
        uint soffset;
        switch (s.Sclass)
        {
            case SC.global:
                typidx = dwarf_typidx(t);

                code = DWARFAbbrev.write!([
                    DW_TAG_variable, DW_CHILDREN_no,
                    DW_AT_name,      DW_FORM_string,
                    DW_AT_type,      DW_FORM_ref4,
                    DW_AT_external,  DW_FORM_flag,
                    DW_AT_location,  DW_FORM_block1,
                ]);

                debug_info.buf.writeuLEB128(code);        // abbreviation code
                debug_info.buf.writeStringz(getSymName(s));// DW_AT_name
                debug_info.buf.write32(typidx);           // DW_AT_type
                debug_info.buf.writeByte(1);              // DW_AT_external

                soffset = cast(uint)debug_info.buf.length();
                debug_info.buf.writeByte(2);                      // DW_FORM_block1

                if (config.objfmt == OBJ_ELF)
                {
                    // debug info for TLS variables
                    assert(s.Sxtrnnum);
                    if (s.Sfl == FL.tlsdata)
                    {
                        if (I64)
                        {
                            debug_info.buf.writeByte(DW_OP_const8u);
                            Obj.addrel(debug_info.seg, debug_info.buf.length(), R_X86_64_DTPOFF32, s.Sxtrnnum, 0);
                            debug_info.buf.write64(0);
                        }
                        else
                        {
                            debug_info.buf.writeByte(DW_OP_const4u);
                            Obj.addrel(debug_info.seg, debug_info.buf.length(), R_386_TLS_LDO_32, s.Sxtrnnum, 0);
                            debug_info.buf.write32(0);
                        }
                        debug_info.buf.writeByte(DW_OP_GNU_push_tls_address);
                    }
                    else
                    {
                        debug_info.buf.writeByte(DW_OP_addr);
                        dwarf_appreladdr(debug_info.seg, debug_info.buf, s.Sseg, s.Soffset); // address of global
                    }
                }
                else
                {
                    debug_info.buf.writeByte(DW_OP_addr);
                    dwarf_appreladdr(debug_info.seg, debug_info.buf, s.Sseg, s.Soffset); // address of global
                }

                debug_info.buf.buf[soffset] = cast(ubyte)(debug_info.buf.length() - soffset - 1);
                break;

            default:
                break;
        }
    }


    /******************************************
     * Write out any deferred symbols.
     */
    static if (0)
    void cv_outlist()
    {
    }


    /* =================== Cached Types in debug_info ================= */

    ubyte dwarf_classify_struct(uint sflags)
    {
        if (sflags & STRclass)
            return DW_TAG_class_type;

        if (sflags & STRunion)
            return DW_TAG_union_type;

        return DW_TAG_structure_type;
    }

    /* ======================= Type Index ============================== */

    uint dwarf_typidx(type* t)
    {
        uint idx = 0;
        uint nextidx;
        uint keyidx;
        uint pvoididx;
        uint code;
        type* tnext;
        type* tbase;
        const(char)* p;

        static immutable ubyte[8] abbrevTypeBasic =
        [
            DW_TAG_base_type, DW_CHILDREN_no,
            DW_AT_name,       DW_FORM_string,
            DW_AT_byte_size,  DW_FORM_data1,
            DW_AT_encoding,   DW_FORM_data1,
        ];
        static immutable ubyte[4] abbrevTypePointer =
        [
            DW_TAG_pointer_type, DW_CHILDREN_no,
            DW_AT_type,          DW_FORM_ref4,
        ];
        static immutable ubyte[2] abbrevTypePointerVoid =
        [
            DW_TAG_pointer_type, DW_CHILDREN_no,
        ];
        static immutable ubyte[4] abbrevTypeRef =
        [
            DW_TAG_reference_type, DW_CHILDREN_no,
            DW_AT_type,            DW_FORM_ref4,
        ];
        static immutable ubyte[4] abbrevTypeConst =
        [
            DW_TAG_const_type, DW_CHILDREN_no,
            DW_AT_type,        DW_FORM_ref4,
        ];
        static immutable ubyte[2] abbrevTypeConstVoid =
        [
            DW_TAG_const_type, DW_CHILDREN_no,
        ];
        static immutable ubyte[4] abbrevTypeVolatile =
        [
            DW_TAG_volatile_type, DW_CHILDREN_no,
            DW_AT_type,           DW_FORM_ref4,
        ];
        static immutable ubyte[2] abbrevTypeVolatileVoid =
        [
            DW_TAG_volatile_type, DW_CHILDREN_no,
        ];
        static immutable ubyte[4] abbrevTypeShared =
        [
            DW_TAG_shared_type, DW_CHILDREN_no,
            DW_AT_type,         DW_FORM_ref4,
        ];
        static immutable ubyte[2] abbrevTypeSharedVoid =
        [
            DW_TAG_shared_type, DW_CHILDREN_no,
        ];
        static immutable ubyte[4] abbrevTypeImmutable =
        [
            DW_TAG_immutable_type, DW_CHILDREN_no,
            DW_AT_type,            DW_FORM_ref4,
        ];
        static immutable ubyte[2] abbrevTypeImmutableVoid =
        [
            DW_TAG_immutable_type, DW_CHILDREN_no,
        ];

        if (!t)
            return 0;

        foreach(mty; [mTYconst, mTYshared, mTYvolatile, mTYimmutable])
        {
            if (t.Tty & mty)
            {
                // We make a copy of the type to strip off the const qualifier and
                // recurse, and then add the const abbrev code. To avoid ending in a
                // loop if the type references the const version of itself somehow,
                // we need to set TFforward here, because setting TFforward during
                // member generation of dwarf_typidx(tnext) has no effect on t itself.
                const ushort old_flags = t.Tflags;
                t.Tflags |= TFforward;

                tnext = type_copy(t);
                tnext.Tcount++;
                tnext.Tty &= ~mty;
                nextidx = dwarf_typidx(tnext);

                t.Tflags = old_flags;

                if (mty == mTYconst)
                {
                    code = nextidx
                        ? DWARFAbbrev.write!(abbrevTypeConst)
                        : DWARFAbbrev.write!(abbrevTypeConstVoid);
                }
                else if (mty == mTYvolatile)
                {
                    code = nextidx
                        ? DWARFAbbrev.write!(abbrevTypeVolatile)
                        : DWARFAbbrev.write!(abbrevTypeVolatileVoid);
                }
                else if (mty == mTYshared)
                {
                    code = nextidx
                        ? DWARFAbbrev.write!(abbrevTypeShared)
                        : DWARFAbbrev.write!(abbrevTypeSharedVoid);
                }
                else if (mty == mTYimmutable && config.dwarf >= 5)
                {
                    code = nextidx
                        ? DWARFAbbrev.write!(abbrevTypeImmutable)
                        : DWARFAbbrev.write!(abbrevTypeImmutableVoid);
                }
                else
                    continue;

                idx = cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);    // abbreviation code
                if (nextidx)
                    debug_info.buf.write32(nextidx);  // DW_AT_type
                goto Lret;
            }
        }

        immutable tym_t ty = tybasic(t.Tty);
        // use cached basic type if it's not TYdarray or TYdelegate
        if (!(t.Tnext && (ty == TYdarray || ty == TYdelegate)))
        {
            idx = typidx_tab[ty];
            if (idx)
                return idx;
        }

        ubyte ate;
        ate = tyuns(t.Tty) ? DW_ATE_unsigned : DW_ATE_signed;

        static immutable ubyte[6] abbrevTypeStruct =
        [
            DW_TAG_structure_type, DW_CHILDREN_yes,
            DW_AT_name,            DW_FORM_string,
            DW_AT_byte_size,       DW_FORM_data1,
        ];

        static immutable ubyte[8] abbrevTypeMember =
        [
            DW_TAG_member,              DW_CHILDREN_no,
            DW_AT_name,                 DW_FORM_string,
            DW_AT_type,                 DW_FORM_ref4,
            DW_AT_data_member_location, DW_FORM_block1,
        ];

        switch (ty)
        {
            Lnptr:
                nextidx = dwarf_typidx(t.Tnext);
                code = nextidx
                    ? DWARFAbbrev.write!(abbrevTypePointer)
                    : DWARFAbbrev.write!(abbrevTypePointerVoid);
                idx = cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);        // abbreviation code
                if (nextidx)
                    debug_info.buf.write32(nextidx);      // DW_AT_type
                break;

            case TYullong:
            case TYucent:
                if (!t.Tnext)
                    goto Lsignedstr;

                /* It's really TYdarray, and Tnext is the
                 * element type
                 */
                {
                    /*
                        https://issues.dlang.org/show_bug.cgi?id=22311
                        Must be unsigned long long, not ulong as the backend thinks ulong is from C.
                    */
                    uint lenidx = I64 ? dwarf_typidx(tstypes[TYullong]) : dwarf_typidx(tstypes[TYuint]);

                    {
                        type* tdata = type_alloc(TYnptr);
                        tdata.Tnext = t.Tnext;
                        t.Tnext.Tcount++;
                        tdata.Tcount++;
                        nextidx = dwarf_typidx(tdata);
                        type_free(tdata);
                    }

                    code = DWARFAbbrev.write!(abbrevTypeStruct);
                    idx = cast(uint)debug_info.buf.length();
                    debug_info.buf.writeuLEB128(code);        // abbreviation code

                    // FIXME: provide a better way to fetch length of a pretty
                    // name on the backend API which is dependent on the
                    // frontend C++ exported API
                    debug_info.buf.write(t.Tident, strlen(t.Tident));       // DW_AT_name
                    debug_info.buf.writeByte(0);
                    debug_info.buf.writeByte(tysize(t.Tty)); // DW_AT_byte_size

                    // length
                    code = DWARFAbbrev.write!(abbrevTypeMember);
                    debug_info.buf.writeuLEB128(code);        // abbreviation code
                    debug_info.buf.writeStringz("length");     // DW_AT_name
                    debug_info.buf.write32(lenidx);           // DW_AT_type

                    debug_info.buf.writeByte(2);              // DW_AT_data_member_location
                    debug_info.buf.writeByte(DW_OP_plus_uconst);
                    debug_info.buf.writeByte(0);

                    // ptr
                    debug_info.buf.writeuLEB128(code);        // abbreviation code
                    debug_info.buf.writeStringz("ptr");        // DW_AT_name
                    debug_info.buf.write32(nextidx);          // DW_AT_type

                    debug_info.buf.writeByte(2);              // DW_AT_data_member_location
                    debug_info.buf.writeByte(DW_OP_plus_uconst);
                    debug_info.buf.writeByte(I64 ? 8 : 4);

                    debug_info.buf.writeByte(0);              // no more children
                }
                break;

            case TYllong:
            case TYcent:
                if (!t.Tnext)
                    goto Lsignedstr;

                /* It's really TYdelegate, and Tnext is the
                 * function type
                 */
                {
                    type* tp = type_fake(TYnptr);
                    tp.Tcount++;
                    pvoididx = dwarf_typidx(tp);    // void*

                    tp.Tnext = t.Tnext;           // fptr*
                    tp.Tnext.Tcount++;
                    nextidx = dwarf_typidx(tp);
                    type_free(tp);
                }

                code = DWARFAbbrev.write!(abbrevTypeStruct);
                idx = cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);       // abbreviation code
                debug_info.buf.writeStringz(t.Tident);    // DW_AT_name
                debug_info.buf.writeByte(tysize(t.Tty)); // DW_AT_byte_size

                // ptr
                code = DWARFAbbrev.write!(abbrevTypeMember);
                debug_info.buf.writeuLEB128(code);        // abbreviation code
                debug_info.buf.writeStringz("ptr");        // DW_AT_name
                debug_info.buf.write32(pvoididx);         // DW_AT_type

                debug_info.buf.writeByte(2);              // DW_AT_data_member_location
                debug_info.buf.writeByte(DW_OP_plus_uconst);
                debug_info.buf.writeByte(0);

                // funcptr
                debug_info.buf.writeuLEB128(code);        // abbreviation code
                debug_info.buf.writeStringz("funcptr");    // DW_AT_name
                debug_info.buf.write32(nextidx);          // DW_AT_type

                debug_info.buf.writeByte(2);              // DW_AT_data_member_location
                debug_info.buf.writeByte(DW_OP_plus_uconst);
                debug_info.buf.writeByte(I64 ? 8 : 4);

                debug_info.buf.writeByte(0);              // no more children
                break;

            case TYnref:
            case TYref:
                nextidx = dwarf_typidx(t.Tnext);
                assert(nextidx);
                code = DWARFAbbrev.write!(abbrevTypeRef);
                idx = cast(uint)cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);        // abbreviation code
                debug_info.buf.write32(nextidx);          // DW_AT_type
                break;

            case TYnptr:
                if (!t.Tkey)
                    goto Lnptr;

                /* It's really TYaarray, and Tnext is the
                 * element type, Tkey is the key type
                 */
                {
                    type* tp = type_fake(TYnptr);
                    tp.Tcount++;
                    pvoididx = dwarf_typidx(tp);    // void*
                }

                code = DWARFAbbrev.write!(abbrevTypeStruct);
                idx = cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);        // abbreviation code
                debug_info.buf.writeStringz(t.Tident);      // DW_AT_name
                debug_info.buf.writeByte(tysize(t.Tty)); // DW_AT_byte_size

                // ptr
                code = DWARFAbbrev.write!(abbrevTypeMember);
                debug_info.buf.writeuLEB128(code);        // abbreviation code
                debug_info.buf.writeStringz("ptr");        // DW_AT_name
                debug_info.buf.write32(pvoididx);         // DW_AT_type

                debug_info.buf.writeByte(2);              // DW_AT_data_member_location
                debug_info.buf.writeByte(DW_OP_plus_uconst);
                debug_info.buf.writeByte(0);

                debug_info.buf.writeByte(0);              // no more children
                break;

            case TYvoid:        return 0;
            case TYbool:
                ate = DW_ATE_boolean;
                goto Lsignedstr;
            case TYchar:
                ate = (config.flags & CFGuchar)
                    ? DW_ATE_unsigned_char
                    : DW_ATE_signed_char;
                goto Lsignedstr;
            case TYschar:
                ate = DW_ATE_signed_char;
                goto Lsignedstr;
            case TYuchar:
                ate = DW_ATE_unsigned_char;
                goto Lsignedstr;
            case TYdchar:
                ate = DW_ATE_UTF;
                goto Lsignedstr;
            case TYshort:
            case TYushort:
            case TYint:
            case TYuint:
            case TYlong:
            case TYulong:
                goto Lsignedstr;
            case TYdouble_alias:
                p = tystring[TYdouble];
                ate = DW_ATE_float;
                goto Lsigned;
            case TYfloat:
            case TYdouble:
                ate = DW_ATE_float;
                goto Lsignedstr;
            case TYldouble:
            case TYifloat:
            case TYidouble:
            case TYildouble:
                ate = DW_ATE_imaginary_float;
                goto Lsignedstr;
            case TYcfloat:
            case TYcdouble:
            case TYcldouble:
                ate = DW_ATE_complex_float;
                goto Lsignedstr;
            Lsignedstr:
                p = tystring[ty];
            Lsigned:
                code = DWARFAbbrev.write!(abbrevTypeBasic);
                idx = cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);        // abbreviation code
                debug_info.buf.writeStringz(p);            // DW_AT_name
                debug_info.buf.writeByte(tysize(t.Tty)); // DW_AT_byte_size
                debug_info.buf.writeByte(ate);            // DW_AT_encoding
                typidx_tab[ty] = idx;
                return idx;

            case TYnsfunc:
            case TYnpfunc:
            case TYjfunc:

            case TYnfunc:
            {
                /* The dwarf typidx for the function type is completely determined by
                 * the return type typidx and the parameter typidx's. Thus, by
                 * caching these, we can cache the function typidx.
                 * Cache them in functypebuf[]
                 */
                OutBuffer tmpbuf;
                nextidx = dwarf_typidx(t.Tnext);                   // function return type
                tmpbuf.write32(nextidx);
                uint params = 0;
                for (param_t* p2 = t.Tparamtypes; p2; p2 = p2.Pnext)
                {
                    params = 1;
                    uint paramidx = dwarf_typidx(p2.Ptype);
                    //printf("1: paramidx = %d\n", paramidx);

                    debug
                        if (!paramidx)
                            type_print(p2.Ptype);

                    assert(paramidx);
                    tmpbuf.write32(paramidx);
                }

                if (!functypebuf)
                {
                    functypebuf = cast(OutBuffer*) calloc(1, OutBuffer.sizeof);
                    if (!functypebuf)
                        err_nomem();
                }
                uint functypebufidx = cast(uint)functypebuf.length();
                functypebuf.write(tmpbuf.buf, cast(uint)tmpbuf.length());
                /* If it's in the cache already, return the existing typidx
                 */
                if (!functype_table)
                    functype_table = AApair.create(functypebuf.bufptr);
                uint* pidx = cast(uint*)functype_table.get(Pair(functypebufidx, cast(uint)functypebuf.length()));
                if (*pidx)
                {
                    // Reuse existing typidx
                    functypebuf.setsize(functypebufidx);
                    return* pidx;
                }

                /* Not in the cache, create a new typidx
                 */
                OutBuffer abuf;             // for abbrev
                abuf.writeByte(DW_TAG_subroutine_type);
                abuf.writeByte(params ? DW_CHILDREN_yes : DW_CHILDREN_no);
                abuf.writeByte(DW_AT_prototyped);
                abuf.writeByte(DW_FORM_flag);
                if (nextidx != 0)           // Don't write DW_AT_type for void
                {
                    abuf.writeByte(DW_AT_type);
                    abuf.writeByte(DW_FORM_ref4);
                }

                abuf.writeByte(0);
                abuf.writeByte(0);
                code = dwarf_abbrev_code(abuf.buf, abuf.length());

                idx = cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);
                debug_info.buf.writeByte(1);            // DW_AT_prototyped
                if (nextidx)                            // if return type is not void
                    debug_info.buf.write32(nextidx);    // DW_AT_type

                if (params)
                {
                    uint paramcode = DWARFAbbrev.write!([
                            DW_TAG_formal_parameter, DW_CHILDREN_no,
                            DW_AT_type,              DW_FORM_ref4
                    ]);

                    uint* pparamidx = cast(uint*)(functypebuf.buf + functypebufidx);
                    //printf("2: functypebufidx = %x, pparamidx = %p, size = %x\n", functypebufidx, pparamidx, functypebuf.length());
                    for (param_t* p2 = t.Tparamtypes; p2; p2 = p2.Pnext)
                    {
                        debug_info.buf.writeuLEB128(paramcode);
                        //uint x = dwarf_typidx(p2.Ptype);
                        uint paramidx = *++pparamidx;
                        //printf("paramidx = %d\n", paramidx);
                        assert(paramidx);
                        debug_info.buf.write32(paramidx);        // DW_AT_type
                    }
                    debug_info.buf.writeByte(0);          // end parameter list
                }

                *pidx = idx;                        // remember it in the functype_table[] cache
                break;
            }

            case TYarray:
            {
                static immutable ubyte[4] abbrevTypeArray =
                [
                    DW_TAG_array_type, DW_CHILDREN_yes, // child (the subrange type)
                    DW_AT_type,        DW_FORM_ref4,
                ];
                static immutable ubyte[2] abbrevTypeArrayVoid =
                [
                    DW_TAG_array_type, DW_CHILDREN_yes, // child (the subrange type)
                ];
                static immutable ubyte[6] abbrevTypeSubrange =
                [
                    DW_TAG_subrange_type, DW_CHILDREN_no,
                    DW_AT_type,           DW_FORM_ref4,
                    DW_AT_upper_bound,    DW_FORM_data4,
                ];
                static immutable ubyte[4] abbrevTypeSubrange2 =
                [
                    DW_TAG_subrange_type, DW_CHILDREN_no,
                    DW_AT_type,           DW_FORM_ref4,
                ];
                uint code2 = (t.Tflags & TFsizeunknown)
                    ? DWARFAbbrev.write!(abbrevTypeSubrange2)
                    : DWARFAbbrev.write!(abbrevTypeSubrange);
                uint idxbase = dwarf_typidx(tssize);
                nextidx = dwarf_typidx(t.Tnext);
                uint code1 = nextidx ? DWARFAbbrev.write!(abbrevTypeArray)
                                     : DWARFAbbrev.write!(abbrevTypeArrayVoid);
                idx = cast(uint)debug_info.buf.length();

                debug_info.buf.writeuLEB128(code1);       // DW_TAG_array_type
                if (nextidx)
                    debug_info.buf.write32(nextidx);      // DW_AT_type

                debug_info.buf.writeuLEB128(code2);       // DW_TAG_subrange_type
                debug_info.buf.write32(idxbase);          // DW_AT_type
                if (!(t.Tflags & TFsizeunknown))
                    debug_info.buf.write32(t.Tdim ? cast(uint)t.Tdim - 1 : 0);    // DW_AT_upper_bound

                debug_info.buf.writeByte(0);              // no more children
                break;
            }

            // SIMD vector types
            case TYfloat16:
            case TYfloat8:
            case TYfloat4:   tbase = tstypes[TYfloat];  goto Lvector;
            case TYdouble8:
            case TYdouble4:
            case TYdouble2:  tbase = tstypes[TYdouble]; goto Lvector;
            case TYschar64:
            case TYschar32:
            case TYschar16:  tbase = tstypes[TYschar];  goto Lvector;
            case TYuchar64:
            case TYuchar32:
            case TYuchar16:  tbase = tstypes[TYuchar];  goto Lvector;
            case TYshort32:
            case TYshort16:
            case TYshort8:   tbase = tstypes[TYshort];  goto Lvector;
            case TYushort32:
            case TYushort16:
            case TYushort8:  tbase = tstypes[TYushort]; goto Lvector;
            case TYlong16:
            case TYlong8:
            case TYlong4:    tbase = tstypes[TYlong];   goto Lvector;
            case TYulong16:
            case TYulong8:
            case TYulong4:   tbase = tstypes[TYulong];  goto Lvector;
            case TYllong8:
            case TYllong4:
            case TYllong2:   tbase = tstypes[TYllong];  goto Lvector;
            case TYullong8:
            case TYullong4:
            case TYullong2:  tbase = tstypes[TYullong]; goto Lvector;
            Lvector:
            {
                uint code2 = DWARFAbbrev.write!([
                    DW_TAG_array_type, DW_CHILDREN_yes, // child (the subrange type)
                    DW_AT_GNU_vector,  DW_FORM_flag,
                    DW_AT_type,        DW_FORM_ref4,
                ]);
                uint idxbase = dwarf_typidx(tbase);

                idx = cast(uint)debug_info.buf.length();

                debug_info.buf.writeuLEB128(code2);       // DW_TAG_array_type
                debug_info.buf.writeByte(1);              // DW_AT_GNU_vector
                debug_info.buf.write32(idxbase);          // DW_AT_type

                // vector length stored as subrange type
                code2 = DWARFAbbrev.write!([
                    DW_TAG_subrange_type, DW_CHILDREN_no,
                    DW_AT_upper_bound,    DW_FORM_data1, // length of vector
                ]);
                debug_info.buf.writeuLEB128(code2);       // DW_TAG_subrange_type
                ubyte dim = cast(ubyte)(tysize(t.Tty) / tysize(tbase.Tty));
                debug_info.buf.writeByte(dim - 1);        // DW_AT_upper_bound

                debug_info.buf.writeByte(0);              // no more children
                break;
            }

            case TYwchar_t:
            {
                uint code3 = DWARFAbbrev.write!(abbrevTypeBasic);
                idx = cast(uint)debug_info.buf.length();

                debug_info.buf.writeuLEB128(code3);       // abbreviation code
                debug_info.buf.writeStringz(tystring[ty]); // DW_AT_name
                debug_info.buf.writeByte(tysize(TYint));  // DW_AT_byte_size
                debug_info.buf.writeByte(DW_ATE_signed);  // DW_AT_encoding
                break;
            }


            case TYstruct:
            {
                Classsym* s = t.Ttag;
                struct_t* st = s.Sstruct;

                if (s.Stypidx)
                    return s.Stypidx;

                __gshared ubyte[8] abbrevTypeStruct0 =
                [
                    DW_TAG_structure_type,  DW_CHILDREN_no,
                    DW_AT_name,             DW_FORM_string,
                    DW_AT_byte_size,        DW_FORM_data1,
                    0,                      0,
                ];
                __gshared ubyte[8] abbrevTypeStruct1 =
                [
                    DW_TAG_structure_type,  DW_CHILDREN_no,
                    DW_AT_name,             DW_FORM_string,
                    DW_AT_declaration,      DW_FORM_flag,
                    0,                      0,
                ];

                if (t.Tflags & (TFsizeunknown | TFforward))
                {
                    abbrevTypeStruct1[0] = dwarf_classify_struct(st.Sflags);
                    code = dwarf_abbrev_code(abbrevTypeStruct1.ptr, (abbrevTypeStruct1).sizeof);
                    idx = cast(uint)debug_info.buf.length();
                    debug_info.buf.writeuLEB128(code);
                    debug_info.buf.writeStringz(getSymName(s));    // DW_AT_name
                    debug_info.buf.writeByte(1);                  // DW_AT_declaration
                    break;                  // don't set Stypidx
                }

                OutBuffer fieldidx;

                // Count number of fields
                uint nfields = 0;
                t.Tflags |= TFforward;
                foreach (sl; ListRange(st.Sfldlst))
                {
                    Symbol* sf = list_symbol(sl);
                    switch (sf.Sclass)
                    {
                        case SC.member:
                            fieldidx.write32(dwarf_typidx(sf.Stype));
                            nfields++;
                            break;

                        default:
                            break;
                    }
                }

                OutBuffer baseclassidx;
                for (auto bc = st.Sbase; bc; bc = bc.BCnext)
                    baseclassidx.write32(dwarf_typidx(bc.BCbase.Stype));

                t.Tflags &= ~TFforward;
                if (nfields == 0 && !st.Sbase)
                {
                    abbrevTypeStruct0[0] = dwarf_classify_struct(st.Sflags);
                    abbrevTypeStruct0[1] = DW_CHILDREN_no;
                    abbrevTypeStruct0[5] = DW_FORM_data1;   // DW_AT_byte_size
                    code = dwarf_abbrev_code(abbrevTypeStruct0.ptr, (abbrevTypeStruct0).sizeof);
                    idx = cast(uint)debug_info.buf.length();
                    debug_info.buf.writeuLEB128(code);
                    debug_info.buf.writeStringz(getSymName(s));    // DW_AT_name
                    debug_info.buf.writeByte(0);                  // DW_AT_byte_size
                }
                else
                {
                    OutBuffer abuf;         // for abbrev
                    abuf.writeByte(dwarf_classify_struct(st.Sflags));
                    abuf.writeByte(DW_CHILDREN_yes);
                    abuf.writeByte(DW_AT_name);     abuf.writeByte(DW_FORM_string);
                    abuf.writeByte(DW_AT_byte_size);

                    size_t sz = cast(uint)st.Sstructsize;
                    if (sz <= 0xFF)
                        abuf.writeByte(DW_FORM_data1);      // DW_AT_byte_size
                    else if (sz <= 0xFFFF)
                        abuf.writeByte(DW_FORM_data2);      // DW_AT_byte_size
                    else
                        abuf.writeByte(DW_FORM_data4);      // DW_AT_byte_size
                    abuf.writeByte(0);              abuf.writeByte(0);

                    code = dwarf_abbrev_code(abuf.buf, abuf.length());

                    uint membercode = DWARFAbbrev.write!([
                        DW_TAG_member,              DW_CHILDREN_no,
                        DW_AT_name,                 DW_FORM_string,
                        DW_AT_type,                 DW_FORM_ref4,
                        DW_AT_data_member_location, DW_FORM_block1
                    ]);

                    uint baseclasscode;
                    if (st.Sbase)
                        baseclasscode = DWARFAbbrev.write!([
                            DW_TAG_inheritance,         DW_CHILDREN_no,
                            DW_AT_type,                 DW_FORM_ref4,
                            DW_AT_data_member_location, DW_FORM_block1
                        ]);

                    idx = cast(uint)debug_info.buf.length();
                    debug_info.buf.writeuLEB128(code);
                    debug_info.buf.writeStringz(getSymName(s));      // DW_AT_name
                    if (sz <= 0xFF)
                        debug_info.buf.writeByte(cast(uint)sz);     // DW_AT_byte_size
                    else if (sz <= 0xFFFF)
                        debug_info.buf.write16(cast(uint)sz);     // DW_AT_byte_size
                    else
                        debug_info.buf.write32(cast(uint)sz);       // DW_AT_byte_size

                    uint n = 0;
                    for (auto bc = st.Sbase; bc; bc = bc.BCnext, n++)
                    {
                        debug_info.buf.writeuLEB128(baseclasscode);
                        uint bci = (cast(uint*)baseclassidx.buf)[n];
                        debug_info.buf.write32(bci);
                        const soffset = debug_info.buf.length();
                        debug_info.buf.writeByte(2);
                        debug_info.buf.writeByte(DW_OP_plus_uconst);
                        debug_info.buf.writeuLEB128(cast(uint)bc.BCoffset);
                        debug_info.buf.buf[soffset] = cast(ubyte)(debug_info.buf.length() - soffset - 1);
                    }

                    s.Stypidx = idx;
                    n = 0;
                    foreach (sl; ListRange(st.Sfldlst))
                    {
                        Symbol* sf = list_symbol(sl);
                        size_t soffset;

                        switch (sf.Sclass)
                        {
                            case SC.member:
                                debug_info.buf.writeuLEB128(membercode);
                                debug_info.buf.writeStringz(getSymName(sf));      // DW_AT_name
                                //debug_info.buf.write32(dwarf_typidx(sf.Stype));
                                uint fi = (cast(uint*)fieldidx.buf)[n];
                                debug_info.buf.write32(fi);
                                n++;
                                soffset = debug_info.buf.length();
                                debug_info.buf.writeByte(2);
                                debug_info.buf.writeByte(DW_OP_plus_uconst);
                                debug_info.buf.writeuLEB128(cast(uint)sf.Smemoff);
                                debug_info.buf.buf[soffset] = cast(ubyte)(debug_info.buf.length() - soffset - 1);
                                break;

                            default:
                                break;
                        }
                    }

                    debug_info.buf.writeByte(0);          // no more children
                }
                s.Stypidx = idx;
                resetSyms.push(s);
                return idx;                 // no need to cache it
            }

            case TYenum:
            {
                Symbol* s = t.Ttag;
                enum_t* se = s.Senum;
                type* tbase2 = s.Stype.Tnext;
                uint sz = cast(uint)type_size(tbase2);
                symlist_t sl;

                if (s.Stypidx)
                    return s.Stypidx;

                if (se.SEflags & SENforward)
                {
                    code = DWARFAbbrev.write!([
                        DW_TAG_enumeration_type, DW_CHILDREN_no,
                        DW_AT_name,              DW_FORM_string,
                        DW_AT_declaration,       DW_FORM_flag,
                    ]);
                    idx = cast(uint)debug_info.buf.length();
                    debug_info.buf.writeuLEB128(code);
                    debug_info.buf.writeStringz(getSymName(s));    // DW_AT_name
                    debug_info.buf.writeByte(1);                  // DW_AT_declaration
                    break;                  // don't set Stypidx
                }

                code = DWARFAbbrev.write!([
                    DW_TAG_enumeration_type, DW_CHILDREN_yes, // child (the subrange type)
                    DW_AT_name,              DW_FORM_string,
                    DW_AT_byte_size,         DW_FORM_data1,
                ]);

                uint membercode;
                OutBuffer abuf;
                abuf.writeByte(DW_TAG_enumerator);
                abuf.writeByte(DW_CHILDREN_no);
                abuf.writeByte(DW_AT_name);
                abuf.writeByte(DW_FORM_string);
                abuf.writeByte(DW_AT_const_value);
                if (tyuns(tbase2.Tty))
                    abuf.writeByte(DW_FORM_udata);
                else
                    abuf.writeByte(DW_FORM_sdata);
                abuf.writeByte(0);
                abuf.writeByte(0);
                membercode = dwarf_abbrev_code(abuf.buf, abuf.length());

                idx = cast(uint)debug_info.buf.length();
                debug_info.buf.writeuLEB128(code);
                debug_info.buf.writeStringz(getSymName(s));// DW_AT_name
                debug_info.buf.writeByte(sz);             // DW_AT_byte_size

                foreach (sl2; ListRange(s.Senum.SEenumlist))
                {
                    Symbol* sf = cast(Symbol*)list_ptr(sl2);
                    const value = cast(uint)el_tolong(sf.Svalue);

                    debug_info.buf.writeuLEB128(membercode);
                    debug_info.buf.writeStringz(getSymName(sf)); // DW_AT_name
                    if (tyuns(tbase2.Tty))
                        debug_info.buf.writeuLEB128(value);
                    else
                        debug_info.buf.writesLEB128(value);
                }

                debug_info.buf.writeByte(0);              // no more children

                s.Stypidx = idx;
                resetSyms.push(s);
                return idx;                 // no need to cache it
            }

            default:
                return 0;
        }
    Lret:
        /* If debug_info.buf.buf[idx .. length()] is already in debug_info.buf,
         * discard this one and use the previous one.
         */
        if (!type_table)
            /* uint[Adata] type_table;
             * where the table values are the type indices
             */
            type_table = AApair.create(debug_info.buf.bufptr);

        uint* pidx = type_table.get(Pair(idx, cast(uint)debug_info.buf.length()));
        if (!*pidx)                 // if no idx assigned yet
        {
            *pidx = idx;            // assign newly computed idx
        }
        else
        {   // Reuse existing code
            debug_info.buf.setsize(idx);  // discard current
            idx = *pidx;
        }
        return idx;
    }

    /**
     *  Returns a pretty identifier name from `sym`.
     *
     *  Params:
     *      sym = the symbol which the name comes from
     *  Returns:
     *      The identifier name
     */
    const(char)* getSymName(Symbol* sym)
    {
        return sym.prettyIdent ? sym.prettyIdent : sym.Sident.ptr;
    }

    /* ======================= Abbreviation Codes ====================== */

    extern(D) private struct DWARFAbbrev
    {
        nothrow:

        void append(const uint idx, const uint form) pure
        {
            abuf.writeuLEB128(idx);
            abuf.writeuLEB128(form);
        }

        void append(const(uint)[] A)() pure
        {
            static immutable abbrev = toLEB128!A;
            abuf.write(abbrev.ptr, abbrev.length);
        }

        uint awrite(const uint idx, const uint form)
        {
            append(idx, form);
            return write();
        }

        uint awrite(const(uint)[] A)()
        {
            append!A;
            return write();
        }

        uint write()
        {
            append(0, 0);
            uint ret = dwarf_abbrev_code(abuf.buf, abuf.length());
            abuf.reset();

            return ret;
        }

        static uint write(const(uint)[] A)()
        {
            static immutable abbrev = toLEB128!(A ~ [0u, 0u]);
            return dwarf_abbrev_code(abbrev.ptr, abbrev.length);
        }

        private static auto toLEB128(const(uint)[] abbrev)() pure @safe
        {
            size_t getLEB128Length(const(uint)[] arr)
            {
                size_t len;
                foreach(uint e; arr)
                    do ++len;
                    while (e >>= 7);
                return len;
            }
            ubyte[getLEB128Length(abbrev)] ret;
            size_t offset;

            foreach(uint e; abbrev)
                do
                {
                    ubyte b = e & 0x7F;

                    e >>= 7;
                    if (e)
                        b |= 0x80;
                    ret[offset] = b;
                    ++offset;
                } while (e);

            return ret;
        }

        unittest
        {
            assert(toLEB128!([0x00, 0x40, 0x81]) == [0x00, 0x40, 0x81, 0x01]);
            assert(toLEB128!([0x00, 0x40, 0xFFFF]) == [0x00, 0x40, 0xFF, 0xFF, 0x03]);
            assert(toLEB128!([0x00, 0x40, 0x79]) == [0x00, 0x40, 0x79]);
        }

        private:
        OutBuffer abuf;
    }

    uint dwarf_abbrev_code(const(ubyte)* data, size_t nbytes)
    {
        if (!abbrev_table)
            /* uint[Adata] abbrev_table;
             * where the table values are the abbreviation codes.
             */
            abbrev_table = AApair.create(debug_abbrev.buf.bufptr);

        // Write new entry into debug_abbrev.buf
        uint idx = cast(uint)debug_abbrev.buf.length();
        ++abbrevcode;
        debug_abbrev.buf.writeuLEB128(abbrevcode);
        size_t start = debug_abbrev.buf.length();
        debug_abbrev.buf.write(data, cast(uint)nbytes);
        size_t end = debug_abbrev.buf.length();

        /* If debug_abbrev.buf.buf[idx .. length()] is already in debug_abbrev.buf,
         * discard this one and use the previous one.
         */

        uint* pcode = abbrev_table.get(Pair(cast(uint) start, cast(uint) end));
        if (!*pcode)
        {
            // if no code assigned yet, assign newly computed code
            *pcode = abbrevcode;
        }
        else
        {
            // Reuse existing code and discard newly added abbreviation
            debug_abbrev.buf.setsize(idx);
            --abbrevcode;
        }
        return* pcode;
    }

    /*****************************************************
     * Write Dwarf-style exception tables.
     * Params:
     *      sfunc = function to generate tables for
     *      startoffset = size of function prolog
     *      retoffset = offset from start of function to epilog
     */
    void dwarf_except_gentables(Funcsym* sfunc, uint startoffset, uint retoffset)
    {
        if (!doUnwindEhFrame())
            return;

        int seg = dwarf_except_table_alloc(sfunc);
        OutBuffer* buf = SegData[seg].SDbuf;
        buf.reserve(100);

        if (config.objfmt == OBJ_ELF)
            sfunc.Sfunc.LSDAoffset = cast(uint)buf.length();

        if (config.objfmt == OBJ_MACH)
        {
            char[16 + (except_table_num).sizeof * 3 + 1] name = void;
            const length = snprintf(name.ptr, name.length, "GCC_except_table%d", ++except_table_num);
            type* t = tspvoid;
            t.Tcount++;
            type_setmangle(&t, Mangle.syscall);         // no leading '_' for mangled name
            Symbol* s = symbol_name(name[0 .. length], SC.static_, t);
            Obj.pubdef(seg, s, cast(uint)buf.length());
            symbol_keep(s);

            sfunc.Sfunc.LSDAsym = s;
        }
        import dmd.backend.dwarfeh : dwehtable;
        genDwarfEh(sfunc, seg, buf, (cgstate.usednteh & EHcleanup) != 0, startoffset, retoffset, dwehtable);
    }

}
else
{

    void dwarf_CFA_set_loc(uint location) { }
    void dwarf_CFA_set_reg_offset(int reg, int offset) { }
    void dwarf_CFA_offset(int reg, int offset) { }
    void dwarf_except_gentables(Funcsym* sfunc, uint startoffset, uint retoffset) { }
}

version (Windows)
{
    private enum DIRCHAR = '\\';

    private bool ispathdelim(char c) nothrow { return c == DIRCHAR || c == ':' || c == '/'; }
}
else
{
    private enum DIRCHAR = '/';

    private bool ispathdelim(char c) nothrow { return c == DIRCHAR; }
}

/**********************
 * Returns: string that is the filename plus dot and extension.
 * The string returned is NOT mem_malloc'ed.
 */
@trusted
private char* filespecname(const(char)* filespec) nothrow
{
    const(char)* p;

    /* Start at end of string and back up till we find the beginning
     * of the filename or a path
     */
    for (p = filespec + strlen(filespec);
         p != filespec && !ispathdelim(*(p - 1));
         p--
        )
    { }
    return cast(char*)p;
}
