/*********************************************************
 * ARM64 disassembler.
 * For unit tests: dmd disasmarm.d -unittest -main
 *
 * Copyright:   Copyright (C) 1982-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Reference:   Arm A64 Instruction Set for A-profile Architecture ISA_A64_xml_A_profile-2024-03.pdf
 *              A64 instruction set https://www.scs.stanford.edu/~zyedidia/arm64/
 */

module dmd.backend.arm.disasmarm;

nothrow @nogc:

/*****************************
 * Calculate and return the number of bytes in an instruction starting at code[c].
 * Params:
 *      code = machine code as array of bytes
 *      c = address of instruction (as index into code[])
 *      pc = set to address of instruction after prefix
 *      model = memory model, 16/32/64
 */

public
addr calccodsize(ubyte[] code, addr c, out addr pc, uint model)
{
    assert(model == 64);
    Disasm disasm = Disasm(code, model);
    return disasm.calccodsize(c, pc);
}

/************************
 * If instruction is a jump or a call, get information about
 * where the offset is and what it is.
 * Params:
 *      code = instruction bytes
 *      c = address of start of instruction, not including prefix.
 *          Use calccodsize() to determine start not including prefix.
 *          Updated to be address of the offset part of the instruction.
 *          Caller determines if it is relative to the start of the next
 *          instruction or not.
 *      offset = set to be address of jump target
 * Returns:
 *      true if jump or call target
 */
@trusted
public
bool jmpTarget(ubyte[] code, ref addr c, out addr offset)
{
static if (0)
{
    const op = code[c] & 0xFF;
    if (inssize[op] & B) // byte jump
    {
        ++c;
        offset = cast(byte) code[c];
    }
    else if (inssize[op] & W) // word jump
    {
        ++c;
        offset = cast(short)((code[c] & 0xFF) + (code[c + 1] << 8));
    }
    else if (op == 0x0F && inssize2[code[c + 1]] & W) // word/dword jump
    {
        c += 2;
        /* BUG: look only at 16 bits of offset */
        offset = cast(short)((code[c] & 0xFF) + (code[c + 1] << 8));
    }
    else
        return false;
}
    return true;
}

/*************************
 * Write to put() the disassembled instruction
 * Params:
 *      put = function to write the output string to
 *      code = instruction bytes
 *      c = address (index into code[]) of start of instruction to disassemble
 *      siz = number of bytes in instruction (from calccodsize())
 *      model = memory model, 16/32/64
 *      nearptr = use 'near ptr' when writing memory references
 *      bObjectcode = also prepend hex characters of object code
 *      mem = if not null, then function that returns a string
 *          representing the label for the memory address. Parameters are `c`
 *          for the address of the memory reference in `code[]`, `sz` for the
 *          number of bytes in the referred to memory location, and `offset`
 *          for the value to be added to any symbol referenced.
 *      immed16 = if not null, then function that returns a string
 *          representation of immediate value.
 *          Parameters are `code` is the binary instructions,
 *          `c` is the address of the memory reference in `code[]`,
 *          `sz` is the number of bytes in the instruction that form the referenece (2/4/8)
 *      labelcode = if not null, then function that returns a string
 *          representation of code label.
 *          Parameters are
 *          `c` is the address of the code reference to the label in `code[]`,
 *          `offset` is the address of the label in `code[]`,
 *          `farflag` is if `far` reference (seg:offset in 16 bit code),
 *          `is16bit` is if 16 bit reference
 *      shortlabel = if not null, then function that returns a string
 *          representing the label for the target. Parameters are `pc`
 *          for the program counter value, and `offset` for the offset
 *          of the label from the pc.
 */
@trusted
public
void getopstring(void delegate(char) nothrow @nogc put, ubyte[] code, uint c, addr siz,
        uint model, int nearptr, ubyte bObjectcode,
        const(char)*function(uint c, uint sz, uint offset) nothrow @nogc mem,
        const(char)*function(ubyte[] code, uint c, int sz) nothrow @nogc immed16,
        const(char)*function(uint c, uint offset, bool farflag, bool is16bit) nothrow @nogc labelcode,
        const(char)*function(uint pc, int offset) nothrow @nogc shortlabel
        )
{
    assert(model == 64);
    auto disasm = Disasm(put, code, siz,
                model, nearptr, bObjectcode,
                mem, immed16, labelcode, shortlabel);
    disasm.disassemble(c);
}

/************************************************************************************/
private:


import core.stdc.stdio;
import core.stdc.string;

alias addr = uint;
alias addr64 = ulong;

enum BUFMAX = 2000;

/***********************************************
 * The disassembler
 */

struct Disasm
{
  nothrow @nogc:

    @trusted
    this(void delegate(char) nothrow @nogc put, ubyte[] code, addr siz,
        uint model, int nearptr, ubyte bObjectcode,
        const(char)*function(uint c, uint sz, uint offset) nothrow @nogc mem,
        const(char)*function(ubyte[] code, uint c, int sz) nothrow @nogc immed16,
        const(char)*function(uint c, uint offset, bool farflag, bool is16bit) nothrow @nogc labelcode,
        const(char)*function(uint pc, int offset) nothrow @nogc shortlabel
        )
    {
        this.put = put;
        this.code = code;
        this.siz = siz;
        this.model = model;
        this.nearptr = nearptr;
        this.bObjectcode = bObjectcode;

        /* Set null function pointers to default functions
         */
        this.mem        = mem        ? mem        : &memoryDefault;
        this.immed16    = immed16    ? immed16    : &immed16Default;
        this.labelcode  = labelcode  ? labelcode  : &labelcodeDefault;
        this.shortlabel = shortlabel ? shortlabel : &shortlabelDefault;

        defopsize = model == 16;
        defadsize = model == 32 || model == 64;

        // Reset globals
        opsize = defopsize;
        adsize = defadsize;
        fwait = 0;
        segover = "".ptr;
    }

    /* Enough to get prefixbyte() working
     */
    this(ubyte[] code, uint model)
    {
        this.code = code;
        this.model = model;
        defopsize = model == 16;
        defadsize = model == 32 || model == 64;
        opsize = defopsize;
        adsize = defadsize;
        fwait = 0;
        segover = "".ptr;
    }

    ubyte[] code;               // the code segment contents
    void delegate(char) put;
    addr siz;
    int nearptr;
    ubyte bObjectcode;
    bool defopsize;             // default value for opsize
    char defadsize;             // default value for adsize
    bool opsize;                // if 0, then 32 bit operand
    char adsize;                // if !=0, then 32 or 64 bit address
    char fwait;                 // if !=0, then saw an FWAIT
    uint model;                 // 16/32/64
    const(char)* segover;       // segment override string

    // Callbacks provided by caller
    const(char)*function(uint c, uint sz, addr offset) mem;
    const(char)*function(ubyte[] code, uint c, int sz) immed16;
    const(char)*function(uint c, uint offset, bool farflag, bool is16bit) labelcode;
    const(char)*function(uint pc, int offset) shortlabel;


addr calccodsize(addr c, out addr pc)
{
    pc = c;
    return 4;
}

/*****************************
 * Load byte at code[c].
 */

const(char)* immed8(uint c) @safe
{
    return wordtostring(code[c]);
}

/*****************************
 * Load byte at code[c], and sign-extend it
 */

const(char)* immeds(uint c)
{
    return wordtostring(cast(byte) code[c]);
}




void puts(const(char)* s)
{
    while (*s)
    {
        put(*s);
        ++s;
    }
}

/*************************
 * Disassemble the instruction at `c`
 * Params:
 *      c = index into code[]
 */

void disassemble(uint c)
{
    //printf("disassemble(c = %d, siz = %d)\n", c, siz);
    enum log = false;
    enum useAlias = true;  // decode to alias syntax
    puts("   ");

    int i;
    char[80] p0;
    const(char)* sep;
    const(char)* s2;
    const(char)* s3;
    char[BUFMAX] buf = void;

    buf[0] = 0;
    sep = ",".ptr;
    s2 = "".ptr;
    s3 = s2;
    uint ins = *(cast(uint*)&code[c]);
    p0[0]='\0';

    if (bObjectcode) {
        for (i=siz; i; --i) {
            snprintf( buf.ptr, buf.length, "%02X", code[c+i-1] );
            printf("%s ", buf.ptr);
            //strcat( p0.ptr, buf.ptr );
        }
    }

    char[8+1] p1buf = void;
    snprintf(p1buf.ptr,p1buf.length,"%08x", ins);
    if (log) printf("ins: %s %d %d\n", p1buf.ptr, field(ins, 28, 24), field(ins, 21, 21));
    const(char)* p1 = p1buf.ptr;
    const(char)* p2 = "";
    const(char)* p3 = "";
    const(char)* p4 = "";
    const(char)* p5 = "";
    const(char)* p6 = "";
    const(char)* p7 = "";

    immutable char*[4] addsubTab = [ "add", "adds", "sub", "subs" ];
    immutable char*[16] condstring =
        [ "eq", "ne", "cs", "cc", "mi", "pl", "vs", "vc",
          "hi", "ls", "ge", "lt", "gt", "le", "al", "nv" ];

    void shiftP()
    {
        p2 = p3;
        p3 = p4;
        p4 = p5;
        p5 = p6;
        p6 = p7;
        p7 = "";
    }

    if (field(ins, 31, 16) == 0) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#reserved
    {
        if (log) printf("reserved");
        uint imm16 = field(ins, 15, 0);
        p1 = "udf";
        p2 = wordtostring(imm16);
    }
    else if (field(ins, 30, 23) == 0xE7) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_1src_imm
    {
        if (log) printf("Data-processing (1 source immediate)\n");
        uint sf    = field(ins, 31, 31);
        uint opc   = field(ins, 22, 21);
        uint imm16 = field(ins, 20, 05);
        uint Rd    = field(ins,  4,  0);

        if (sf == 1 && (opc & 2) == 0 && Rd == 0x1F)
        {
            p1 = opc & 1 ? "aitobsppc" : "aitoasppc";
            p2 = wordtostring(imm16);
        }
    }
    else if (field(ins, 28, 23) == 0x10) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#pcreladdr
    {
        if (log) printf("PC-rel. addressing\n");
        uint op    = field(ins, 31, 31);
        uint immlo = field(ins, 30, 29);
        uint immhi = field(ins, 23, 05);
        uint Rd    = field(ins,  4,  0);

        p1 = op ? "adrp" : "adr";
        p2 = regString(1, Rd);
        uint imm = op ? ((immhi << 2) | immlo) << 12
                      : ((immhi << 2) | immlo);
        p3 = wordtostring(imm);
    }
    else if (field(ins, 28, 23) == 0x22) // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_ext
    {
        if (log) printf("Add/subtract (immediate)\n");
        uint sf    = field(ins, 31, 31);
        uint op    = field(ins, 30, 30);
        uint S     = field(ins, 29, 29);
        uint sh    = field(ins, 22, 22);
        uint imm12 = field(ins, 21, 10);
        uint Rn    = field(ins,  9,  5);
        uint Rd    = field(ins,  4,  0);

        uint opS = op * 2 + S;

        p1 = addsubTab[opS];
        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);
        p4 = wordtostring(imm12 << (sh * 12));

        if (opS == 0 && sh == 0 && imm12 == 0 && (Rd == 31 || Rn == 31))
        {
            p1 = "mov"; // https://www.scs.stanford.edu/~zyedidia/arm64/add_addsub_imm.html
            p4 = "";
        }
        else if (opS == 1 && Rd == 31) // adds
        {
            p1 = "cmn"; // https://www.scs.stanford.edu/~zyedidia/arm64/adds_addsub_imm.html
            shiftP();
        }
        else if (opS == 3 && Rd == 31)
        {
            p1 = "cmp";  // https://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_imm.html
            shiftP();
        }
    }
    else if (field(ins, 28, 22) == 0x45) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#pcreladdr
    {
        if (log) printf("Add/subtract (immediate, with tags)\n");
        uint sf    = field(ins, 31, 31);
        uint op    = field(ins, 30, 30);
        uint S     = field(ins, 29, 29);
        uint uimm6 = field(ins, 21, 16);
        uint op3   = field(ins, 15, 14);
        uint uimm4 = field(ins, 13, 10);
        uint Rn    = field(ins,  9,  5);
        uint Rd    = field(ins,  4,  0);

        if (sf == 1 && S == 0)
        {
            p1 = op ? "subg" : "addg";
            p2 = regString(sf, Rd);
            p3 = regString(sf, Rn);
            p4 = wordtostring(uimm6);
            p5 = wordtostring(uimm4);
        }
    }
    else if (field(ins, 28, 22) == 0x47) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#minmax_imm
    {
        if (log) printf("Min/max (immediate)\n");
        uint sf    = field(ins, 31, 31);
        uint op    = field(ins, 30, 30);
        uint S     = field(ins, 29, 29);
        uint opc   = field(ins, 21, 18);
        uint imm8  = field(ins, 17, 10);
        uint Rn    = field(ins,  9,  5);
        uint Rd    = field(ins,  4,  0);

        if (op == 0 && S == 0 && opc < 4)
        {
            immutable char*[4] opstring = [ "smax", "umax", "smin", "umin" ];
            p1 = opstring[opc];
            p2 = regString(sf, Rd);
            p3 = regString(sf, Rn);
            p4 = wordtostring(imm8);
        }
    }
    else if (field(ins, 28, 23) == 0x24) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#log_imm
    {
        if (log) printf("Logical (immediate)\n");
        uint sf    = field(ins, 31, 31);
        uint opc   = field(ins, 30, 29);
        uint N     = field(ins, 22, 22);
        uint immr  = field(ins, 21, 16);
        uint imms  = field(ins, 15, 10);
        uint Rn    = field(ins,  9,  5);
        uint Rd    = field(ins,  4,  0);
        //printf("N:%d immr:x%x imms:x%x\n", N, immr, imms);
        if (sf || N == 0)
        {
            immutable char*[4] opstring = [ "and", "orr", "eor", "ands" ];
            p1 = opstring[opc];
            p2 = regString(sf, Rd);
            p3 = regString(sf, Rn);
            uint imm = sf ? (imms << 6) | immr : (N << 12) | (imms << 6) | immr;
            p4 = wordtostring(imm);
            if (opc == 3 && Rd == 0x1F)
            {
                p1 = "tst";
                shiftP();
            }
            else if (opc == 1 && Rn == 0x1F)
            {
                p1 = "mov";
                p3 = p4;
                p4 = "";
            }
        }
    }
    else if (field(ins, 28, 23) == 0x25) // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#movewidex
    {
        if (log) printf("Move wide (immediate)\n");
        uint sf    = field(ins, 31, 31);
        uint opc   = field(ins, 30, 29);
        uint hw    = field(ins, 22, 21);
        uint imm16 = field(ins, 20, 5);
        uint Rd    = field(ins, 4, 0);
        if (opc == 0) // https://www.scs.stanford.edu/~zyedidia/arm64/movn.html
        {
            if (useAlias)
            {
                bool mov = !(imm16 == 0 && hw != 0) && imm16 != 0xFFFF;
                p1 = mov ? "mov" : "movn";
                ulong imm = cast(ulong)imm16 << (hw * 16);
                if (mov)
                    imm = ~imm;
                if (!sf)
                    imm &= 0xFFFF_FFFF;
                p3 = wordtostring(imm);
                hw = 0;
            }
            else
            {
                p1 = "movn";
                p3 = wordtostring(imm16);
            }
        }
        else if (opc == 2)
        {
            p1 = (imm16 || hw == 0) ? "mov" : "movz";
            p3 = wordtostring(imm16);
        }
        else if (opc == 3)
        {
            p1 = "movk";
            p3 = wordtostring(imm16);
        }
        p2 = regString(sf, Rd);
        if (hw)
        {
            __gshared char[5 + hw.sizeof * 3 + 1 + 1] P4 = void;
            snprintf(P4.ptr, P4.length, "lsl #%d", hw * 16);
            p4 = P4.ptr;
        }
    }
    else if (field(ins, 28, 23) == 0x26) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#bitfield
    {
        if (log) printf("Bitfield\n");
        uint sf    = field(ins, 31, 31);
        uint opc   = field(ins, 30, 29);
        uint N     = field(ins, 22, 22);
        uint immr  = field(ins, 21, 16);
        uint imms  = field(ins, 15, 10);
        uint Rn    = field(ins,  9,  5);
        uint Rd    = field(ins,  4,  0);

        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);

        if (opc == 0) // SBFM
        {
           if ((sf ? 63 : 31) == imms)
           {
                p1 = "asr";
                p4 = wordtostring(immr);
           }
           else if (imms < immr)
           {
                p1 = "sbfiz";                      // https://www.scs.stanford.edu/~zyedidia/arm64/sbfiz_sbfm.html
                uint lsb = sf ? (-immr & 63) : (-immr & 31);
                uint width = imms + 1;
                p4 = wordtostring(lsb);  // is this right?
                p5 = wordtostring2(width);
           }
           else if (immr == 0 && imms == 7)
           {
                p1 = "sxtb";
           }
           else if (immr == 0 && imms == 15)
           {
                p1 = "sxth";
           }
           else if (immr == 0 && imms == 31)
           {
                p1 = "sxtw";
           }
           else if (1) // https://www.scs.stanford.edu/~zyedidia/arm64/sbfx_sbfm.html
           {
                p1 = "sbfx";
                p4 = wordtostring(-immr);
                p5 = wordtostring2(imms + 1 - immr);
           }
           else
           {
                p1 = "sbfm";                       // https://www.scs.stanford.edu/~zyedidia/arm64/sbfm.html
                p4 = wordtostring(immr);
                p5 = wordtostring2(imms);
           }
        }
        else if (opc == 1) // BFM https://www.scs.stanford.edu/~zyedidia/arm64/bfm.html
        {
           if (Rn == 0x1F && imms < immr)
           {
                p1 = "bfc";                       // https://www.scs.stanford.edu/~zyedidia/arm64/bfc.html
                p3 = wordtostring(-immr);
                p4 = wordtostring2(imms - 1);
           }
           else if (Rn != 0x1F && imms < immr)
           {
                p1 = "bfi";                       // https://www.scs.stanford.edu/~zyedidia/arm64/bfi.html
                p4 = wordtostring(-immr);
                p5 = wordtostring2(imms - 1);
           }
           else if (imms >= immr)
           {
                p1 = "bfxil";                     // https://www.scs.stanford.edu/~zyedidia/arm64/bfxil.html
                p4 = wordtostring(immr);
                p5 = wordtostring2(imms + 1 - immr);
           }
           else
           {
                p1 = "bfm";                       // https://www.scs.stanford.edu/~zyedidia/arm64/bfm.html
                p4 = wordtostring(immr);
                p5 = wordtostring2(imms);
           }
        }
        else if (opc == 2) // UBFM
        {
           if ((sf ? imms != 31 : imms != 15) && imms + 1 == immr)
           {
                p1 = "lsl";                        // https://www.scs.stanford.edu/~zyedidia/arm64/lsl_ubfm.html
                p4 = wordtostring((sf ? 63 : 31) - imms);
           }
           else if (sf ? imms == 63 : imms == 31)
           {
                p1 = "lsr";                        // https://www.scs.stanford.edu/~zyedidia/arm64/lsr_ubfm.html
                p4 = wordtostring(immr);
           }
           else if (imms < immr)
           {
                p1 = "ubfiz";                      // https://www.scs.stanford.edu/~zyedidia/arm64/ubfiz_ubfm.html
                p4 = wordtostring(-immr);
                p5 = wordtostring2(imms - 1);
           }
           else if (immr == 0 && imms == 7)
           {
                p1 = "uxtb";                      // https://www.scs.stanford.edu/~zyedidia/arm64/uxtb_ubfm.html
           }
           else if (immr == 0 && imms == 15)
           {
                p1 = "uxth";                      // https://www.scs.stanford.edu/~zyedidia/arm64/uxth_ubfm.html
           }
           else if (1)
           {
                p1 = "ubfx";                      // https://www.scs.stanford.edu/~zyedidia/arm64/ubfx_ubfm.html
                p4 = wordtostring(immr);
                p5 = wordtostring2(imms + 1 - immr);
           }
           else
           {
                p1 = "ubfm";                       // https://www.scs.stanford.edu/~zyedidia/arm64/ubfm.html
                p4 = wordtostring(immr);
                p5 = wordtostring2(imms);
           }
        }
    }
    else if (field(ins, 28, 23) == 0x27) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#extract
    {
        if (log) printf("Extract\n");
        uint sf    = field(ins, 31, 31);
        uint op21  = field(ins, 30, 29);
        uint N     = field(ins, 22, 22);
        uint oO    = field(ins, 21, 21);
        uint Rm    = field(ins, 20, 16);
        uint imms  = field(ins, 15, 10);
        uint Rn    = field(ins,  9,  5);
        uint Rd    = field(ins,  4,  0);
        if (Rn == Rm)
        {
            p1 = "ror";
            p2 = regString(sf, Rd);
            p3 = regString(sf, Rn);
            p4 = wordtostring(imms);
        }
        else
        {
            p1 = "extr";
            p2 = regString(sf, Rd);
            p3 = regString(sf, Rn);
            p4 = regString(sf, Rm);
            p5 = wordtostring(imms);
        }
    }
    else if (field(ins, 31, 24) == 0x54) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condbranch
    {
        if (log) printf("Conditional branch (immediate)\n");
        uint imm19 = field(ins, 23, 5);
        uint oO    = field(ins, 4, 4);
        uint cond  = field(ins, 3, 0);

        const char* format = oO ? "bc.%s" : "b.%s";
        sprintf(buf.ptr, format, condstring[cond]);
        p1 = buf.ptr;
        p2 = wordtostring(imm19);
    }
    else if (field(ins, 31, 24) == 0x55) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#miscbranch
    {
        if (log) printf("Miscellaneous branch (immediate)\n");
        uint opc   = field(ins, 23, 21);
        uint imm16 = field(ins, 20,  5);
        uint op2   = field(ins,  4,  0);

        if ((opc & 6) == 0 && op2 == 0x1F)
        {
            p1 = opc ? "retabsppc" : "retaaspcc";
            p2 = labeltostring(imm16 << 2);
        }
    }
    else if (field(ins, 31, 24) == 0xB4) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#exception
    {
        if (log) printf("Exception generation\n");
        uint opc   = field(ins, 23, 21);
        uint imm16 = field(ins, 20,  5);
        uint op2   = field(ins,  4,  2);
        uint LL    = field(ins,  1,  0);

        if (op2 == 0)
        {
            uint X(uint opc, uint LL) { return (opc << 2) | LL; }
            switch (X(opc, LL))
            {
                case X(0, 1): p1 = "svc";     goto Limm;
                case X(0, 2): p1 = "hvc";     goto Limm;
                case X(0, 3): p1 = "smc";     goto Limm;
                case X(1, 0): p1 = "brk";     goto Limm;
                case X(2, 0): p1 = "hlt";     goto Limm;
                case X(3, 0): p1 = "tcancel"; goto Limm;
                Limm:
                    p2 = wordtostring(imm16);
                    break;

                case X(5, 1): p1 = "dcps1"; goto Ldcps;
                case X(5, 2): p1 = "dcps2"; goto Ldcps;
                case X(5, 3): p1 = "dcps3"; goto Ldcps;
                Ldcps:
                    if (imm16)
                        p2 = wordtostring(imm16);
                    break;

                default:
                    break;
            }
        }
    }
    else if (field(ins, 31, 12) == 0xD5031) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#systeminstrswithreg
    {
        if (log) printf("System instructions with register argument\n");
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        if (CRm == 0 && (op2 >> 1) == 0)
        {
            p1 = op2 ? "wfit" : "wfet";
            p2 = regString(1, Rt);
        }
    }
    else if (field(ins, 31, 12) == 0xD5032) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#hints
    {
        if (log) printf("Hints\n");
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        if (CRm <= 5 && Rt == 0x1F)
        {
            uint Z(uint CRm, uint op2) { return (CRm << 3) | op2; }
            switch (Z(CRm, op2))
            {
                case Z(0, 0): p1 = "nop";         break;
                case Z(0, 1): p1 = "yield";       break;
                case Z(0, 2): p1 = "wfe";         break;
                case Z(0, 3): p1 = "wfi";         break;
                case Z(0, 4): p1 = "sev";         break;
                case Z(0, 5): p1 = "sevl";        break;
                case Z(0, 6): p1 = "dgh";         break;
                case Z(0, 7): p1 = "xpaclri";     break;
                case Z(1, 0): p1 = "pacia1716";   break;
                case Z(1, 2): p1 = "pacob1716";   break;
                case Z(1, 4): p1 = "autia1716";   break;
                case Z(1, 6): p1 = "autib1716";   break;
                case Z(2, 0): p1 = "esb";         break;
                case Z(2, 1): p1 = "psb csync";   break;
                case Z(2, 2): p1 = "tsb csync";   break;
                case Z(2, 3): p1 = "gcsb dsync";  break;
                case Z(2, 4): p1 = "csdb";        break;
                case Z(2, 6): p1 = "clrbhb";      break;
                case Z(3, 0): p1 = "paciaz";      break;
                case Z(3, 1): p1 = "paciasp";     break;
                case Z(3, 2): p1 = "pacibz";      break;
                case Z(3, 3): p1 = "pacibsp";     break;
                case Z(3, 4): p1 = "autiaz";      break;
                case Z(3, 5): p1 = "autiasp";     break;
                case Z(3, 6): p1 = "autibz";      break;
                case Z(3, 7): p1 = "autibsp";     break;
                case Z(4, 7): p1 = "pacm";        break;
                case Z(5, 0): p1 = "chkfeat x16"; break;

                default:
                    if (CRm == 4 && (op2 & 1) == 0)
                    {
                        p1 = "bti";
                        immutable char*[4] option = [ "", "c", "j", "jc" ];
                        p2 = option[op2 >> 1];
                    }
                    break;
            }
        }
    }
    else if (field(ins, 31, 12) == 0xD5033) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#barriers
    {
        if (log) printf("Barriers\n");
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        if (Rt == 0x1F)
        {
            if (op2 == 2)
            {
                p1 = "clrex";
                if (CRm)
                    p2 = wordtostring(CRm);
            }
            else if (op2 == 4)
            {
                if (CRm == 4)
                    p1 = "pssbb";
                else if (CRm == 0)
                    p1 = "ssbb";
                else
                {
                    p1 = "dsb";
                    p2 = wordtostring(CRm);
                }
            }
            else if (op2 == 5)
            {
                p1 = "dsb";
                p2 = wordtostring(CRm);
            }
            else if (op2 == 6)
            {
                p1 = "isb";
                if (CRm != 15)
                    p2 = wordtostring(CRm);
            }
            else if (op2 == 7)
                p1 = "sb";
            else if ((CRm & 3) == 2 && op2 == 1)
            {
                p1 = "dsb";
                immutable char*[4] xs = [ "oshnXS", "nshnXS", "ishnXS", "synXS" ];
                p2 = xs[CRm >> 2];
            }
            else if (CRm == 0 && op2 == 3)
                p1 = "tcommit";
        }
    }
    else if (field(ins, 31, 19) == 0x1AA0) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#pstate
    {
        if (log) printf("PSTATE\n");
        uint op1   = field(ins, 18, 16);
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        if (Rt == 0x1F)
        {
            if (op1 == 0 && op2 == 0)
                p1 = "cfinv";
            else if (op1 == 0 && op2 == 1)
                p1 = "xaflag";
            else if (op1 == 0 && op2 == 2)
                p1 = "axflag";
            else
            {
                p1 = "msr";
                p2 = wordtostring((op1 << 7) | (op2 << 4) | CRm); // <pstatefield>
                p3 = wordtostring(CRm);
            }
        }
    }
    else if (field(ins, 31, 19) == 0x1AA4) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#systemresult
    {
        if (log) printf("System with result\n");
        uint op1   = field(ins, 18, 16);
        uint CRn   = field(ins, 15, 12);
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        if (op1 == 3 && CRn == 3 && op2 == 3)
        {
            if (CRm == 0)
            {
                p1 = "tstart";
                p2 = regString(1, Rt);
            }
            else if (CRm == 1)
            {
                p1 = "ttest";
                p2 = regString(1, Rt);
            }
        }
    }
    else if (field(ins, 31, 22) == 0x354 && field(ins, 20, 19) == 1) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#systeminstrs
    {
        if (log) printf("System instructions\n");
        uint L     = field(ins, 21, 21);
        uint op1   = field(ins, 18, 16);
        uint CRn   = field(ins, 15, 12);
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        if (L)
        {
            if (op1 == 3 && CRn == 7 && CRm == 7 && (op2 == 1 || op2 == 3))
            {
                p1 = op2 == 1 ? "gcspopm" : "gcss2";
                if (Rt != 0x1F || op2 == 3)
                    p2 = regString(1, Rt);
            }
            else
            {
                p1 = "sysl";
                p2 = regString(1, Rt);
                p3 = wordtostring(op1);
                p4 = cregString(CRn);
                p5 = cregString(CRm);
                p6 = wordtostring2(op2);
            }
        }
        else
        {
            p1 = "sys";
            p2 = wordtostring(op1);
            p3 = cregString(CRn);
            p4 = cregString(CRm);
            p5 = wordtostring2(op2);
            if (Rt != 0x1F)
                p6 = regString(1, Rt);
            // TODO: a bunch of aliases http://www.scs.stanford.edu/~zyedidia/arm64/sys.html
        }
    }
    else if (field(ins, 31, 22) == 0x354 && field(ins, 20, 20) == 1) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#systemmove
    {
        if (log) printf("System register move\n");
        uint L     = field(ins, 21, 21);
        uint oO    = field(ins, 19, 19);
        uint op1   = field(ins, 18, 16);
        uint CRn   = field(ins, 15, 12);
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        snprintf(buf.ptr, cast(uint)buf.length, "S%d_%d_%s_%s_%d".ptr, oO + 2, op1, cregString(CRn), cregString(CRm), op2);
        if (L)
        {
            p1 = "mrs";
            p2 = regString(1, Rt);
            p3 = buf.ptr;
        }
        else
        {
            p1 = "msr";
            p2 = buf.ptr;
            p3 = regString(1, Rt);
        }
    }
    else if (field(ins, 31, 22) == 0x355 && field(ins, 20, 19) == 1) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#syspairinstrs
    {
        if (log) printf("System pair instructions\n");
        uint L     = field(ins, 21, 21);
        uint op1   = field(ins, 18, 16);
        uint CRn   = field(ins, 15, 12);
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        if (L == 0)
        {
            p1 = "sysp";
            p2 = wordtostring(op1);
            p3 = cregString(CRn);
            p4 = cregString(CRm);
            p5 = wordtostring2(op2);
            if (Rt != 0x1F)
            {
                p6 = regString(1, Rt);
                p7 = regString(1, Rt + 1);
            }
            // TODO: tlbip alias http://www.scs.stanford.edu/~zyedidia/arm64/tlbip_sysp.html
        }
    }
    else if (field(ins, 31, 22) == 0x355 && field(ins, 20, 20) == 1) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#systemmovepr
    {
        if (log) printf("System register pair move\n");
        uint L     = field(ins, 21, 21);
        uint oO    = field(ins, 19, 19);
        uint op1   = field(ins, 18, 16);
        uint CRn   = field(ins, 15, 12);
        uint CRm   = field(ins, 11,  8);
        uint op2   = field(ins,  7,  5);
        uint Rt    = field(ins,  4,  0);

        snprintf(buf.ptr, cast(uint)buf.length, "S%d_%d_%s_%s_%d".ptr, oO + 2, op1, cregString(CRn), cregString(CRm), op2);
        if (L)
        {
            p1 = "mrrs";
            p2 = regString(1, Rt);
            p3 = regString(1, Rt + 1);
            p4 = buf.ptr;
        }
        else
        {
            p1 = "msrr";
            p2 = buf.ptr;
            p3 = regString(1, Rt);
            p4 = regString(1, Rt + 1);
        }
    }
    else if (field(ins, 31, 25) == 0x6B) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#branch_reg
    {
        if (log) printf("Unconditional branch (register)\n");
        uint opc = field(ins, 24, 21);
        uint op2 = field(ins, 20, 16);
        uint op3 = field(ins, 15, 10);
        uint Rn  = field(ins,  9,  5);
        uint op4 = field(ins,  4,  0);

        //printf("opc x%0x op2 x%0x op3 x%0x Rn x%0x op4 x%0x\n", opc, op2, op3, Rn, op4);
        if (opc == 0 && op2 == 0x1F && op3 == 0 && op4 == 0)
        {
            p1 = "br";
            p2 = xregs[Rn];
        }
        else if (opc == 0 && op2 == 0x1F && op3 == 2 && op4 == 0x1F)
        {
            p1 = "braaz";
            p2 = xregs[Rn];
        }
        else if (opc == 0 && op2 == 0x1F && op3 == 3 && op4 == 0x1F)
        {
            p1 = "brabz";
            p2 = xregs[Rn];
        }
        else if (opc == 1 && op2 == 0x1F && op3 == 0 && op4 == 0)
        {
            p1 = "blr";
            p2 = xregs[Rn];
        }
        else if (opc == 1 && op2 == 0x1F && op3 == 2 && op4 == 0x1F)
        {
            p1 = "blraaz";
            p2 = xregs[Rn];
        }
        else if (opc == 1 && op2 == 0x1F && op3 == 3 && op4 == 0x1F)
        {
            p1 = "blrabz";
            p2 = xregs[Rn];
        }
        else if (opc == 2 && op2 == 0x1F && op3 == 0 && op4 == 0)
        {
            p1 = "ret";
            if (Rn != 30)
                p2 = xregs[Rn];
        }
        else if (opc == 2 && op2 == 0x1F && op3 == 2 && Rn == 0x1F && op4 == 0x1F)
            p1 = "retaa";
        else if (opc == 2 && op2 == 0x1F && op3 == 3 && Rn == 0x1F && op4 == 0x1F)
            p1 = "retab";
        else if (opc == 2 && op2 == 0x1F && op3 == 2 && Rn == 0x1F && op4 != 0x1F)
        {
            p1 = "retaasppc";
            p2 = xregs[op4];
        }
        else if (opc == 2 && op2 == 0x1F && op3 == 3 && Rn == 0x1F && op4 != 0x1F)
        {
            p1 = "retabsppc";
            p2 = xregs[op4];
        }
        else if (opc == 4 && op2 == 0x1F && op3 == 0 && Rn == 0x1F && op4 == 0)
            p1 = "eret";
        else if (opc == 4 && op2 == 0x1F && op3 == 2 && Rn == 0x1F && op4 == 0x1F)
            p1 = "eretaa";
        else if (opc == 4 && op2 == 0x1F && op3 == 3 && Rn == 0x1F && op4 == 0x1F)
            p1 = "eretab";
        else if (opc == 5 && op2 == 0x1F && op3 == 0 && Rn == 0x1F && op4 == 0)
            p1 = "drps";
        else if (opc == 0x8 && op2 == 0x1F && op3 == 2)
        {
            p1 = "braa";
            p2 = xregs[Rn];
            if (op4 != 0x1F)
                p3 = xregs[op4];
        }
        else if (opc == 0x8 && op2 == 0x1F && op3 == 3)
        {
            p1 = "brab";
            p2 = xregs[Rn];
            if (op4 != 0x1F)
                p3 = xregs[op4];
        }
        else if (opc == 0x9 && op2 == 0x1F && op3 == 2)
        {
            p1 = "blraa";
            p2 = xregs[Rn];
            if (op4 != 0x1F)
                p3 = xregs[op4];
        }
        else if (opc == 0x9 && op2 == 0x1F && op3 == 3)
        {
            p1 = "blrab";
            p2 = xregs[Rn];
            if (op4 != 0x1F)
                p3 = xregs[op4];
        }
    }
    else if (field(ins, 30, 26) == 0x05) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#branch_imm
    {
        if (log) printf("Unconditional branch (immediate)\n");
        uint    op = field(ins, 31, 31);
        uint imm26 = field(ins, 25,  0);

        p1 = op ? "bl" : "b";
        p2 = wordtostring(imm26 * 4);
    }
    else if (field(ins, 30, 25) == 0x1A) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#compbranch
    {
        if (log) printf("Compare and branch (immediate)\n");
        uint sf      = field(ins, 31, 31);
        uint op      = field(ins, 24, 24);
        uint imm19   = field(ins, 23,  5);
        uint Rt      = field(ins,  4,  0);

        p1 = op ? "cbnz" : "cbz";
        p2 = regString(sf, Rt);
        p3 = wordtostring(imm19 * 4);
    }
    else if (field(ins, 30, 25) == 0x1B) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#testbranch
    {
        if (log) printf("Test and branch (immediate)\n");
        uint b5      = field(ins, 31, 31);
        uint op      = field(ins, 24, 24);
        uint b40     = field(ins, 23, 19);
        uint imm14   = field(ins, 18,  5);
        uint Rt      = field(ins,  4,  0);

        p1 = op ? "tbnz" : "tbz";
        p2 = regString(b5, Rt);
        p3 = wordtostring((b5 << 5) | b40);
        p4 = wordtostring(imm14 * 4);
    }
    else if (field(ins, 30, 30) == 0 && field(ins, 28, 21) == 0xD6) // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_2src
    {
        if (log) printf("Data-processing (2 source)\n");
        uint sf      = field(ins, 31, 31);
        uint S       = field(ins, 29, 29);
        uint Rm      = field(ins, 20, 16);
        uint opcode  = field(ins, 15, 10);
        uint Rn      = field(ins,  9,  5);
        uint Rd      = field(ins,  4,  0);

        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);
        p4 = regString(sf, Rm);

        uint sfSopcode = (sf << 7) | (S << 6) | opcode;

        switch (sfSopcode)
        {
            case 2: // https://www.scs.stanford.edu/~zyedidia/arm64/udiv.html
            case 0x82:
                p1 = "udiv";
                break;

            case 3: // https://www.scs.stanford.edu/~zyedidia/arm64/sdiv.html
            case 0x83:
                p1 = "sdiv";
                break;

            case 8: // https://www.scs.stanford.edu/~zyedidia/arm64/lslv.html
            case 0x88:
                p1 = "lsl";
                break;

            case 9: // https://www.scs.stanford.edu/~zyedidia/arm64/lsrv.html
            case 0x89:
                p1 = "lsr";
                break;

            case 0x0A: // https://www.scs.stanford.edu/~zyedidia/arm64/asrv.html
            case 0x8A:
                p1 = "asr";
                break;

            case 0x0B: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
            case 0x8B:
                p1 = "ror";
                break;

            case 0x10: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
                p1 = "crc32b";
                break;

            case 0x11: // https://www.scs.stanford.edu/~zyedidia/arm64/crc32.html#CRC32B_32C_dp_2src
                p1 = "crc32h";
                break;

            case 0x12: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
                p1 = "crc32w";
                break;

            case 0x14: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
                p1 = "crc32cb";
                break;

            case 0x15: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
                p1 = "crc32ch";
                break;

            case 0x16: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
                p1 = "crc32cw";
                break;

            case 0x18: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
            case 0x98:
                p1 = "smax";
                break;

            case 0x19: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
            case 0x99:
                p1 = "umax";
                break;

            case 0x1A: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
            case 0x9A:
                p1 = "smin";
                break;

            case 0x1B: // https://www.scs.stanford.edu/~zyedidia/arm64/rorv.html
            case 0x9B:
                p1 = "umin";
                break;

            case 0x80: // https://www.scs.stanford.edu/~zyedidia/arm64/subp.html
                p1 = "subp";
                break;

            case 0xC0: // https://www.scs.stanford.edu/~zyedidia/arm64/subps.html
                p1 = "subs";
                break;

            case 0x93: // https://www.scs.stanford.edu/~zyedidia/arm64/crc32x.html
                p1 = "crc32x";
                break;

            case 0x97: // https://www.scs.stanford.edu/~zyedidia/arm64/crc32cx.html
                p1 = "crc32x";
                break;

            case 0x84: // https://www.scs.stanford.edu/~zyedidia/arm64/irg.html
                p1 = "irg";
                break;

            case 0x85: // https://www.scs.stanford.edu/~zyedidia/arm64/gmi.html
                p1 = "gmi";
                break;

            case 0x8C: // https://www.scs.stanford.edu/~zyedidia/arm64/pacga.html
                p1 = "pacga";
                break;

            default:
                p2 = p3 = p4 = "";
                break;
        }
    }
    else if (field(ins, 30, 30) == 1 && field(ins, 28, 21) == 0xD6) // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_1src
    {
        if (log) printf("Data-processing (1 source)\n");
        uint sf      = field(ins, 31, 31);
        uint S       = field(ins, 29, 29);
        uint opcode2 = field(ins, 20, 16);
        uint opcode  = field(ins, 15, 10);
        uint Rn      = field(ins,  9,  5);
        uint Rd      = field(ins,  4,  0);

        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);

        uint decode(uint sf, uint S, uint opcode2, uint opcode)
        { return (sf << (1 + 5 + 6)) | (S << (5 + 6)) | (opcode2 << 6) | opcode; }

        switch (decode(sf, S, opcode2, opcode))
        {
            case decode(0, 0, 0, 0x00):
            case decode(1, 0, 0, 0x00):     p1 = "rbit";    break;
            case decode(0, 0, 0, 0x01):
            case decode(1, 0, 0, 0x01):     p1 = "rev16";   break;
            case decode(0, 0, 0, 0x02):     p1 = "rev";     break;
            case decode(1, 0, 0, 0x02):     p1 = "rev32";   break;
            case decode(1, 0, 0, 0x03):     p1 = "rev64";   break;
            case decode(0, 0, 0, 0x04):
            case decode(1, 0, 0, 0x04):     p1 = "clz";     break;
            case decode(0, 0, 0, 0x05):
            case decode(1, 0, 0, 0x05):     p1 = "cls";     break;
            case decode(0, 0, 0, 0x06):
            case decode(1, 0, 0, 0x06):     p1 = "ctz";     break;
            case decode(0, 0, 0, 0x07):
            case decode(1, 0, 0, 0x07):     p1 = "cnt";     break;
            case decode(0, 0, 0, 0x08):
            case decode(1, 0, 0, 0x08):     p1 = "abs";     break;
            case decode(1, 0, 1, 0x00):     p1 = "pacia";   break;
            case decode(1, 0, 1, 0x01):     p1 = "pacib";   break;
            case decode(1, 0, 1, 0x02):     p1 = "pacda";   break;
            case decode(1, 0, 1, 0x03):     p1 = "pacdb";   break;
            case decode(1, 0, 1, 0x04):     p1 = "autia";   break;
            case decode(1, 0, 1, 0x05):     p1 = "autib";   break;
            case decode(1, 0, 1, 0x06):     p1 = "autda";   break;
            case decode(1, 0, 1, 0x07):     p1 = "autdb";   break;
            case decode(1, 0, 1, 0x08):     if (Rn == 0x1F) p1 = "paciza";  break;
            case decode(1, 0, 1, 0x09):     if (Rn == 0x1F) p1 = "pacizb";  break;
            case decode(1, 0, 1, 0x0A):     if (Rn == 0x1F) p1 = "pacdza";  break;
            case decode(1, 0, 1, 0x0B):     if (Rn == 0x1F) p1 = "pacdzb";  break;
            case decode(1, 0, 1, 0x0C):     if (Rn == 0x1F) p1 = "autiza";  break;
            case decode(1, 0, 1, 0x0D):     if (Rn == 0x1F) p1 = "autizb";  break;
            case decode(1, 0, 1, 0x0E):     if (Rn == 0x1F) p1 = "autdza";  break;
            case decode(1, 0, 1, 0x0F):     if (Rn == 0x1F) p1 = "autdzb";  break;
            case decode(1, 0, 1, 0x10):     if (Rn == 0x1F) p1 = "xpaci";   break;
            case decode(1, 0, 1, 0x11):     if (Rn == 0x1F) p1 = "xpacd";   break;
            case decode(1, 0, 1, 0x20):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "pacnbiasppc"; break;
            case decode(1, 0, 1, 0x21):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "pacnbibsppc"; break;
            case decode(1, 0, 1, 0x22):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "pacia171615"; break;
            case decode(1, 0, 1, 0x23):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "pacib171615"; break;
            case decode(1, 0, 1, 0x24):     if (              Rd == 0x1E)   p1 = "autiasppc";   break;
            case decode(1, 0, 1, 0x25):     if (              Rd == 0x1E)   p1 = "autibsppc";   break;
            case decode(1, 0, 1, 0x28):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "paciasppc";   break;
            case decode(1, 0, 1, 0x29):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "pacibsppc";   break;
            case decode(1, 0, 1, 0x2E):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "autia171615"; break;
            case decode(1, 0, 1, 0x2F):     if (Rn == 0x1F && Rd == 0x1E)   p1 = "autib171615"; break;

            default: p2 = p3 = ""; break;
        }
    }
    else if (field(ins, 28, 24) == 0x0A) // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#log_shift
    {
        if (log) printf("Logical (shifted register)\n");
        uint sf      = field(ins, 31, 31);
        uint opc     = field(ins, 30, 29);
        uint shift   = field(ins, 23, 22);
        uint N       = field(ins, 21, 21);
        uint Rm      = field(ins, 20, 16);
        uint imm6    = field(ins, 15, 10);
        uint Rn      = field(ins,  9,  5);
        uint Rd      = field(ins,  4,  0);

        immutable char*[8] opstring = [ "and", "bic", "orr", "orn", "eor", "eon", "ands", "bics" ];
        p1 = opstring[(opc << 1) | N];
        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);
        p4 = regString(sf, Rm);
        immutable char*[4] shiftstring = [ "", "lsr ", "asr ", "ror " ];
        if (imm6)
        {
            __gshared char[4 + 3 + imm6.sizeof * 3 + 1 + 1] P5 = void;
            snprintf(P5.ptr, P5.length, ((imm6 < 10) ? "%s #%d" : "#0x%X"), shiftstring[shift], imm6);
            p5 = P5.ptr;
        }
        if (((opc << 1) | N) == 2 && Rn == 0x1F)
        {
            p1 = "mov"; // https://www.scs.stanford.edu/~zyedidia/arm64/mov_orr_log_shift.html
            p3 = p4;
            p4 = p5;
            p5 = "";
        }
        else if (((opc << 1) | N) == 3 && Rn == 0x1F)
        {
            p1 = "mvn"; // https://www.scs.stanford.edu/~zyedidia/arm64/mvn_orn_log_shift.html
            p3 = p4;
            p4 = p5;
            p5 = "";
        }
    }
    else if (field(ins, 28, 24) == 11 && field(ins, 21, 21) == 0) // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_shift
    {
        if (log) printf("Add/subtract (shifted register)\n");
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint shift  = field(ins, 23, 22);
        uint Rm     = field(ins, 20, 16);
        uint immed6 = field(ins, 15, 10);
        uint Rn     = field(ins,  9,  5);
        uint Rd     = field(ins,  4,  0);

        uint opS = op * 2 + S;
        p1 = addsubTab[opS];
        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);
        p4 = regString(sf, Rm);

        if (immed6) // defaults to 0
        {
            immutable char*[4] tab2 = [ "lsl", "lsr", "asr", "reserved" ];
            __gshared char[1 + 8 + 1 + 3 + immed6.sizeof * 3 + 1 + 1] P5buf = void;
            snprintf(P5buf.ptr, P5buf.length, ((immed6 < 10) ? "%s #%d".ptr : "#0x%X".ptr), tab2[shift], immed6);
            p5 = P5buf.ptr;
        }

        if (opS == 1 && Rd == 31) // adds
        {
            p1 = "cmn"; // https://www.scs.stanford.edu/~zyedidia/arm64/cmn_adds_addsub_shift.html
            shiftP();
        }
        else if (opS == 2 && Rn == 31)
        {
            p1 = "neg"; // https://www.scs.stanford.edu/~zyedidia/arm64/neg_sub_addsub_shift.html
            p3 = p4;
            p4 = p5;
            p5 = "";
        }
        else if (opS == 3) // subs
        {
            if (Rd == 31)
            {
                p1 = "cmp";
                shiftP();
            }
            else if (Rn == 31)
            {
                p1 = "negs";
                shiftP();
            }
        }
    }
    else if (field(ins, 28, 24) == 11 && field(ins, 21, 21)) // https://www.scs.stanford.edu/~zyedidia/arm64/subs_addsub_ext.html
    {
        if (log) printf("Add/subtract (extended register)\n");
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint opt    = field(ins, 23, 22);
        uint Rm     = field(ins, 20, 16);
        uint option = field(ins, 15, 13);
        uint imm3   = field(ins, 12, 10);
        uint Rn     = field(ins,  9,  5);
        uint Rd     = field(ins,  4,  0);
        //printf("Rd: x%x\n", Rd);

        immutable char*[8] tab = [ "uxtb", "uxth", "ustw", "uxtx", "sxtb","sxth", "sxtw", "sxtx" ];
        const(char)* extend;
        if (sf && Rn == 0x1F && option == 3 ||
           !sf && Rn == 0x1F && option == 2)
            extend = imm3 ? "lsl" : "";
        else
            extend = tab[option];

        uint opS = op * 2 + S;
        p1 = addsubTab[opS];
        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);
        if (sf)
            p4 = regString(option == 3 || option == 7, Rm);
        else
            p4 = regString(sf, Rm);

        __gshared char[1 + 4 + 1 + 3 + imm3.sizeof * 3 + 1 + 1] P5buf2 = void;
        if (imm3 == 0)
            p5 = extend;
        else
            snprintf(P5buf2.ptr, P5buf2.length, ((imm3 < 10) ? "%s #%d" : "#0x%X"), extend, imm3);
        p5 = P5buf2.ptr;

        if (opS == 1 && Rd == 31)
        {
            p1 = "cmn"; // https://www.scs.stanford.edu/~zyedidia/arm64/cmn_adds_addsub_ext.html
            shiftP();
        }
        else if (opS == 3 && Rd == 0)
        {
            p1 = "cmp"; // https://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_ext.html
            shiftP();
        }
    }
    else if (field(ins, 28, 21) == 0xD0 && field(ins, 15, 10) == 0) // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_carry
    {
        if (log) printf("Add/subtract (with carry)\n");
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint Rm     = field(ins, 20, 16);
        uint Rn     = field(ins,  9,  5);
        uint Rd     = field(ins,  4,  0);

        immutable char*[4] opstring = [ "adc", "adcs", "sbc", "sbcs" ];
        p1 = opstring[op * 2 + S];
        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);
        p4 = regString(sf, Rm);
    }
    else if (field(ins, 28, 21) == 0xD0 && field(ins, 15, 13) == 1) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_pt
    {
        if (log) printf("Add/subtract (checked pointer)\n");
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint Rm     = field(ins, 20, 16);
        uint imm3   = field(ins, 12, 10);
        uint Rn     = field(ins,  9,  5);
        uint Rd     = field(ins,  4,  0);

        uint sfopS  = field(ins, 31, 29);
        if (sfopS == 4 || sfopS == 6)
        {
            immutable char*[4] opstring = [ "adc", "adcs", "sbc", "sbcs" ];
            p1 = sfopS == 4 ? "addpt" : "subpt";
            p2 = regString(sf, Rd);
            p3 = regString(sf, Rn);
            p4 = regString(sf, Rm);
            if (imm3)
            {
                __gshared char[7 + imm3.sizeof * 3 + 1] P5buf3 = void;
                size_t n = snprintf(P5buf3.ptr, P5buf3.length, ((imm3 < 10) ? "LSL #%d" : "LSL #0x%X"), imm3);
                assert(n <= P5buf3.length);
                p5 = P5buf3.ptr;
            }
        }
    }
    else if (field(ins, 28, 21) == 0xD0 && field(ins, 14, 10) == 1) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#rmif
    {
        if (log) printf("Rotate right into flags\n");
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint imm3   = field(ins, 20, 15);
        uint Rn     = field(ins,  9,  5);
        uint o2     = field(ins,  4,  4);
        uint mask   = field(ins,  3,  0);

        if (sf == 1 && op == 0 && S == 1 && o2 == 0)
        {
            p1 = "rmif";
            p2 = regString(sf, Rn);
            p3 = wordtostring(imm3);
            p4 = wordtostring2(mask);
        }
    }
    else if (field(ins, 28, 21) == 0xD0 && field(ins, 13, 10) == 2) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#setf
    {
        if (log) printf("Evaluate into flags\n");
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint opcode2= field(ins, 20, 15);
        uint sz     = field(ins,  2,  2);
        uint Rn     = field(ins,  9,  5);
        uint o3     = field(ins,  4,  4);
        uint mask   = field(ins,  3,  0);

        if (sf == 0 && op == 0 && S == 1 && opcode2 == 0 && o3 == 1 && mask == 0xD)
        {
            p1 = sz ? "setf16" : "setf8";
            p2 = regString(sf, Rn);
        }
    }
    else if (field(ins, 28, 21) == 0xD2 && field(ins, 11, 11) == 0)
    {
        if (log) printf("Conditional compare (register)\n"); // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condcmp_reg
        if (log) printf("Conditional compare (immediate)\n"); // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condcmp_imm
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint Rm     = field(ins, 20, 16);
        uint imm5   = Rm;
        uint cond   = field(ins, 15, 12);
        uint o2     = field(ins, 10, 10);
        uint Rn     = field(ins,  9,  5);
        uint o3     = field(ins,  4,  4);
        uint nzcv   = field(ins,  3,  0);

        if (S == 1 && o2 == 0 && o3 == 0)
        {
            p1 = sf * 2 + op ? "ccmn" : "ccmp";
            p2 = regString(sf, Rn);
            p3 = field(ins, 11, 11) ? wordtostring(imm5) : regString(sf, Rm);
            p4 = wordtostring(nzcv);
            p5 = condstring[cond];
        }
    }
    else if (field(ins, 28, 21) == 0xD4) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condsel
    {
        if (log) printf("Conditional select\n");
        uint sf     = field(ins, 31, 31);
        uint op     = field(ins, 30, 30);
        uint S      = field(ins, 29, 29);
        uint Rm     = field(ins, 20, 16);
        uint cond   = field(ins, 15, 12);
        uint op2    = field(ins, 11, 10);
        uint Rn     = field(ins,  9,  5);
        uint Rd     = field(ins,  4,  0);

        immutable char*[4] opstring = [ "csel", "csinc", "csinv", "csneg" ];
        p1 = opstring[op * 2 + (op2 & 1)];
        p2 = regString(sf, Rd);
        p3 = regString(sf, Rn);
        p4 = regString(sf, Rm);
        p5 = condstring[cond];
    }
    else if (field(ins, 28, 24) == 0x1B) // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_3src
    {
        if (log) printf("Data-processing (3 source)\n");
        uint sf     = field(ins, 31, 31);
        uint op54   = field(ins, 30, 29);
        uint op31   = field(ins, 23, 21);
        uint Rm     = field(ins, 20, 16);
        uint oO     = field(ins, 15, 15);
        uint Ra     = field(ins, 14, 10);
        uint Rn     = field(ins,  9,  5);
        uint Rd     = field(ins,  4,  0);

        if (op54 == 0)
        {
            if (op54 == 0 && op31 == 0)
            {
                p1 = oO ? "msub" : "madd";
                p2 = regString(sf, Rd);
                p3 = regString(sf, Rn);
                p4 = regString(sf, Rm);
                p5 = regString(sf, Ra);
                if (oO == 0 && Ra == 0x1F)
                {
                    // http://www.scs.stanford.edu/~zyedidia/arm64/mul_madd.html
                    p1 = "mul";
                    p5 = "";
                }
            }
            else if (sf)
            {
                uint Y(uint op31, uint oO) { return op31 * 2 + oO; }
                switch (Y(op31, oO))
                {
                    case Y(1, 0): p1 = "smaddl"; goto Lxwwx;
                    case Y(1, 1): p1 = "smsubl"; goto Lxwwx;
                    case Y(2, 0): p1 = "smulh";  goto Lxxx;
                    case Y(3, 0): p1 = "maddpt"; goto Lxxxx;
                    case Y(3, 1): p1 = "msubpt"; goto Lxxxx;
                    case Y(5, 0): p1 = "umaddl"; goto Lxwwx;
                    case Y(5, 1): p1 = "umsubl"; goto Lxwwx;
                    case Y(6, 0): p1 = "umulh";  goto Lxxx;

                    Lxwwx:
                        p2 = regString(sf, Rd);
                        p3 = regString( 0, Rn);
                        p4 = regString( 0, Rm);
                        p5 = regString(sf, Ra);
                        break;

                    Lxxx:
                        p2 = regString(sf, Rd);
                        p3 = regString(sf, Rn);
                        p4 = regString(sf, Rm);
                        break;

                    Lxxxx:
                        p2 = regString(sf, Rd);
                        p3 = regString(sf, Rn);
                        p4 = regString(sf, Rm);
                        p5 = regString(sf, Ra);
                        break;

                    default: break;
                }
            }
        }
    }
    else

    // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst Loads and Stores
    if (field(ins, 29, 27) == 7 && field(ins, 25, 24) == 1)
    {
        uint size = field(ins, 31, 30);
        uint VR = field(ins, 26, 26);
        uint opc = field(ins, 23, 22);
        uint imm12 = field(ins, 21, 10);
        uint Rn = field(ins, 9, 5);
        uint Rt = field(ins, 4, 0);

        // https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_pos Load/store register (unsigned immediate)
        // https://www.scs.stanford.edu/~zyedidia/arm64/str_imm_gen.html STR (immediate)
        // https://www.scs.stanford.edu/~zyedidia/arm64/ldr_imm_gen.html LDR (immediate)

        uint ldr(uint size, uint VR, uint opc) { return (size << 3) | (VR << 2) | opc; }

        bool is64 = false;
        switch (ldr(size, VR, opc))
        {
            case ldr(0,0,0): p1 = "strb";  goto Lldr;
            case ldr(0,0,1): p1 = "ldrb";  goto Lldr;
            case ldr(0,0,2): p1 = "ldrsb"; goto Lldr64;
            case ldr(0,0,3): p1 = "ldrsb"; goto Lldr;
            case ldr(1,0,0): p1 = "strh";  goto Lldr;
            case ldr(1,0,1): p1 = "ldrh";  goto Lldr;
            case ldr(1,0,2): p1 = "ldrsh"; goto Lldr64;
            case ldr(1,0,3): p1 = "ldrsh"; goto Lldr;
            case ldr(2,0,0): p1 = "str";   goto Lldr;
            case ldr(2,0,1): p1 = "ldr";   goto Lldr;
            case ldr(2,0,2): p1 = "ldrsw"; goto Lldr64;
            case ldr(3,0,0): p1 = "str";   goto Lldr64;
            case ldr(3,0,1): p1 = "ldr";   goto Lldr64;
            Lldr64:
                is64 = true;
            Lldr:
                p2 = regString(is64, Rt);
                p3 = indexString(Rn);
                if (imm12)
                    p4 = wordtostring(imm12);
                break;

            static if (0) // fix later
            {
            case ldr(0,1,0): p1 = "str";
            case ldr(0,1,1): p1 = "ldr";
            case ldr(0,1,2): p1 = "str";
            case ldr(0,1,3): p1 = "ldr";
            case ldr(1,1,0): p1 = "str";
            case ldr(1,1,1): p1 = "ldr";
            case ldr(2,1,0): p1 = "str";
            case ldr(2,1,1): p1 = "ldr";
            case ldr(3,0,1): p1 = "prfm";
            case ldr(3,1,0): p1 = "str";
            case ldr(3,1,1): p1 = "ldr";
            }

            default:
                break;
        }
    }

    //printf("%x\n", field(ins, 31, 25));
    //printf("p1: %s\n", p1);

    put(' ');
    puts(p1);
    if (*p2)
    {
        for (int len1 = cast(int)strlen(p1); len1 < 9; ++len1)
            put(' ');
        put(' ');
        puts(s2);
        if (*p2 != ' ')
            puts(p2);
        if (*p3)
        {
            puts(sep);
            puts(s3);
            puts(p3);
            if (*p4)
            {
                put(',');
                puts(p4);
                if (*p5)
                {
                    put(',');
                    puts(p5);
                    if (*p6)
                    {
                        put(',');
                        puts(p6);
                        if (*p7)
                        {
                            put(',');
                            puts(p7);
                        }
                    }
                }
            }
        }
    }
}

}

/***********************
 * Default version.
 * Creates string representation of memory location.
 * Params:
 *      c = the address of the memory reference in `code[]`
 *      sz = the number of bytes in the referred to memory location
 *      offset =  the value to be added to any symbolic reference
 * Returns:
 *      string representation of the memory address
 */
@trusted
const(char)* memoryDefault(uint c, uint sz, addr offset)
{
    __gshared char[12 + 1] EA;
    snprintf(EA.ptr,EA.length,"[0%Xh]",offset);
    return EA.ptr;
}

/***********************
 * Default version.
 * Creates string representation of immediate value.
 * Params:
 *      code = the binary instructions
 *      c = the address of the memory reference in `code[]`
 *      sz = the number of bytes in the instruction that form the referenece (2/4/8)
 * Returns:
 *      string representation of the memory address
 */
@trusted
const(char)* immed16Default(ubyte[] code, uint c, int sz)
{
    ulong offset;
    switch (sz)
    {
        case 8:
            offset = dword(code, c) + (cast(ulong)dword(code, c + 4) << 32);
            break;

        case 4:
            offset = dword(code, c);
            break;

        case 2:
            offset = word(code, c);
            break;

        default:
            assert(0);
    }
    __gshared char[1 + offset.sizeof * 3 + 1 + 1] buf;

    snprintf(buf.ptr, buf.length,((cast(long)offset < 10) ? "%lld" : "0%llXh"), offset);
    return buf.ptr;
}

/***********************
 * Default version.
 * Creates string representation of code label.
 * Params:
 *      c = the address of the code reference to the label in `code[]`
 *      offset = address of the label in `code[]`
 *      farflag = if `far` reference
 *      is16bit = if 16 bit reference
 * Returns:
 *      string representation of the memory address
 */
@trusted
const(char)* labelcodeDefault(uint c, uint offset, bool farflag, bool is16bit)
{
    //printf("offset = %x\n", offset);
    __gshared char[1 + uint.sizeof * 3 + 1] buf;
    snprintf(buf.ptr, buf.length, "L%x", offset);
    return buf.ptr;
}

/***********************
 * Default version.
 * Params:
 *      pc = program counter
 *      offset = add to pc to get address of target
 * Returns:
 *      string representation of the memory address
 */
@trusted
const(char)* shortlabelDefault(uint pc, int offset)
{
    __gshared char[1 + ulong.sizeof * 3 + 1] buf;
    snprintf(buf.ptr, buf.length, "L%x", pc + offset);
    return buf.ptr;
}

/*****************************
 * Load word at code[c].
 */

uint word(ubyte[] code, uint c) @safe
{
    return code[c] + (code[c + 1] << 8);
}

/*****************************
 * Load dword at code[c].
 */

addr dword(ubyte[] code, uint c)
{
    return word(code, c) + (cast(addr) word(code, c + 2) << 16);
}

/*************************************
 */
@trusted
const(char)* wordtostring(uint w)
{
    __gshared char[1 + 3 + w.sizeof * 3 + 1 + 1] EA;

    snprintf(EA.ptr, EA.length, ((w < 10) ? "#%ld" : "#0x%lX"), w);
    return EA.ptr;
}

@trusted
const(char)* wordtostring(ulong w)
{
    __gshared char[1 + 3 + w.sizeof * 3 + 1 + 1] EA;

    snprintf(EA.ptr, EA.length, ((w < 10) ? "#%lld" : "#0x%llX"), w);
    return EA.ptr;
}

@trusted
const(char)* wordtostring2(uint w)
{
    __gshared char[1 + 3 + w.sizeof * 3 + 1 + 1] EA;

    snprintf(EA.ptr, EA.length, ((w < 10) ? "#%ld" : "#0x%lX"), w);
    return EA.ptr;
}

@trusted
const(char)* labeltostring(ulong w)
{
    __gshared char[2 + w.sizeof * 3 + 1] EA;

    auto n = snprintf(EA.ptr, EA.length, ((w < 10) ? "%lld" : "0x%llX"), w);
    assert(n <= EA.length);
    return EA.ptr;
}

@trusted
const(char)* indexString(uint reg)
{
    __gshared char[1 + 2 + 1 + 1] EA;

    auto n = snprintf(EA.ptr, EA.length, "[%s]", regString(1, reg));
    assert(n <= EA.length);
    return EA.ptr;
}


/***************************************
 */
pragma(inline, false)
const(char)* regString(uint sf, uint reg) { return sf ? xregs[reg] : wregs[reg]; }

pragma(inline, false)
const(char)* cregString(uint reg) { return cregs[reg]; }

immutable
{
    char*[32] xregs       = [ "x0","x1","x2","x3","x4","x5","x6","x7",
                              "x8","x9","x10","x11","x12","x13","x14","x15",
                              "x16","x17","x18","x19","x20","x21","x22","x23",
                              "x24","x25","x26","x27","x28","x29","x30","sp" ];
    char*[32] wregs       = [ "w0","w1","w2","w3","w4","w5","w6","w7",
                              "w8","w9","w10","w11","w12","w13","w14","w15",
                              "w16","w17","w18","w19","w20","w21","w22","w23",
                              "w24","w25","w26","w27","w28","w29","w30","wsp" ];
    char*[32] cregs       = [ "c0","c1","c2","c3","c4","c5","c6","c7",
                              "c8","c9","c10","c11","c12","c13","c14","c15",
                              "c16","c17","c18","c19","c20","c21","c22","c23",
                              "c24","c25","c26","c27","c28","c29","c30","csp" ];
}

/******************************
 * Extract fields from instruction in manner lifted from spec.
 * Params:
 *      opcode = opcode to extract field
 *      leftBit = leftmost bit number 31..0
 *      rightBit = rightmost bit number 31..0
 * Returns:
 *      extracted field
 */
uint field(uint opcode, uint end, uint start)
{
    assert(end < 32 && start < 32 && start <= end);
    //printf("%08x\n", (cast(uint)((cast(ulong)1 << (end + 1)) - 1) & opcode) >> start);
    return (cast(uint)((cast(ulong)1 << (end + 1)) - 1) & opcode) >> start;
}

unittest
{
    assert(field(0xFFFF_FFFF, 31, 31) == 1);
    assert(field(0xFFFF_FFFF, 31, 0) == 0xFFFF_FFFF);
    assert(field(0x0000_FFCF,  7, 4) == 0x0000_000C);
}

/************************************* Tests ***********************************/

unittest
{
    int line64 = __LINE__;
    string[41] cases64 =      // 64 bit code gen
    [
        "39 C0 00 20         ldrsb w0,[x1]",
        "39 40 00 20         ldrb  w0,[x1]",
        "79 C0 00 20         ldrsh w0,[x1]",
        "79 40 00 20         ldrh  w0,[x1]",
        "B9 40 00 20         ldr   w0,[x1]",

        "39 80 00 20         ldrsb x0,[x1]",
        "79 80 00 20         ldrsh x0,[x1]",
        "B9 80 00 20         ldrsw x0,[x1]",
        "F9 40 00 20         ldr   x0,[x1]",

        "B2 50 AF E0         mov  x0,#0xAD0",
        "EB 03 08 9F         cmp  x4,x3,lsl #2",
        "F1 00 08 7F         cmp  x3,#2",
        "91 00 0C 00         add  x0,x0,#3",
        "9A C1 28 02         asr  x2,x0,x1",
        "93 43 FC 01         asr  x1,x0,#3",
        "93 C1 0C 03         extr x3,x0,x1,#3",
        "13 81 0C 03         extr w3,w0,w1,#3",
        "D3 7D F0 01         lsl  x1,x0,#3",
        "9A C1 20 02         lsl  x2,x0,x1",
        "9A C1 24 02         lsr  x2,x0,x1",
        "D3 43 FC 01         lsr  x1,x0,#3",
        "D2 80 01 C0         mov  x0,#0xE",
        "92 80 01 A1         mov  x1,#0xFFFFFFFFFFFFFFF2",
        "D2 80 02 02         mov  x2,#0x10",
        "D2 80 01 C3         mov  x3,#0xE",
        "D2 80 07 04         mov  x4,#0x38",
        "9A C1 2C 02         ror  x2,x0,x1",
        "93 C0 0C 01         ror  x1,x0,#3",
        "93 C0 0C 03         ror  x3,x0,#3",
        "D6 5F 03 C0         ret",
        "D6 5F 0B FF         retaa",
        "D6 5F 0F FF         retab",
        "D6 5F 0B F3         retaasppc x19",
        "D6 5F 0F F4         retabsppc x20",
        "13 14 3C 24         sbfiz w4,w1,#0xC,#0x10",
        "13 00 1C 24         sxtb w4,w1",
        "13 00 3C 24         sxth w4,w1",
        "D2 9B DE 00         mov  x0,#0xDEF0",
        "F2 B3 57 80         movk x0,#0x9ABC,lsl #16",
        "F2 CA CF 00         movk x0,#0x5678,lsl #32",
        "F2 E2 46 80         movk x0,#0x1234,lsl #48",
    ];

    char[BUFMAX] buf;
    ubyte[BUFMAX] buf2;
    bool errors;

    void testcase(int line, string s, uint size)
    {
        //printf("testcase(line %d s: '%.*s'\n", cast(int)line, cast(int)s.length, s.ptr);
        auto codput = Output!ubyte(buf2[]);
        size_t j;
        ubyte[] code = hexToUbytes(codput, j, s);

        if (code.length != 4)
        {
            printf("Fail%d: %d hex code must be 4 bytes was %d\n",
                size, cast(int)(line + 2), cast(int)code.length);
            errors = true;
            return;
        }
        // Reverse code[]
        ubyte c = code[0]; code[0] = code[3]; code[3] = c;
              c = code[1]; code[1] = code[2]; code[2] = c;

        string expected = s[j .. $];

        addr m;
        auto length = calccodsize(code, 0, m, size);
        assert(length == 4);

        auto output = Output!char(buf[]);
        getopstring(&output.put, code, 0, length,
                size, 0, 0, null, null, null, null);
        auto result = output.peek();

        static bool compareEqual(const(char)[] result, const(char)[] expected)
        {
            size_t r, e;
            while (1)
            {
                while (r < result.length && (result[r] == ' ' || result[r] == '\t'))
                    ++r;
                while (e < expected.length && (expected[e] == ' ' || expected[e] == '\t'))
                    ++e;

                if ((r == result.length) != (e == expected.length))
                    return false;

                if (r == result.length)
                    return true;

                if (result[r] != expected[e])
                    return false;

                ++r;
                ++e;
            }
        }

        if (!compareEqual(result, expected))
        {
            printf("Fail%d: %d expected '%.*s' got '%.*s'\n",
                size, cast(int)(line + 2),
                cast(int)expected.length, expected.ptr, cast(int)result.length, result.ptr);
            errors = true;
        }
    }

    foreach (i; 0 .. cases64.length)
        testcase(line64, cases64[i], 64);

    assert(!errors);
}

version (unittest)
{

/**********************
 * Converts hex string prefix in `s` in test cases to ubyte[]
 * Params:
 *      output = where to write the ubyte's
 *      m = index of start of expected result
 *      s = ascii source
 * Returns:
 *      converted ubyte[]
 */
ubyte[] hexToUbytes(ref Output!ubyte output, out size_t m, string s)
{
    uint n = 0;
    ubyte v = 0;

  Loop:
    foreach (i, cc; s)
    {
        m = i;
        char c = cc;
        switch (c)
        {
            case ' ':
            case '\t':
            case '\v':
            case '\f':
            case '\r':
            case '\n':
                continue;                       // skip white space

            case 0:
            case 0x1A:
                printf("unterminated string constant at %d\n", cast(int)i);
                assert(0);

            case '0': .. case '9':
                c -= '0';
                break;

            case 'A': .. case 'F':
                c -= 'A' - 10;
                break;

            default:
                break Loop;
        }
        if (n & 1)
        {
            v = cast(ubyte)((v << 4) | c);
            output.put(v);
            v = 0;
        }
        else
            v = c;
        ++n;
    }
    if (n & 1)
    {
        printf("unterminated string constant\n");
        assert(0);
    }
    return output.peek;
}

struct Output(T)
{
  nothrow @nogc:

    T[] buf;
    size_t i;

    void put(T c)
    {
        buf[i] = c;
        ++i;
    }

    void initialize(T[] buf)
    {
        this.buf = buf;
        i = 0;
    }

    T[] peek()
    {
        return buf[0 .. i];
    }
}

}
