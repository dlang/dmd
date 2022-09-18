/*********************************************************
 * X86 disassembler. Can disassemble 16, 32, and 64 bit code. Includes
 * x87 FPU instructions and vector instructions.
 *
 * Copyright:   Copyright (C) 1982-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */

module dmd.backend.disasm86;

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
    assert(model == 16 || model == 32 || model == 64);
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
public
bool jmpTarget(ubyte[] code, ref addr c, out addr offset)
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

public
void getopstring(void delegate(char) nothrow @nogc put, ubyte[] code, uint c, addr siz,
        uint model, int nearptr, ubyte bObjectcode,
        const(char)*function(uint c, uint sz, uint offset) nothrow @nogc mem,
        const(char)*function(ubyte[] code, uint c, int sz) nothrow @nogc immed16,
        const(char)*function(uint c, uint offset, bool farflag, bool is16bit) nothrow @nogc labelcode,
        const(char)*function(uint pc, int offset) nothrow @nogc shortlabel
        )
{
    assert(model == 16 || model == 32 || model == 64);
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

enum AX = 0;

enum REX   =  0x40;          // REX prefix byte, OR'd with the following bits:
enum REX_W =  8;             // 0 = default operand size, 1 = 64 bit operand size
enum REX_R =  4;             // high bit of reg field of modregrm
enum REX_X =  2;             // high bit of sib index reg
enum REX_B =  1;             // high bit of rm field, sib base reg, or opcode reg

const(char)* REGNAME(uint rex, uint reg)
{
    return rex & REX_W ? rreg[reg] : (opsize ? wordreg[reg] : ereg[reg]);
}

const(char)* BREGNAME(uint rex, uint reg)
{
    return rex ? byteregrex[reg] : bytereg[reg];
}

/* Return !=0 if there is an SIB byte   */
bool issib(uint rm) { return (rm & 7) == 4 && (rm & 0xC0) != 0xC0; }


addr calccodsize(addr c, out addr pc)
{
    uint prefixsize = 0;
    {
        uint sz;
        do
        {
            sz = prefixbyte(c);
            c += sz;
            prefixsize += sz;
        } while (sz);
    }
    pc = c;            // to skip over prefix

    addr size;
    uint op,rm,mod;
    uint ins;
    ubyte rex = 0;

    op = code[c] & 0xFF;

    // if VEX prefix
    if (op == 0xC4 || op == 0xC5)
    {
        if (model == 64 || (code[c + 1] & 0xC0) == 0xC0)
        {
            if (op == 0xC4)     // 3 byte VEX
            {
                switch (code[c + 1] & 0x1F)
                {
                    case 1: // 0F
                        ins = inssize2[code[c + 3]] + 2;
                        break;
                    case 2: // 0F 38
                        ins = inssize2[0x38] + 1;
                        break;
                    case 3: // 0F 3A
                        ins = inssize2[0x3A] + 1;
                        break;
                    default:
                        printf("Invalid VEX at x%x\n", cast(int)c);
                        break;
                }
                c += 3;
            }
            else
            {
                ins = inssize2[code[c + 2]] + 1;
                c += 2;
            }
            size = ins & 7;
            goto Lmodrm;
        }
    }

    if (model == 64)
    {
        if (op == 0xF3 || op == 0xF2)
        {   if ((code[c + 1] & 0xF0) == REX)
            {
               c++;
               rex = code[c];
            }
        }
        else if ((op & 0xF0) == REX)
        {   rex = cast(ubyte)op;
            c++;
            op = code[c] & 0xFF;
        }
    }
    if ((op == 0xF2 || op == 0xF3) && code[c + 1] == 0x0F)
    {
        addr dummy;
        return prefixsize + (rex != 0) + 1 + calccodsize(c + 1, dummy);
    }
    ins = inssize[op];
    if (op == 0x0F)                     /* if 2 byte opcode             */
    {   c++;
        ins = inssize2[code[c]];
        if (ins & W)                    /* long-disp conditional jump   */
            return prefixsize + (opsize ? 4 : 6);
        if (opsize != defopsize && (code[c] == 0x38 || code[c] == 0x3A))
            c++;
    }
    size = ins & 7;
    if (opsize == true)
    { }
    else if (op != 0x0F)
        size = inssize32[op];
    if (rex)
    {   size++;
        if (rex & REX_W && (op & 0xF8) == 0xB8)
            size += 4;
    }
  Lmodrm:
    if (ins & M)                        /* if modregrm byte             */
    {
        rm = code[c+1] & 0xFF;
        mod = rm & 0xC0;
        if (adsize == 0 && model != 64)
        {   /* 16 bit addressing        */
            if (mod == 0x40)            /* 01: 8 bit displacement       */
                size++;
            else if (mod == 0x80 || (mod == 0 && (rm & 7) == 6))
                size +=2;
        }
        else
        {   /* 32 bit addressing        */
            if (issib(rm))
                size++;
            switch (mod)
            {   case 0:
                    if ((issib(rm) && (code[c+2] & 7) == 5) || (rm & 7) == 5)
                        size += 4;      /* disp32                       */
                    break;
                case 0x40:
                    size++;             /* disp8                        */
                    break;
                case 0x80:
                    size += 4;          /* disp32                       */
                    break;
                default:
                    break;
            }
        }
        if (op == 0xF6)                 /* special case                 */
        {       if ((rm & (7<<3)) == 0)
                        size++;
        }
        else if (op == 0xF7)
        {       if ((rm & (7<<3)) == 0)
                        size += opsize ? 2 : 4;
        }
    }
    else if (ins & T && (op & 0xFC) == 0xA0)
    {
        size = adsize ? 5 : 3;
        if (rex)
        {   size += 1;
            if (op == 0xA1 || op == 0xA3)
                size += 4;                      // 64 bit immediate value for MOV
        }
    }
    //printf("op = x%02x, size = x%lx, opsize = %d\n",op,size,opsize);
    return prefixsize + size;
}

/*****************************
 * Load byte at code[c].
 */

const(char)* immed8(uint c)
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

/*************************
 * Return # of bytes that EA consumes.
 */

addr EAbytes(uint c)
{
    addr a;
    uint modrgrm,mod,rm;

    a = 1;
    modrgrm = code[c + 1];
    mod = modrgrm >> 6;
    rm = modrgrm & 7;
    if (adsize == 0)            /* if 16 bit addressing         */
    {
        switch (mod)
        {   case 0:
                if (rm == 6)
                        a += 2;
                break;
            case 1:
                a += 1;
                break;
            case 2:
                a += 2;
                break;
            case 3:
                break;
            default:
                break;
        }
    }
    else
    {
        if (issib(modrgrm))
        {   ubyte sib;

            a += 1;
            sib = code[c + 2];
            switch (mod)
            {
                case 0:
                    if ((sib & 7) == 5)
                        a += 4;
                    break;
                case 1:
                    a += 1;
                    break;
                case 2:
                    a += 4;
                    break;
                default:
                    break;
            }
        }
        else
        {
            switch (mod)
            {   case 0:
                    if (rm == 5)
                        a += 4;
                    break;
                case 1:
                    a += 1;
                    break;
                case 2:
                    a += 4;
                    break;
                case 3:
                    break;
                default:
                    break;
            }
        }
    }
    return a;
}


/*************************
 * Params:
 *      vlen = 128: XMM, 256: YMM
 */


char *getEAxmm(ubyte rex, uint c)
{
    return getEAimpl(rex, c, 1, 128);
}

char *getEAxmmymm(ubyte rex, uint c, uint vlen)
{
    return getEAimpl(rex, c, 2, vlen);
}

const(char)* getEAvec(ubyte rex, uint c)
{
    const(char)* p;
    if ((code[c + 1] & 0xC0) == 0xC0)
    {
        uint rm = code[c + 1] & 7;
        if (rex & REX_B)
            rm |= 8;
        p = rex & REX_W ? rreg[rm] : ereg[rm];
    }
    else
        p = getEA(rex, c);
    return p;
}

char *getEA(ubyte rex, uint c)
{
    return getEAimpl(rex, c, 0, 128);
}

/*************************
 * Params:
 *      vlen = 128: XMM, 256: YMM
 */
char *getEAimpl(ubyte rex, uint c, int do_xmm, uint vlen)
{
    ubyte modrgrm,mod,reg,rm;
    uint opcode;
    const(char)* p;
    char[BUFMAX] EA = void;

    __gshared char[BUFMAX] EAb;
    __gshared const char*[6] ptr = ["","byte ptr ","word ptr ","dword ptr ",
                                 "fword ptr ", "qword ptr " ];
    int ptri;
    uint mm;            // != 0 if mmx opcode
    uint xmm;           // != 0 if xmm opcode
    uint r32;           // != 0 if r32

    char *displacement(addr w, const(char)* postfix)
    {
        const(char)* s = "".ptr;
        if (cast(short) w < 0)
        {
            w = -w;
            s = "-".ptr;
        }
        w &= 0xFFFF;
        sprintf(EAb.ptr,((w < 10) ? "%s%s%s%ld%s" : "%s%s%s0%lXh%s"),
                segover,ptr[ptri],s,w,postfix);

        segover = "".ptr;
        assert(strlen(EAb.ptr) < EAb.length);
        return EAb.ptr;
    }

    char *displacementFixup(addr c, uint sz, const(char)* postfix)
    {
        uint value = sz == 2 ? word(code, c) : dword(code, c);
        auto p = mem(c, sz, value);
        if (*p == '[')   // if just `[number]`
            return displacement(value, postfix); // don't use brackets
        sprintf(EAb.ptr,"%s%s%s%s",ptr[ptri],segover,p,postfix);
        return EAb.ptr;
    }

    mm = 0;
    xmm = (do_xmm == 2);
    r32 = 0;
    EA[0] = 0;
    EAb[0] = 0;
    opcode = code[c];
    if (opcode == 0x0F && do_xmm != 2)          /* if 2 byte opcode             */
    {   c++;
        opcode = 0x0F00 + code[c];
        //printf("opcode = %x\n", opcode);
        if (opcode == 0x0F2A)
            r32 = 1;
        if (do_xmm || inssize2[code[c]] & (Y & ~M))
            xmm = 1;
        else if (inssize2[code[c]] & (X & ~M))
            mm = 1;
        if (opsize != defopsize && (opcode == 0x0F38 || opcode == 0x0F3A))
            c++;
    }
    modrgrm = code[c + 1];
    switch (opcode)
    {
        case 0xFF:
            reg = (modrgrm >> 3) & 7;
            if (reg == 3 || reg == 5)   /* CALLF or JMPF        */
            {   ptri = opsize ? 3 : 4;
                break;
            }
            goto case;

        case 0x81:
        case 0x83:
        case 0xC7:
        case 0xD1:
        case 0xD3:
        case 0xF7:
            ptri = opsize ? 2 : 3;
            if (rex & REX_W)
                ptri = 5;               // qword ptr
            break;
        case 0x80:
        case 0xC6:
        case 0xD0:
        case 0xD2:
        case 0xF6:
        case 0xFE:
            ptri = 1;
            break;
        case 0x0FB6:
        case 0x0FBE:
            ptri = 1;
            break;
        case 0x0FB7:
        case 0x0FBF:
            ptri = 2;
            break;
        default:
            ptri = 0;
            if (opcode >= 0x0F90 && opcode <= 0x0F9F)
                ptri = 1;
            break;
    }
    if (do_xmm == 2)
        ptri = 0;

    mod = modrgrm >> 6;
    rm = modrgrm & 7;
    if (adsize == 0 && model != 64)          // if 16 bit addressing
    {
        __gshared const char*[8] rmstr =
        [ "[BX+SI]","[BX+DI]","[BP+SI]","[BP+DI]","[SI]","[DI]","[BP]","[BX]" ];

        switch (mod)
        {   case 0:
                if (rm == 6)
                {
                    strcpy(EA.ptr, ptr[ptri]);
                    strcat(EA.ptr, segover);
                    strcat(EA.ptr, mem(c + 2, 2, word(code, c + 2)));
                    p = EA.ptr;
                    break;
                }
                p = rmstr[rm];
                break;
            case 1:
                return displacement(cast(byte) code[c + 2], rmstr[rm]);
            case 2:
                return displacementFixup(c + 2, 2, rmstr[rm]);

            case 3:
                switch (opcode) {
                case 0x8c:
                case 0x8e:
                    p = wordreg[rm];
                    break;
                case 0x0F6E:
                case 0x0F7E:
                    p = mm ? mmreg[rm] : ereg[rm];
                    break;
                case 0x0FAC:
                case 0x0FA4:
                    opcode |= 1;
                    goto default;
                default:
                    p = (opcode & 1 || r32) ? ereg[rm] + opsize : bytereg[rm];
                    if (mm)
                        p = mmreg[rm];
                    else if (xmm)
                        p = vlen == 128 ? xmmreg[rm] : ymmreg[rm];
                    break;
                }
                break;
            default:
                assert(0);
        }
    }
    else                                        /* 32 bit addressing    */
    {   ubyte sib;
        char[5 + 5 + 2 + 1] rbuf;

        const(char*)* preg = &ereg[0];          // 32 bit address size
        if (model == 64 && adsize)
            preg = rreg.ptr;                    // 64 bit address size

        if (issib(modrgrm))
        {          /* [ EAX *2 ][ EAX ] */
            char[1 +4  +2 +2 +4 +1 +1] base;
            __gshared const char[3][4] scale = [ "","*2","*4","*8" ];

            sib = code[c + 2];

            uint sib_index = (sib >> 3) & 7;
            if (rex & REX_X)
                sib_index |= 8;

            uint sib_base = (sib & 7);
            if (rex & REX_B)
                sib_base |= 8;

            if (sib_index == 4)                 // REX_X is not ignored
                sprintf(base.ptr,"[%s]",preg[sib_base]);
            else
                sprintf(base.ptr,"[%s%s][%s]",
                    preg[sib_index], scale[sib >> 6].ptr, preg[sib_base]);
            strcpy(rbuf.ptr, base.ptr);
            switch (mod)
            {   case 0:
                    if ((sib_base & 7) == 5)
                    {
                        p = mem(c + 3, 4, dword(code, c + 3));
                        if (sib_index == 4)
                          sprintf(EAb.ptr,"%s%s%s",ptr[ptri],segover,p);
                        else
                          sprintf(EAb.ptr,"%s%s%s[%s%s]",ptr[ptri],segover,p,
                            preg[sib_index], scale[sib >> 6].ptr);
                        return EAb.ptr;
                    }
                    p = rbuf.ptr;       // no displacement
                    break;
                case 1:
                    return displacement(cast(byte)code[c + 3], rbuf.ptr);
                case 2:
                    return displacementFixup(c + 3, 4, rbuf.ptr);
                default:
                    assert(0);
            }
        }
        else
        {
            sprintf(rbuf.ptr,"[%s]", preg[(rex & REX_B) ? 8|rm : rm]);
            switch (mod)
            {   case 0:
                    if (rm == 5)                // ignore REX_B
                    {
                        p = mem(c + 2, 4, dword(code, c + 2));
                        if (model == 64)
                            sprintf(EAb.ptr,"%s%s%s[RIP]",ptr[ptri],segover,p);
                        else
                            sprintf(EAb.ptr,"%s%s%s",ptr[ptri],segover,p);
                        return EAb.ptr;
                    }
                    else
                    {   p = rbuf.ptr;
                        sprintf(EA.ptr,"%s%s",ptr[ptri],p);
                    }
                    p = EA.ptr;
                    break;
                case 1:
                    return displacement(cast(byte)code[c + 2], rbuf.ptr);
                case 2:
                    return displacementFixup(c + 2, 4, rbuf.ptr);
                case 3:
                    if (rex & REX_B)
                        rm |= 8;
                    switch (opcode)
                    {   case 0x8C:
                        case 0x8E:
                        case 0x0FB7:            /* MOVZX        */
                        case 0x0FBF:            /* MOVSX        */
                            p = wordreg[rm];
                            break;
                        case 0x0FA4:            /* SHLD         */
                        case 0x0FA5:            /* SHLD         */
                        case 0x0FAC:            /* SHRD         */
                        case 0x0FAD:            /* SHRD         */
                            p = ereg[rm] + opsize;
                            if (rex & REX_W)
                                p = rreg[rm];
                            break;
                        case 0x0F6E:
                        case 0x0F7E:
                        case 0x0FC5:
                        case 0x0FC4:
                            if (mm)
                                p = mmreg[rm];
                            else if (xmm)
                                p = vlen == 128 ? xmmreg[rm] : ymmreg[rm];
                            else if (rex & REX_W)
                                p = rreg[rm];
                            else
                                p = ereg[rm];
                            break;
                        default:
                            if (opcode >= 0x0F90 && opcode <= 0x0F9F)
                                p = rex ? byteregrex[rm] : bytereg[rm];
                            else if (mm)
                                p = mmreg[rm];
                            else if (xmm)
                                p = vlen == 128 ? xmmreg[rm] : ymmreg[rm];
                            else
                            {
                                if (opcode & 1 || r32)
                                {
                                    p = ereg[rm] + opsize;
                                    if (opsize && rm >= 8)
                                        p = wordreg[rm];
                                }
                                else
                                    p = (rex ? byteregrex[rm] : bytereg[rm]);
                                if (rex & REX_W)
                                    p = (opcode & 1 || r32) ? rreg[rm] : byteregrex[rm];
                            }
                            break;
                    }
                    break;
                default:
                    assert(0);
            }
        }
    }
    sprintf(EAb.ptr,"%s%s",segover,p);
    segover = "".ptr;
    assert(strlen(EA.ptr) < EA.length);
    assert(strlen(EAb.ptr) < EAb.length);
    return EAb.ptr;
}


/********************************
 * Determine if the byte at code[c] is a prefix instruction.
 * Params:
 *      put = if not null, store hex code here
 * Returns:
 *      number of prefix bytes
 */
int prefixbyte(uint c)
{
    void printHex(uint prefix)
    {
        if (bObjectcode)
        {
            char[3 + 1] tmp;
            sprintf(tmp.ptr, "%02X ", prefix);
            puts(tmp.ptr);
        }
    }

    if (c + 1 < code.length)
    {
        const prefix = code[c];         // this may be a prefix byte

        /* If segment override  */
        char s;
        switch (prefix)
        {
            case 0x26:  s = 'E'; goto L1; // ES
            case 0x2E:  s = 'C'; goto L1; // CS
            case 0x36:  s = 'S'; goto L1; // SS
            case 0x3E:  s = 'D'; goto L1; // DS
            case 0x64:  s = 'F'; goto L1; // FS
            case 0x65:  s = 'G'; goto L1; // GS
            L1:
            {
                /* prefix is only a prefix if it is followed by the right opcode
                 */
                ubyte op = code[c + 1];
                if (model == 64 && (op & 0xF0) == REX)
                {
                    if (c + 2 >= code.length)
                        return 0;       // a label splits REX off from its instruction
                    // skip over REX to get the opcode
                    op = code[c + 2];
                }
                if (inssize[op] & M || (op >= 0xA0 && op <= 0xA3))
                {
                    __gshared char[4] buf;
                    buf[0] = s;
                    buf[1] = 'S';
                    buf[2] = ':';
                    buf[3] = 0;
                    segover = &buf[0];
                    printHex(prefix);
                    return 1;
                }
                break;
            }

            case 0x66:       // operand size
                opsize ^= true;
                printHex(prefix);
                return 1;

            case 0x67:       // address size
                adsize ^= 1;
                printHex(prefix);
                return 1;

            case 0x9B:       // FWAIT
                if (0 && code[c + 1] >= 0xD8 && code[c + 1] <= 0xDF)
                {
                    fwait = 1;
                    printHex(prefix);
                    printHex(code[c + 1]);
                    return 2;
                }
                break;

            default:
                break;
        }
    }
    return 0;
}

/**********************************
 * Decode VEX instructions.
 * Store in buffer the 'stringized' instruction indexed by c.
 * Params:
 *      put = where to store output
 *      c = index into code[] of the first VEX prefix byte
 *      siz = number of bytes in instruction
 *      p0 = hex bytes dump
 */

void getVEXstring(addr c, addr siz, char *p0)
{
    /* Parse VEX prefix,
     * fill in the following variables,
     * and point c at opcode byte
     */
    ubyte rex = REX;
    ubyte vreg;
    uint vlen;
    uint m_mmmm;                // leading opcode byte
    ubyte opext;                // opcode extension
    {
        __gshared const ubyte[4] opexts = [ 0, 0x66, 0xF3, 0xF2 ];
        ubyte v1 = code[c + 1];
        if (!(v1 & 0x80))
            rex |= REX_R;
        if (code[c] == 0xC5)
        {
            vreg = ~(v1 >> 3) & 0xF;
            vlen = v1 & 4 ? 256 : 128;
            opext = opexts[v1 & 3];
            m_mmmm = 0x0F;
            c += 2;
        }
        else // 0xC4
        {
            if (!(v1 & 0x40))
                rex |= REX_X;
            if (!(v1 & 0x20))
                rex |= REX_B;
            switch (v1 & 0x1F)
            {
                case 1: m_mmmm = 0x0F; break;
                case 2: m_mmmm = 0x0F38; break;
                case 3: m_mmmm = 0x0F3A; break;
                default: m_mmmm = 0; break;
            }
            ubyte v2 = code[c + 2];
            if (v2 & 0x80)
                rex |= REX_W;
            vreg = ~(v2 >> 3) & 0xF;
            vlen = v2 & 4 ? 256 : 128;
            opext = opexts[v2 & 3];
            c += 3;
        }
    }

    uint opcode,reg;
    char[5] p1buf;
    sprintf(p1buf.ptr,"0x%02x",code[c]);
    const(char)* p1 = p1buf.ptr;
    const(char)* p2 = "".ptr;
    const(char)* p3 = "".ptr;
    const(char)* p4 = "".ptr;
    const(char)* p5 = "".ptr;

    opcode = code[c];

    reg = 13;
    if (inssize2[opcode] & M)   // if modregrm byte
    {   reg = (code[c + 1] >> 3) & 7;
        if (rex & REX_R)
            reg |= 8;
    }

    if (m_mmmm == 0x0F && opext == 0)
    {

        switch (opcode)
        {
            case 0x10: p1 = "vmovups"; goto Lxmm_eax;
            case 0x11: p1 = "vmovups"; goto Leax_xmm;
            case 0x12: p1 = ((code[c + 1] & 0xC0) == 0xC0) ? "vmovhlps" : "vmovlps"; goto L3op;
            case 0x13: p1 = "vmovlps"; goto Leax_xmm;
            case 0x14: p1 = "vunpcklps"; goto L3op;
            case 0x15: p1 = "vunpckhps"; goto L3op;
            case 0x16: p1 = ((code[c + 1] & 0xC0) == 0xC0) ? "vmovlhps" : "vmovhps"; goto L3op;
            case 0x17: p1 = "vmovhps"; goto Leax_xmm;
            case 0x28: p1 = "vmovaps"; goto Lxmm_eax;
            case 0x29: p1 = "vmovaps"; goto Leax_xmm;
            case 0x2B: p1 = "vmovntps"; goto Leax_xmm;
            case 0x2E: p1 = "vucomiss"; goto Lxmm_eax;
            case 0x2F: p1 = "vcomiss"; goto Lxmm_eax;
            case 0x50: p1 = "vmovmskps"; goto Lrxmm;
            case 0x51: p1 = "vsqrtp2"; goto Lxmm_eax;
            case 0x53: p1 = "vrcpps"; goto Lxmm_eax;
            case 0x54: p1 = "vandps"; goto L3op;
            case 0x55: p1 = "vandnps"; goto L3op;
            case 0x56: p1 = "vorps"; goto L3op;
            case 0x57: p1 = "vxorps"; goto L3op;
            case 0x58: p1 = "vaddps"; goto L3op;
            case 0x5A: p1 = "vcvtps2pd"; goto Lymmea;
            case 0x5B: p1 = "vcvtdq2ps"; goto Lxmm_eax;
            case 0x5C: p1 = "vsubps"; goto L3op;
            case 0x5D: p1 = "vminps"; goto L3op;
            case 0x5F: p1 = "vmaxps"; goto L3op;
            case 0x77: p1 = vlen == 128 ? "vzeroupper" : "vzeroall"; goto Ldone;
            case 0xC2: p1 = "vcmpps"; goto L4op;
            case 0xC6: p1 = "vshufps"; goto L4op;
            case 0xAE:
                if ((code[c + 1] & 0xC0) != 0xC0)
                {
                    __gshared const char[9][8] grp15 =
                    [   "v00","v01","vldmxcsr","vstmxcsr","v04","v05","v06","v07" ];
                    p1 = grp15[reg].ptr;
                    p2 = getEA(rex, c);
                    goto Ldone;
                }
                goto Ldone;

            default:
                printf("0F 00: %02x\n", opcode);
                break;
        }
    }
    else if (m_mmmm == 0x0F && opext == 0x66)
    {

        switch (opcode)
        {
            case 0x10: p1 = "vmovupd"; goto Lxmm_eax;
            case 0x11: p1 = "vmovupd"; goto Leax_xmm;
            case 0x14: p1 = "vunpcklpd"; goto L3op;
            case 0x15: p1 = "vunpckhpd"; goto L3op;
            case 0x16: p1 = "vmovhpd"; goto L3op;
            case 0x17: p1 = "vmovhpd"; goto Leax_xmm;
            case 0x28: p1 = "vmovapd"; goto Lxmm_eax;
            case 0x29: p1 = "vmovapd"; goto Leax_xmm;
            case 0x2B: p1 = "vmovntpd"; goto Leax_xmm;
            case 0x2E: p1 = "vucomisd"; goto Lxmm_eax;
            case 0x2F: p1 = "vcomisd"; goto Lxmm_eax;
            case 0x50: p1 = "vmovmskpd"; goto Lrxmm;
            case 0x51: p1 = "vsqrtpd"; goto Lxmm_eax;
            case 0x54: p1 = "vandpd"; goto L3op;
            case 0x55: p1 = "vandnpd"; goto L3op;
            case 0x56: p1 = "vorpd"; goto L3op;
            case 0x57: p1 = "vxorpd"; goto L3op;
            case 0x58: p1 = "vaddpd"; goto L3op;
            case 0x5A: p1 = "vcvtpd2ps"; goto L_xmmea;
            case 0x5B: p1 = "vcvtps2dq"; goto Lxmm_eax;
            case 0x5C: p1 = "vsubpd"; goto L3op;
            case 0x5D: p1 = "vminpd"; goto L3op;
            case 0x5F: p1 = "vmaxpd"; goto L3op;
            case 0x60: p1 = "vunpcklbw"; goto L3op;
            case 0x61: p1 = "vunpcklwd"; goto L3op;
            case 0x62: p1 = "vunpckldq"; goto L3op;
            case 0x63: p1 = "vpacksswb"; goto L3op;
            case 0x64: p1 = "vpcmpgtb"; goto L3op;
            case 0x65: p1 = "vpcmpgtw"; goto L3op;
            case 0x66: p1 = "vpcmpgtd"; goto L3op;
            case 0x67: p1 = "vpackuswb"; goto L3op;
            case 0x68: p1 = "vunpckhbw"; goto L3op;
            case 0x69: p1 = "vunpckhwd"; goto L3op;
            case 0x6A: p1 = "vunpckhdq"; goto L3op;
            case 0x6B: p1 = "vpackssdw"; goto L3op;
            case 0x6C: p1 = "vunpcklqdq"; goto L3op;
            case 0x6D: p1 = "vunpckhqdq"; goto L3op;
            case 0x6E: p1 = rex & REX_W ? "vmovq" : "vmovd"; goto Lxmm_ea;
            case 0x6F: p1 = "vmovdqa"; goto Lxmm_eax;
            case 0x70: p1 = "vpshufd"; goto Lymmxeaimm;
            case 0x71:
            {   __gshared const char*[8] reg71 =
                [ null, null, "vpsrlw", null, "vpsraw", null, "vpslw", null ];
                const char *p = reg71[reg];
                if (!p)
                    goto Ldefault;
                p1 = p;
                goto Leax_xmm_imm;
            }
            case 0x72:
            {   __gshared const char*[8] reg72 =
                [ null, null, "vpsrld", null, "vpsrad", null, "vpslld", null ];
                const char *p = reg72[reg];
                if (!p)
                    goto Ldefault;
                p1 = p;
                goto Leax_xmm_imm;
            }
            case 0x73:
            {   __gshared const char*[8] reg73 =
                [ null, null, "vpsrlq", "vpsrldq", null, null, "vpsllq", "vpslldq" ];
                const char *p = reg73[reg];
                if (!p)
                    goto Ldefault;
                p1 = p;
                goto Leax_xmm_imm;
            }
            case 0x74: p1 = "vpcmpeqb"; goto L3op;
            case 0x75: p1 = "vpcmpeqw"; goto L3op;
            case 0x76: p1 = "vpcmpeqd"; goto L3op;
            case 0x7C: p1 = "vhaddpd"; goto L3op;
            case 0x7E: p1 = rex & REX_W ? "vmovq" : "vmovd"; goto Lea_xmm;
            case 0x7F: p1 = "vmovdqa"; goto Leax_xmm;
            case 0xC2: p1 = "vcmppd"; goto L4op;
            case 0xC4: p1 = "vpinsrw"; goto Lymm_ymm_ea_imm;
            case 0xC5: p1 = "vpextrw"; goto Lea_xmm_imm;
            case 0xC6: p1 = "vshufpd"; goto L4op;
            case 0xD0: p1 = "vaddsubpd"; goto L3op;
            case 0xD1: p1 = "vpsrlw"; goto L3op;
            case 0xD2: p1 = "vpsrld"; goto L3op;
            case 0xD3: p1 = "vpsrlq"; goto L3op;
            case 0xD4: p1 = "vpaddq"; goto L3op;
            case 0xD5: p1 = "vpmulld"; goto L3op;
            case 0xD7: p1 = "vpmovmskb"; goto Lrxmm;
            case 0xD8: p1 = "vpsubusb"; goto L3op;
            case 0xD9: p1 = "vpsubusw"; goto L3op;
            case 0xDA: p1 = "vpminub"; goto L3op;
            case 0xDB: p1 = "vpand"; goto L3op;
            case 0xDC: p1 = "vpaddusb"; goto L3op;
            case 0xDD: p1 = "vpaddusw"; goto L3op;
            case 0xDE: p1 = "vpmaxub"; goto L3op;
            case 0xDF: p1 = "vpandn"; goto L3op;
            case 0xE0: p1 = "vpavgb"; goto L3op;
            case 0xE1: p1 = "vpsraw"; goto L3op;
            case 0xE2: p1 = "vpsrad"; goto L3op;
            case 0xE3: p1 = "vpavgw"; goto L3op;
            case 0xE4: p1 = "vpmulhuw"; goto L3op;
            case 0xE5: p1 = "vpmulhw"; goto L3op;
            case 0xE6: p1 = "vcvttpd2dq"; goto L_xmmea;
            case 0x12: p1 = "vmovlpd"; goto L3op;
            case 0x13: p1 = "vmovlpd"; goto Leax_xmm;
            case 0xE7: p1 = "vmovntdq"; goto Leax_xmm;
            case 0xE8: p1 = "vpsubsb"; goto L3op;
            case 0xE9: p1 = "vpsubsw"; goto L3op;
            case 0xEA: p1 = "vpminsw"; goto L3op;
            case 0xEB: p1 = "vpor"; goto L3op;
            case 0xEC: p1 = "vpaddsb"; goto L3op;
            case 0xED: p1 = "vpaddsw"; goto L3op;
            case 0xEE: p1 = "vpmaxsw"; goto L3op;
            case 0xEF: p1 = "vpxor"; goto L3op;
            case 0xF1: p1 = "vpsllw"; goto L3op;
            case 0xF2: p1 = "vpslld"; goto L3op;
            case 0xF3: p1 = "vpsllq"; goto L3op;
            case 0xF4: p1 = "vpmuludq"; goto L3op;
            case 0xF5: p1 = "vpmaddwd"; goto L3op;
            case 0xF6: p1 = "vpsadbw"; goto L3op;
            case 0xF7: p1 = "vmaskmovdqu"; goto Lxmm_eax;
            case 0xF8: p1 = "vpsubb"; goto L3op;
            case 0xF9: p1 = "vpsubw"; goto L3op;
            case 0xFA: p1 = "vpsubd"; goto L3op;
            case 0xFB: p1 = "vpsubq"; goto L3op;
            case 0xFC: p1 = "vpaddb"; goto L3op;
            case 0xFD: p1 = "vpaddw"; goto L3op;
            case 0xFE: p1 = "vpaddd"; goto L3op;

            default:
            Ldefault:
                printf("0F 66: %02x\n", opcode);
                break;
        }
    }
    else if (m_mmmm == 0x0F && opext == 0xF2)
    {

        switch (opcode)
        {
            case 0x10: p1 = "vmovsd"; goto L3op;
            case 0x11: p1 = "vmovsd"; goto Leax_xmm;
            case 0x12: p1 = "vmovddup"; goto Lxmm_eax;
            case 0x2A: p1 = "vcvtsi2sd"; goto Lxmmxmmea;
            case 0x2C: p1 = "vcvttsd2si"; goto Lregeax;
            case 0x2D: p1 = "vcvtsd2si"; goto Lregeax;
            case 0x51: p1 = "vsqrtsd"; goto L3op;
            case 0x58: p1 = "vaddsd"; goto L3op;
            case 0x5A: p1 = "vcvtsd2ss"; goto L3op;
            case 0x5C: p1 = "vsubsd"; goto L3op;
            case 0x5D: p1 = "vminsd"; goto L3op;
            case 0x5F: p1 = "vmaxsd"; goto L3op;
            case 0x7C: p1 = "vhaddps"; goto L3op;
            case 0xC2: p1 = "vcmpsd"; goto L4op;
            case 0xD0: p1 = "vaddsubps"; goto L3op;
            case 0xE6: p1 = "vcvtpd2dq"; goto L_xmmea;
            case 0xF0: p1 = "vlddqu"; goto Lxmm_eax;
            case 0x70: p1 = "vpshuflw"; goto Lymmxeaimm;

            default:
                printf("0F F2: %02x\n", opcode);
                break;
        }
    }
    else if (m_mmmm == 0x0F && opext == 0xF3)
    {
        switch (opcode)
        {
            case 0x10: p1 = "vmovss"; goto L3op;
            case 0x11: p1 = "vmovss"; goto Leax_xmm;
            case 0x12: p1 = "vmovsldup"; goto Lxmm_eax;
            case 0x16: p1 = "vmovshdup"; goto Lxmm_eax;
            case 0x2A: p1 = "vcvtsi2ss"; goto Lxmmxmmea;
            case 0x2C: p1 = "vcvttss2si"; goto Lregeax;
            case 0x2D: p1 = "vcvtss2si"; goto Lregeax;
            case 0x51: p1 = "vsqrtss"; goto L3op;
            case 0x53: p1 = "vrcpss"; goto L3op;
            case 0x58: p1 = "vaddss"; goto L3op;
            case 0x5B: p1 = "vcvttps2dq"; goto Lxmm_eax;
            case 0x5C: p1 = "vsubss"; goto L3op;
            case 0x5D: p1 = "vminss"; goto L3op;
            case 0x5F: p1 = "vmaxss"; goto L3op;
            case 0x6F: p1 = "vmovdqu"; goto Lxmm_eax;
            case 0x7F: p1 = "vmovdqu"; goto Leax_xmm;
            case 0xC2: p1 = "vcmpss"; goto L4op;
            case 0xE6: p1 = "vcvtdq2pd"; goto Lymmea;
            case 0x70: p1 = "vpshufhw"; goto Lymmxeaimm;
            default:
                printf("0F F3: %02x\n", opcode);
                break;
        }
    }
    else if (m_mmmm == 0x0F38 && opext == 0x66)
    {

        switch (opcode)
        {
            case 0x00: p1 = "vpshufb"; goto L3op;
            case 0x01: p1 = "vphaddw"; goto L3op;
            case 0x02: p1 = "vphaddd"; goto L3op;
            case 0x03: p1 = "vphaddsw"; goto L3op;
            case 0x04: p1 = "vpmaddubsw"; goto L3op;
            case 0x05: p1 = "vphsubw"; goto L3op;
            case 0x06: p1 = "vphsubd"; goto L3op;
            case 0x07: p1 = "vphsubsw"; goto L3op;
            case 0x08: p1 = "vpsignb"; goto L3op;
            case 0x09: p1 = "vpsignw"; goto L3op;
            case 0x0A: p1 = "vpsignd"; goto L3op;
            case 0x0B: p1 = "vpmulhrsw"; goto L3op;
            case 0x0C: p1 = "vpermilps"; goto L3op;
            case 0x0D: p1 = "vpermilpd"; goto L3op;
            case 0x13: p1 = "vcvtph2ps"; goto Lxmm_eax;
            case 0x17: p1 = "vptest"; goto L3op;
            case 0x18: p1 = "vbroadcastss"; goto Lymmea;
            case 0x19: p1 = "vbroadcastsd"; goto Lymmea;
            case 0x1A: p1 = "vbroadcastf128"; goto Lymmea;
            case 0x1C: p1 = "vpabsb"; goto Lxmm_eax;
            case 0x1D: p1 = "vpabsw"; goto Lxmm_eax;
            case 0x1E: p1 = "vpabsd"; goto Lxmm_eax;
            case 0x20: p1 = "vpmovsxbw"; goto Lxmm_eax;
            case 0x21: p1 = "vpmovsxbd"; goto Lxmm_eax;
            case 0x22: p1 = "vpmovsxbq"; goto Lxmm_eax;
            case 0x23: p1 = "vpmovsxwd"; goto Lxmm_eax;
            case 0x24: p1 = "vpmovsxwq"; goto Lxmm_eax;
            case 0x25: p1 = "vpmovsxdq"; goto Lxmm_eax;
            case 0x28: p1 = "vpmuldq"; goto L3op;
            case 0x29: p1 = "vpcmpeqq"; goto L3op;
            case 0x2A: p1 = "vmovntdqa"; goto Lxmm_eax;
            case 0x2C: p1 = "vmaskmovps"; goto L3op;
            case 0x2B: p1 = "vpackusdw"; goto L3op;
            case 0x2D: p1 = "vmaskmovpd"; goto L3op;
            case 0x2E: p1 = "vmaskmovps"; goto L3opr;
            case 0x2F: p1 = "vmaskmovpd"; goto L3opr;
            case 0x30: p1 = "vpmovzxbw"; goto Lxmm_eax;
            case 0x31: p1 = "vpmovzxbd"; goto Lxmm_eax;
            case 0x32: p1 = "vpmovzxbq"; goto Lxmm_eax;
            case 0x33: p1 = "vpmovzxwd"; goto Lxmm_eax;
            case 0x34: p1 = "vpmovzxwq"; goto Lxmm_eax;
            case 0x35: p1 = "vpmovzxdq"; goto Lxmm_eax;
            case 0x37: p1 = "vpcmpgtq"; goto L3op;
            case 0x38: p1 = "vpminsb"; goto L3op;
            case 0x39: p1 = "vpminsd"; goto L3op;
            case 0x3A: p1 = "vpminuw"; goto L3op;
            case 0x3B: p1 = "vpminud"; goto L3op;
            case 0x3C: p1 = "vpmaxsb"; goto L3op;
            case 0x3D: p1 = "vpmaxsd"; goto L3op;
            case 0x3E: p1 = "vpmaxuw"; goto L3op;
            case 0x3F: p1 = "vpmaxud"; goto L3op;
            case 0x40: p1 = "vpmulhd"; goto L3op;
            case 0x41: p1 = "vpminposuw"; goto Lxmm_eax;
            case 0x96: p1 = rex & REX_W ? "vfmaddsub132pd" : "vfmaddsub132ps"; goto L3op;
            case 0x97: p1 = rex & REX_W ? "vfmaddsub132pd" : "vfmaddsub132ps"; goto L3op;
            case 0x98: p1 = rex & REX_W ? "vfmadd132pd" : "vfmadd132ps"; goto L3op;
            case 0x99: p1 = rex & REX_W ? "vfmadd132sd" : "vfmadd132ss"; goto L3op;
            case 0x9A: p1 = rex & REX_W ? "vfmsub132pd" : "vfmsub132ps"; goto L3op;
            case 0x9B: p1 = rex & REX_W ? "vfmsub132sd" : "vfmsub132ss"; goto L3op;
            case 0xA6: p1 = rex & REX_W ? "vfmaddsub213pd" : "vfmaddsub213ps"; goto L3op;
            case 0xA7: p1 = rex & REX_W ? "vfmaddsub213pd" : "vfmaddsub213ps"; goto L3op;
            case 0xA8: p1 = rex & REX_W ? "vfmadd213pd" : "vfmadd213ps"; goto L3op;
            case 0xA9: p1 = rex & REX_W ? "vfmadd213sd" : "vfmadd213ss"; goto L3op;
            case 0xAA: p1 = rex & REX_W ? "vfmsub213pd" : "vfmsub213ps"; goto L3op;
            case 0xAB: p1 = rex & REX_W ? "vfmsub213sd" : "vfmsub213ss"; goto L3op;
            case 0xB6: p1 = rex & REX_W ? "vfmaddsub231pd" : "vfmaddsub231ps"; goto L3op;
            case 0xB7: p1 = rex & REX_W ? "vfmaddsub231pd" : "vfmaddsub231ps"; goto L3op;
            case 0xB8: p1 = rex & REX_W ? "vfmadd231pd" : "vfmadd231ps"; goto L3op;
            case 0xB9: p1 = rex & REX_W ? "vfmadd231sd" : "vfmadd231ss"; goto L3op;
            case 0xBA: p1 = rex & REX_W ? "vfmsub231pd" : "vfmsub231ps"; goto L3op;
            case 0xBB: p1 = rex & REX_W ? "vfmsub231sd" : "vfmsub231ss"; goto L3op;
            case 0xDB: p1 = "vaesenc"; goto Lxmm_eax;
            case 0xDC: p1 = "vaesenc"; goto L3op;
            case 0xDD: p1 = "vaesenclast"; goto L3op;
            case 0xDE: p1 = "vaesdec"; goto L3op;
            case 0xDF: p1 = "vaesdeclast"; goto L3op;

            default:
                printf("0F38 66: %02x\n", opcode);
                break;
        }
    }
    else if (m_mmmm == 0x0F3A && opext == 0x66)
    {
        switch (opcode)
        {
            case 0x04: p1 = "vpermilps"; goto Lymmxeaimm;
            case 0x06: p1 = "vperm2f128"; goto L4op;
            case 0x05: p1 = "vpermilpd"; goto Lymmxeaimm;
            case 0x08: p1 = "vroundps"; goto Leax_xmm_imm;
            case 0x09: p1 = "vroundpd"; goto Leax_xmm_imm;
            case 0x0A: p1 = "vroundss"; goto L4op;
            case 0x0B: p1 = "vroundsd"; goto L4op;
            case 0x0C: p1 = "vblendps"; goto L4op;
            case 0x0D: p1 = "vblendpd"; goto L4op;
            case 0x0E: p1 = "vpblendw"; goto L4op;
            case 0x0F: p1 = "vpalignr"; goto L4op;
            case 0x14: p1 = "vpextrb"; goto Lea_xmm_imm;
            case 0x15: p1 = "vpextrw"; goto Lea_xmm_imm;
            case 0x16: p1 = rex & REX_W ? "vpextrq" : "vpextrd"; goto Lea_xmm_imm;
            case 0x17: p1 = "vextractps"; goto Lea_xmm_imm;
            case 0x18: p1 = "vinsertf128"; goto Lymm_ymm_eax_imm;
            case 0x19: p1 = "vextractf128"; goto Lxeaymmimm;
            case 0x1D: p1 = "vcvtps2ph"; goto Leax_xmm_imm;
            case 0x20: p1 = "vpinsrb"; goto Lymm_ymm_ea_imm;
            case 0x21: p1 = "vinsertps"; goto Lymm_ymm_eax_imm;
            case 0x22: p1 = rex & REX_W ? "vpinsrq" : "vpinsrd"; goto Lymm_ymm_ea_imm;
            case 0x40: p1 = "vdpps"; goto L4op;
            case 0x41: p1 = "vdppd"; goto L4op;
            case 0x42: p1 = "vmpsadbw"; goto L4op;
            case 0x44: p1 = "vpclmulqdq"; goto L4op;
            case 0x4A: p1 = "vblendvps"; goto L4op;
            case 0x4B: p1 = "vblendvpd"; goto L4op;
            case 0x4C: p1 = "vpblendvb"; goto L4op;
            case 0x60: p1 = "vpcmpestrm"; goto L4op;
            case 0x61: p1 = "vpcmpestri"; goto L4op;
            case 0x62: p1 = "vpcmpistrm"; goto L4op;
            case 0x63: p1 = "vpcmpistri"; goto L4op;
            case 0xDF: p1 = "vaeskeygenassist"; goto Lxmm_eax_imm;

            default:
                printf("0F3A 66: %02x\n", opcode);
                break;
        }
    }
    goto Ldone;

Lregeax:
    p2 = (rex & REX_W) ? rreg[reg] : ereg[reg];
    p3 = getEAxmmymm(rex, c, 128);
    goto Ldone;

Leax_xmm_imm:
    p2 = getEAxmmymm(rex, c, vlen);
    p3 = vlen == 256 ? ymmreg[vreg] : xmmreg[vreg];
    p4 = immed8(c + 1 + EAbytes(c));
    goto Ldone;

Lxmm_eax_imm:
    p2 = vlen == 256 ? ymmreg[vreg] : xmmreg[vreg];
    p3 = getEAxmmymm(rex, c, vlen);
    p4 = immed8(c + 1 + EAbytes(c));
    goto Ldone;

Lea_xmm_imm:
    p2 = getEAvec(rex, c);
    p3 = xmmreg[reg];
    p4 = immed8(c + 1 + EAbytes(c));
    goto Ldone;

Lxmm_eax:
    p2 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = getEAxmmymm(rex, c, vlen);
    goto Ldone;

Leax_xmm:
    p2 = getEAxmmymm(rex, c, vlen);
    p3 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    goto Ldone;

Lxmm_ea:
    p2 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = getEAvec(rex, c);
    goto Ldone;

Lea_xmm:
    p2 = getEAvec(rex, c);
    p3 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    goto Ldone;

L_xmmea:
    p2 = xmmreg[reg];
    p3 = getEAxmmymm(rex, c, vlen);
    goto Ldone;

Lymmea:
    p2 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = getEAxmmymm(rex, c, 128);
    goto Ldone;

Lrxmm:
    p2 = ereg[reg];
    p3 = getEAxmmymm(rex, c, vlen);
    goto Ldone;

Lxmmxmmea:
    p2 = xmmreg[reg];
    p3 = xmmreg[vreg];
    p4 = getEAvec(rex, c);
    goto Ldone;

Lxeaymmimm:
    p2 = getEAxmmymm(rex, c, 128);
    p3 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p4 = immed8(c + 1 + EAbytes(c));
    goto Ldone;

Lymmxeaimm:
    p2 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = getEAxmmymm(rex, c, 128);
    p4 = immed8(c + 1 + EAbytes(c));
    goto Ldone;

L3op:
    p2 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = vlen == 256 ? ymmreg[vreg] : xmmreg[vreg];
    p4 = getEAxmmymm(rex, c, vlen);
    goto Ldone;

L3opr:
    p4 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = vlen == 256 ? ymmreg[vreg] : xmmreg[vreg];
    p2 = getEAxmmymm(rex, c, vlen);
    goto Ldone;

L4op:
    p5 = immed8(c + 1 + EAbytes(c));
    goto L3op;

Lymm_ymm_eax_imm:
    p2 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = vlen == 256 ? ymmreg[vreg] : xmmreg[vreg];
    p4 = getEAxmmymm(rex, c, 128);
    p5 = immed8(c + 1 + EAbytes(c));
    goto Ldone;

Lymm_ymm_ea_imm:
    p2 = vlen == 256 ? ymmreg[reg] : xmmreg[reg];
    p3 = vlen == 256 ? ymmreg[vreg] : xmmreg[vreg];
    p4 = getEAvec(rex, c);
    p5 = immed8(c + 1 + EAbytes(c));
    goto Ldone;

Ldone:
    void puts(const(char)* s)
    {
        while (*s)
        {
            put(*s);
            ++s;
        }
    }

    puts(p0);
    put('t');
    puts(p1);
    if (*p2)
    {
        put('t');
        puts(p2);
        if (*p3)
        {
            put(',');
            puts(p3);
            if (*p4)
            {
                put(',');
                puts(p4);
                if (*p5)
                {
                    put(',');
                    puts(p5);
                }
            }
        }
    }
}


/***************************
 * Decipher 8087 instructions.
 * Input:
 *      waitflag        if 1 then generate FWAIT form of instruction
 */

void get87string(addr c,char *p0,int waitflag)
{
    uint opcode,reg,modrgrm,mod;
    const(char)* p1, p2, p3;
    uint MF;
    const(char)* mfp;
    immutable char* reserved = "reserved";
    immutable char* fld = "fnld";
    immutable char* fst = "fnst";
    immutable char* fstp = "fnstp";
    immutable char* fisttp = "fnisttp";
    __gshared const(char)*[8] orth =
    [   "fnadd","fnmul","fncom","fncomp","fnsub","fnsubr","fndiv","fndivr"];
    __gshared const(char)*[4] mfstring = ["float","dword","qword","word"];
    __gshared const(char)*[8] op7 =
    [   "fnild","fnisttp","fnist","fnistp","fnbld","fnild","fnbst","fnistp"];
    __gshared const(char)*[7] op7b = [ "fnfree","fnxch","fnstp","fnstp","fnstsw","fnucomip","fncomip" ];
    __gshared const(char)*[4] opD9 = [ "fnldenv","fnldcw","fnstenv","fnstcw" ];
    __gshared const(char)*[6] opDDb = ["fnfree","fnxch","fnst","fnstp","fnucom","fnucomp"];
    __gshared const(char)*[8] opDDa = ["fnld","fnisttp","fnst","fnstp",
            "fnrstor","reserved","fnsave","fnstsw"];
    __gshared const(char)*[5] opDBa = [ "fneni","fndisi","fnclex","fninit","fnsetpm" ];
    __gshared const(char)* ST = "ST";
    __gshared const(char)* STI = "ST(i)";
    char[6] sti;

    waitflag = 1;
    mfp = p2 = p3 = "";
    p1 = reserved;
    opcode = code[c];
    modrgrm = code[c + 1];
    reg = (modrgrm >> 3) & 7;
    MF = (opcode >> 1) & 3;
    mod = (modrgrm >> 6) & 3;
    if (opcode == 0xDA)
    {
        switch (modrgrm & ~7)
        {
            case 0xC0:  p1 = "fncmovb";         goto Lcc;
            case 0xC8:  p1 = "fncmove";         goto Lcc;
            case 0xD0:  p1 = "fncmovbe";        goto Lcc;
            case 0xD8:  p1 = "fncmovu";         goto Lcc;
            default:
                break;
        }
    }
    else if (opcode == 0xDB)
    {
        switch (modrgrm & ~7)
        {
            case 0xC0:  p1 = "fncmovnb";        goto Lcc;
            case 0xC8:  p1 = "fncmovne";        goto Lcc;
            case 0xD0:  p1 = "fncmovnbe";       goto Lcc;
            case 0xD8:  p1 = "fncmovnu";        goto Lcc;
            Lcc:
                if ((modrgrm & 7) != 1)
                {
                    strcpy(sti.ptr, STI);
                    sti[3] = (modrgrm & 7) + '0';
                    p2 = sti.ptr;
                }
                goto L2;
            default:
                break;
        }
    }

    if ((opcode & 1) == 0)
    {
        p1 = orth[reg];
        if (mod == 3)
        {
            immutable char*[8] orthp =
            [ "fnaddp","fnmulp","fncomp","fncompp",
              "fnsubrp","fnsubp","fndivrp","fndivp"
            ];

            if (opcode == 0xDE)
                p1 = orthp[reg];
            if (modrgrm != 0xD9)                /* FNCOMPP      */
            {
                strcpy(sti.ptr, STI);
                sti[3] = (modrgrm & 7) + '0';
                p2 = sti.ptr;
                if ((reg & 6) != 2)
                {
                    if (opcode == 0xD8 && ((reg & 6) != 2))
                    {   p3 = p2;
                        p2 = ST;
                    }
                    else
                        p3 = ST;
                }
            }
            if (opcode == 0xDA && modrgrm == 0xE9)
                p1 = "fnucompp";
        }
        else
        {   mfp = mfstring[MF];
            p2 = getEA(0, c);
        }
    }
    else if (reg == 0 && mod != 3)
    {   p1 = (opcode == 0xDB || opcode == 0xDF) ? op7[reg] : fld;
            mfp = mfstring[MF];
            p2 = getEA(0, c);
    }
    else if (reg == 2 && mod != 3)
    {   p1 = (opcode == 0xDB || opcode == 0xDF) ? op7[reg] : fst;
            mfp = mfstring[MF];
            p2 = getEA(0, c);
    }
    else if (reg == 3 && mod != 3)
    {   p1 = (opcode == 0xDB || opcode == 0xDF) ? op7[reg] : fstp;
            mfp = mfstring[MF];
            p2 = getEA(0, c);
    }
    else
    {   switch (opcode)
        {
            case 0xD9:
                if (mod != 3)
                {   p1 = opD9[reg - 4];
                    p2 = getEA(0, c);
                }
                else if (reg <= 3)
                {   switch (reg)
                    {   case 0:
                            p1 = fld;
                            goto L1;
                        case 1:
                            p1 = "fnxch";
                            goto L1;
                        case 2:
                            if ((modrgrm & 7) == 0)
                                    p1 = "fnnop";
                            else
                                    p1 = reserved;
                            break;
                        case 3:
                            p1 = fstp;
                        L1:
                            strcpy(sti.ptr,STI);
                            sti[3] = (modrgrm & 7) + '0';
                            p2 = sti.ptr;
                            break;
                        default:
                            break;
                    }
                }
                else
                {
                    immutable char*[32] opuna =
                    [ "fnchs","fnabs","reserved","reserved",
                      "fntst","fnxam","reserved","reserved",
                      "fnld1","fnldl2t","fnldl2e","fnldpi",
                      "fnldlg2","fnldln2","fnldz","reserved",
                      "fn2xm1","fnyl2x","fnptan","fnpatan",
                      "fnxtract","fnprem1","fndecstp","fnincstp",
                      "fnprem","fnyl2xp1","fnsqrt","fnsincos",
                      "fnrndint","fnscale","fnsin","fncos"
                    ];

                    p1 = opuna[modrgrm & 0x1F];
                }
                break;
            case 0xDB:
                if (modrgrm >= 0xE0 && modrgrm <= 0xE4)
                    p1 = opDBa[modrgrm - 0xE0];
                else if (mod != 3 && (reg == 5 || reg == 7))
                {   p1 = (reg == 5) ? fld : fstp;
                    p2 = getEA(0, c);
                    mfp = "tbyte";
                }
                else if (mod != 3 && reg == 1)
                {   p1 = fisttp;
                    p2 = getEA(0, c);
                    mfp = "word";
                }
                else if ((modrgrm & 0xF8) == 0xF0)
                {   p1 = "fncomi";
                 Lst:
                    if ((modrgrm & 7) != 1)
                    {
                        strcpy(sti.ptr, STI);
                        sti[3] = (modrgrm & 7) + '0';
                        p2 = sti.ptr;
                    }
                }
                else if ((modrgrm & 0xF8) == 0xE8)
                {   p1 = "fnucomi";
                    goto Lst;
                }
                break;
            case 0xDD:
                if (mod != 3)
                {   p1 = opDDa[reg];
                    p2 = getEA(0, c);
                    if (reg == 1)               // if FISTTP m64int
                        mfp = "long64";
                }
                else if (reg <= 5)
                {   p1 = opDDb[reg];
                    if (modrgrm & 7)
                    {
                        strcpy(sti.ptr, STI);
                        sti[3] = (modrgrm & 7) + '0';
                        p2 = sti.ptr;
                    }
                    else
                        p2 = ST;
                }
                break;
            case 0xDF:
                p1 = op7[reg];
                if (reg == 1)
                    mfp = "short";
                else if (reg <= 3)
                    mfp = "long";
                else if (reg == 5 || reg == 7)
                    mfp = "long64";
                if ((modrgrm & 0xC0) == 0xC0)
                {   p1 = (reg <= 6) ? op7b[reg] : reserved;
                    if (reg == 4)
                        p2 = "AX";
                    else
                    {   if (reg == 5)
                            mfp = "";
                        if ((modrgrm & 7) != 1)
                        {
                            strcpy(sti.ptr, STI);
                            sti[3] = (modrgrm & 7) + '0';
                            p2 = sti.ptr;
                        }
                    }
                }
                else
                    p2 = getEA(0, c);
                break;
            default:
                break;
        }
    }
L2:
    void puts(const(char)* s)
    {
        while (*s)
        {
            put(*s);
            ++s;
        }
    }

    puts(p0);
    put('\t');
    if (waitflag)
        puts(p1 + 2);
    else
        puts(p1);
    if (*p2)
    {
        put('\t');
        if (*mfp)
        {
            puts(mfp);
            puts(" ptr ");
        }
        puts(p2);
        if (*p3)
        {
            put(',');
            puts(p3);
        }
    }
}

void puts(const(char)* s)
{
    while (*s)
    {
        put(*s);
        ++s;
    }
}

/**
 * Holding area for functions that implement X86 instruction patterns
 * It's a mixin template so it can be mixed into `disassemble` to access
 * it's state.
 */
mixin template PatternFunctions()
{
    /**
     * Implements `xmm1, xmm2/m128, imm8`
     * Params:
     *   indexOffset = this will be called from various amounts of
     *                 lookahead into the code buffer which means an index is needed
     *                 for finding the right offset to the register.
     */
    void xmm_xmm_imm8(uint indexOffset)
    {
        p2 = xmmreg[reg];
        p3 = getEAxmm(rex, c + indexOffset);
        p4 = immed8(c + 2 + EAbytes(c + 1));
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
    puts("   ");
    uint prefixsize = 0;
    uint sz;
    do
    {
        sz = prefixbyte(c);
        c += sz;
        prefixsize += sz;
    } while (sz);
    assert(siz > prefixsize);
    siz -= prefixsize;

    uint opcode,reg = 0;
    ubyte rex;
    int i,o3;
    const(char)* p1, p2, p3, p4;
    char[80] p0;
    char[5] p1buf;
    const(char)* sep;
    const(char)* s2;
    const(char)* s3;
    char[BUFMAX] buf = void;

    mixin PatternFunctions;
    enum MOV = "mov";
    enum XCHG = "xchg";
    enum IMUL = "imul";
    enum SHRD = "shrd";
    enum SHLD = "shld";
    __gshared const char*[12] astring =
    [   "add","or", "adc","sbb","and","sub","xor","cmp",
      "inc","dec","push","pop"
    ];
    __gshared const char*[4] bstring = [ "daa","das","aaa","aas" ];
    __gshared const char*[8] mulop =
    [   "test","F6|7?","not","neg","mul",IMUL,"div","idiv" ];
    __gshared const char*[8] segreg = [ "ES","CS","SS","DS","FS","FS","?6","?7" ];
    __gshared const char*[16] jmpop =
    [   "jo","jno","jb","jae","je","jne","jbe","ja",
      "js","jns","jp","jnp","jl","jge","jle","jg"
    ];
    __gshared const char*[0x100 - 0x90] ge90 =
    [   "nop",XCHG,XCHG,XCHG,XCHG,XCHG,XCHG,XCHG,
      "cbw","cwd","call","wait","pushf","popf","sahf","lahf",
      MOV,MOV,MOV,MOV,"movsb","movsw","cmpsb","cmpsw",
      "test","test","stosb","stosw","lodsb","lodsw","scasb","scasw",
      MOV,MOV,MOV,MOV,MOV,MOV,MOV,MOV,
      MOV,MOV,MOV,MOV,MOV,MOV,MOV,MOV,
      "C0","C1","ret","ret","les","lds",MOV,MOV,
      "enter","leave","retf","retf","int","int","into","iret",
      "D0","D1","D2","D3","aam","aad","D6","xlat",
      "D8","D9","DA","DB","DC","DD","DE","DF",  /* ESC  */
      "loopne","loope","loop","jcxz","in","in","out","out",
      "call","jmp","jmp","jmp short","in","in","out","out",
      "lock","F1","repne","rep","hlt","cmc","F6","F7",
      "clc","stc","cli","sti","cld","std","FE","FF"
    ];

    buf[0] = 0;
    sep = ",".ptr;
    s2 = "".ptr;
    s3 = s2;
    opcode = code[c];
    p0[0]='\0';
    if (bObjectcode) {
        for (i=0; i<siz; i++) {
            sprintf( buf.ptr, "%02X ", code[c+i] );
            strcat( p0.ptr, buf.ptr );
        }
        for (; i + prefixsize < 8; i++)
            strcat(p0.ptr, "   ");
    }

    // if VEX prefix
    if (siz >= 3 &&
        (opcode == 0xC4 || opcode == 0xC5) &&
        (model == 64 || (code[c + 1] & 0xC0) == 0xC0)
       )
    {
        getVEXstring(c, siz, p0.ptr);
        return;
    }

    rex = 0;
    if (model == 64)
    {
        if (opcode == 0xF3 || opcode == 0xF2)
        {   if ((code[c + 1] & 0xF0) == REX)
            {
               c++;
               rex = code[c];
            }
        }
        else if ((opcode & 0xF0) == REX)
        {   rex = cast(ubyte)opcode;
            c++;
            opcode = code[c];
        }
    }
    if (inssize[opcode] & M)    /* if modregrm byte             */
    {   reg = (code[c + 1] >> 3) & 7;
        if (rex & REX_R)
            reg |= 8;
    }
    sprintf(p1buf.ptr,"0x%02x",opcode);
    p1 = p1buf.ptr;
    p2 = "";
    p3 = "";
    p4 = "";
    if (opcode >= 0x90)
    {
        p1 = ge90[opcode - 0x90];
        if (!opsize)                    /* if 32 bit operand    */
        {   switch (opcode)
            {   case 0x98:      p1 = "cwde";
                            if (rex & REX_W)
                                p1 = "cdqe";
                            break;
                case 0x99:      p1 = "cdq";
                            if (rex & REX_W)
                                p1 = "cqo";
                            break;
                case 0x9C:      p1 = "pushfd";  break;
                case 0x9D:  p1 = "popfd";       break;
                case 0xA5:      p1 = "movsd";   break;
                case 0xA7:      p1 = "cmpsd";   break;
                case 0xAB:      p1 = "stosd";   break;
                case 0xAD:      p1 = "lodsd";   break;
                case 0xAF:      p1 = "scasd";   break;
                case 0xCF:      p1 = "iretd";   break;
                default:
                    break;
            }
        }
        if (opcode == 0xF2 && code[c + 1] == 0x0F)
        {
            reg = (code[c + 3] >> 3) & 7;
            switch (code[c + 2])
            {
                case 0x10:      p1 = "movsd";           goto Lsdxmm;
                case 0x11:      p1 = "movsd";           goto Lsdxmmr;
                case 0x12:      p1 = "movddup";         goto Lsdxmm;
                case 0x2A:      p1 = "cvtsi2sd";        goto Lsd32;
                case 0x2C:      p1 = "cvttsd2si";       goto Lsd4;
                case 0x2D:      p1 = "cvtsd2si";        goto Lsd;
                case 0x51:      p1 = "sqrtsd";          goto Lsd;
                case 0x58:      p1 = "addsd";           goto Lsd;
                case 0x59:      p1 = "mulsd";           goto Lsd;
                case 0x5A:      p1 = "cvtsd2ss";        goto Lsd;
                case 0x5C:      p1 = "subsd";           goto Lsd;
                case 0x5D:      p1 = "minsd";           goto Lsd;
                case 0x5E:      p1 = "divsd";           goto Lsd;
                case 0x5F:      p1 = "maxsd";           goto Lsd;
                case 0x70:
                            p1 = "pshuflw";
                            xmm_xmm_imm8(1);
                            break;
                case 0x7C:      p1 = "haddps";          goto Lsdxmm;
                case 0x7D:      p1 = "hsubps";          goto Lsdxmm;
                case 0xC2:      p1 = "cmpsd";           goto Lsdi;
                case 0xD0:      p1 = "addsubps";        goto Lsdxmm;
                case 0xD6:      p1 = "movdq2q";         goto Lsdmm;
                case 0xE6:      p1 = "cvtpd2dq";        goto Lsd;
                case 0xF0:      p1 = "lddqu";           goto Lsdxmm;
                default:
                    break;
            }
        }
        if (opcode == 0xF3 && code[c + 1] == 0x0F)
        {
            reg = (code[c + 3] >> 3) & 7;
            switch (code[c + 2])
            {
                case 0x10:      p1 = "movss";           goto Lsdxmm;
                case 0x11:      p1 = "movss";           goto Lsdxmmr;
                case 0x12:      p1 = "movsldup";        goto Lsdxmm;
                case 0x16:      p1 = "movshdup";        goto Lsdxmm;
                case 0x2A:      p1 = "cvtsi2ss";        goto Lsd32;
                case 0x2C:      p1 = "cvttss2si";       goto Lsd4;
                case 0x2D:      p1 = "cvtss2si";        goto Lsd;
                case 0x51:      p1 = "sqrtss";          goto Lsd;
                case 0x52:      p1 = "rsqrtss";         goto Lsd;
                case 0x53:      p1 = "rcpss";           goto Lsd;
                case 0x58:      p1 = "addss";           goto Lsd;
                case 0x59:      p1 = "mulss";           goto Lsd;
                case 0x5A:      p1 = "cvtss2sd";        goto Lsd;
                case 0x5B:      p1 = "cvttps2dq";       goto Lsd;
                case 0x5C:      p1 = "subss";           goto Lsd;
                case 0x5D:      p1 = "minss";           goto Lsd;
                case 0x5E:      p1 = "divss";           goto Lsd;
                case 0x5F:      p1 = "maxss";           goto Lsd;
                case 0x6F:      p1 = "movdqu";          goto Lsdxmm;
                case 0x70:
                        p1 = "pshufhw";
                        xmm_xmm_imm8(1);
                        break;
                case 0xC2:
                        p1 = "cmpss";
                        xmm_xmm_imm8(1);
                        break;
                case 0xD6:      p1 = "movq2dq";         goto Lsdmmr;
                case 0xE6:      p1 = "cvtdq2pd";        goto Lsd;
                case 0x7E:      p1 = "movq";            goto Lsdxmm;
                case 0x7F:      p1 = "movdqu";          goto Lsdxmmr;
                Lsdi:
                    p4 = immed8(c + 3 + EAbytes(c + 2));
                Lsd:
                    p2 = xmmreg[reg];
                    p3 = getEA(rex, c + 1);
                    goto Ldone;
                Lsd32:
                    p2 = xmmreg[reg];
                    inssize2[0x2A] = M|3;
                    p3 = getEA(rex, c + 1);
                    inssize2[0x2A] = X|3;
                    goto Ldone;
                Lsd4:
                    p2 = ereg[reg];
                    p3 = getEA(rex, c + 1);
                    goto Ldone;
                Lsdxmm:
                    p2 = xmmreg[reg];
                    p3 = getEAxmm(rex, c + 1);
                    goto Ldone;

                Lsdxmmr:
                    p3 = xmmreg[reg];
                    p2 = getEAxmm(rex, c + 1);
                    goto Ldone;
                Lsdmm:
                    p2 = mmreg[reg];
                    p3 = getEAxmm(rex, c + 1);
                    goto Ldone;
                Lsdmmr:
                    p2 = xmmreg[reg];
                    p3 = getEA(rex, c + 1);
                    goto Ldone;
                default:
                    break;
            }
        }
    }
    if (opcode < 0x60)
    {
        if (opsize != defopsize && opcode == 0x0F &&
            (code[c + 1] == 0x38 || code[c + 1] == 0x3A)
           )
        {   // SSE4
            opcode = code[c + 2];

            if (inssize2[code[c + 1]] & M)      // if modregrm byte
            {   reg = (code[c + 2] >> 3) & 7;
                if (rex & REX_R)
                    reg |= 8;
            }
            switch (opcode)
            {
                case 0x40:
                    p1 = "dpps";
                    goto Ldpp;
                case 0x41:
                    p1 = "dppd";
                Ldpp:
                    p2 = xmmreg[reg];
                    p3 = getEAxmm(rex, c);
                    p4 = immed8(c + 3 + EAbytes(c + 2));
                    break;
                default:
                    break;
            }
        }
        else if (opcode == 0x0F)
        {   opcode = code[c + 1];

            if (inssize2[opcode] & M)   // if modregrm byte
            {   reg = (code[c + 2] >> 3) & 7;
                if (rex & REX_R)
                    reg |= 8;
            }

            switch (opcode)
            {
                case 0x00:
                    {
                        __gshared const char*[8] pszGrp6 = [ "sldt","str","lldt","ltr",
                            "verr", "verw", "bad6", "bad7" ];
                    p1 = pszGrp6[reg];
                    p2 = getEA(rex, c);
                    goto Ldone;
                    }
                case 0x01:
                    if (code[c + 2] == 0xC8)
                    {   p1 = "monitor";
                        goto Ldone;
                    }
                    else if (code[c + 2] == 0xC9)
                    {   p1 = "mwait";
                        goto Ldone;
                    }
                    else if (code[c + 2] == 0xD0)
                    {   p1 = "xgetbv";
                        goto Ldone;
                    }
                    else if (code[c + 2] == 0xD1)
                    {   p1 = "xsetbv";
                        goto Ldone;
                    }
                    else if (code[c+2] == 0xF9)
                    {
                        //0F 01 F9 RDTSCP
                        p1 = "rdtscp";
                        goto Ldone;
                    }
                    else
                    {
                        __gshared const char*[8] pszGrp7 = [ "sgdt", "sidt", "lgdt",
                            "lidt", "smsw", "bad5", "lmsw", "invlpg" ];
                        p1 = pszGrp7[reg];
                        p2 = getEA(rex, c);
                        goto Ldone;
                    }
                case 0x02:
                    p1 = "lar";
                    break;
                case 0x03:
                    p1 = "lsl";
                    break;
                case 0x06:
                    p1 = "clts";
                    goto Ldone;
                case 0x08:
                    p1 = "invd";
                    goto Ldone;
                case 0x09:
                    p1 = "wbinvd";
                    goto Ldone;
                case 0x0B:
                    p1 = "ud2";
                    goto Ldone;
                case 0x0D:
                    if (reg == 1 || reg == 2)
                    {
                        p1 = reg == 1 ? "prefetchw" : "prefetchwt1";
                        p2 = getEA(rex, c);
                        goto Ldone;
                    }
                    break;
                case 0x0F:
                {   __gshared const ubyte[22] imm =
                    [   0xBF,0x1D,0xAE,0x9E,
                      0xB0,0x90,0xA0,0xA4,
                      0x94,0xB4,0x8A,0x8E,
                      0x96,0xA6,0xB6,0xA7,
                      0x97,0x9A,0xAA,0x0D,
                      0xB7,0xBB,
                    ];
                    __gshared const char*[22] amdstring =
                    [
                        "pavgusb","pf2id","pfacc","pfadd",
                        "pfcmpeq","pfcmpge","pfcmpgt","pfmax",
                        "pfmin","pfmul","pfnacc","pfpnacc",
                        "pfrcp","pfrcpit1","pfrcpit2","pfrsqit1",
                        "pfrsqrt","pfsub","pfsubr","pi2fd",
                        "pmulhrw","pswapd",
                    ];

                    const opimm = code[c + 2 + EAbytes(c + 1)];
                    foreach (j; 0 .. imm.length)
                    {
                        if (imm[j] == opimm)
                        {   p1 = amdstring[j];
                            break;
                        }
                    }
                    p2 = mmreg[reg];
                    p3 = getEA(rex, c);
                    goto Ldone;
                }
                case 0x10:
                case 0x11:
                    p1 = (opsize != defopsize) ? "movupd" : "movups";
                    if (opcode == 0x10)
                    {
                        goto Lxmm;
                    }
                    p3 = xmmreg[reg];
                    p2 = getEA(rex, c);
                    goto Ldone;
                case 0x12:
                case 0x13:
                    p1 = (opsize != defopsize) ? "movlpd" : "movlps";
                    if (opcode == 0x12)
                    {
                        if (opsize == defopsize &&
                            (code[c + 2] & 0xC0) == 0xC0)
                            p1 = "movhlps";
                        goto Lxmm;
                    }
                    p3 = xmmreg[reg];
                    p2 = getEA(rex, c);
                    goto Ldone;
                case 0x14:
                    p1 = (opsize != defopsize) ? "unpcklpd" : "unpcklps";
                    goto Lxmm;
                case 0x15:
                    p1 = (opsize != defopsize) ? "unpckhpd" : "unpckhps";
                    goto Lxmm;
                case 0x16:
                case 0x17:
                    p1 = (opsize != defopsize) ? "movhpd" : "movhps";
                    if (opcode == 0x16)
                    {
                        if (opsize == defopsize &&
                            (code[c + 2] & 0xC0) == 0xC0)
                            p1 = "movlhps";
                        goto Lxmm;
                    }
                    p3 = xmmreg[reg];
                    p2 = getEA(rex, c);
                    goto Ldone;
                case 0x18:
                {   __gshared const char*[4] prefetch = ["prefetchnta","prefetcht0",
                            "prefetcht1","prefetcht2" ];
                    p1 = prefetch[reg];
                    p2 = getEA(rex, c);
                    goto Ldone;
                }
                case 0x1F:
                    p1 = "nop";
                    p2 = getEA(rex, c);
                    goto Ldone;
                case 0x20:
                    p1 = "mov";
                    p2 = ereg[code[c+2]&7];
                    strcpy( buf.ptr, "CR0" );
                    buf[2] += reg;
                    p3 = buf.ptr;
                    goto Ldone;
                case 0x21:
                    p1 = "mov";
                    p2 = ereg[code[c+2]&7];
                    strcpy( buf.ptr, "DR0" );
                    buf[2] += reg;
                    p3 = buf.ptr;
                    goto Ldone;
                case 0x22:
                    p1 = "mov";
                    strcpy( buf.ptr, "CR0" );
                    buf[2] += reg;
                    p2 = buf.ptr;
                    p3 = ereg[code[c+2]&7];
                    goto Ldone;
                case 0x23:
                    p1 = "mov";
                    strcpy( buf.ptr, "DR0" );
                    buf[2] += reg;
                    p2 = buf.ptr;
                    p3 = ereg[code[c+2]&7];
                    goto Ldone;
                case 0x24:
                    p1 = "mov";
                    p2 = ereg[code[c+2]&7];
                    strcpy( buf.ptr, "TR0" );
                    buf[2] += reg;
                    p3 = buf.ptr;
                    goto Ldone;
                case 0x26:
                    p1 = "mov";
                    strcpy( buf.ptr, "TR0" );
                    buf[2] += reg;
                    p2 = buf.ptr;
                    p3 = ereg[code[c+2]&7];
                    goto Ldone;
                case 0x28:
                case 0x29:
                    p1 = (opsize != defopsize) ? "movapd" : "movaps";
                    if (opcode == 0x28)
                        goto Lxmm;
                    p3 = xmmreg[reg];
                    p2 = getEA(rex, c);
                    goto Ldone;
                case 0x2A:
                    p1 = (opsize != defopsize) ? "cvtpi2pd" : "cvtpi2ps";
                    goto Lxmm;
                case 0x2B:
                    p1 = (opsize != defopsize) ? "movntpd" : "movntps";
                    p3 = xmmreg[reg];
                    p2 = getEA(rex, c);
                    goto Ldone;
                case 0x2C:
                    p1 = (opsize != defopsize) ? "cvttpd2pi" : "cvttps2pi";
                    p2 = mmreg[reg];
                    p3 = getEA(rex, c);
                    goto Ldone;
                case 0x2D:
                    p1 = (opsize != defopsize) ? "cvtpd2pi" : "cvtps2pi";
                    p2 = mmreg[reg];
                    p3 = getEA(rex, c);
                    goto Ldone;
                case 0x2E:
                    p1 = (opsize != defopsize) ? "ucomisd" : "ucomiss";
                    goto Lxmm;
                case 0x2F:
                    p1 = (opsize != defopsize) ? "comisd" : "comiss";
                    goto Lxmm;
                case 0x30:
                    p1 = "wrmsr";
                    goto Ldone;
                case 0x31:
                    p1 = "rdtsc";
                    goto Ldone;
                case 0x32:
                    p1 = "rdmsr";
                    goto Ldone;
                case 0x33:
                    p1 = "rdpmc";
                    goto Ldone;
                case 0x34:
                    p1 = "sysenter";
                    goto Ldone;
                case 0x35:
                    p1 = "sysexit";
                    goto Ldone;
                case 0x50:
                    p1 = (opsize != defopsize) ? "movmskpd" : "movmskps";
                    p2 = ereg[reg];
                    p3 = getEA(rex, c);

                    goto Ldone;
                case 0x51:
                    p1 = (opsize != defopsize) ? "sqrtpd" : "sqrtps";
                    goto Lxmm;
                case 0x52:
                    p1 = "rsqrtps";
                    goto Lxmm;
                case 0x53:
                    p1 = "rcpps";
                    goto Lxmm;
                case 0x54:
                    p1 = (opsize != defopsize) ? "andpd" : "andps";
                    goto Lxmm;
                case 0x55:
                    p1 = (opsize != defopsize) ? "andnpd" : "andnps";
                    goto Lxmm;
                case 0x56:
                    p1 = (opsize != defopsize) ? "orpd" : "orps";
                    goto Lxmm;
                case 0x57:
                    p1 = (opsize != defopsize) ? "xorpd" : "xorps";
                    goto Lxmm;
                case 0x58:
                    p1 = (opsize != defopsize) ? "addpd" : "addps";
                    goto Lxmm;
                case 0x59:
                    p1 = (opsize != defopsize) ? "mulpd" : "mulps";
                    goto Lxmm;
                case 0x5A:
                    p1 = (opsize != defopsize) ? "cvtpd2ps" : "cvtps2pd";
                    goto Lxmm;
                case 0x5B:
                    p1 = (opsize != defopsize) ? "cvtps2dq" : "cvtdq2ps";
                    goto Lxmm;
                case 0x5C:
                    p1 = (opsize != defopsize) ? "subpd" : "subps";
                    goto Lxmm;
                case 0x5D:
                    p1 = (opsize != defopsize) ? "minpd" : "minps";
                    goto Lxmm;
                case 0x5E:
                    p1 = (opsize != defopsize) ? "divpd" : "divps";
                    goto Lxmm;
                case 0x5F:
                    p1 = (opsize != defopsize) ? "maxpd" : "maxps";
                    goto Lxmm;
                case 0x6F:
                    if (opsize != defopsize)
                    {
                        p1 = "movdqa";
                        p2 = xmmreg[reg];
                        p3 = getEAxmm(rex, c);
                        goto Ldone;
                    }
                    break;
                case 0x70:
                    if (opsize != defopsize)
                    {
                        p1 = "pshufd";
                        xmm_xmm_imm8(0);
                        goto Ldone;
                        /* p2 = xmmreg[reg];
                        p3 = getEAxmm(rex, c);
                        p4 = immed8(c + 2 + EAbytes(c + 1));
                        goto Ldone; */
                    }
                    else
                    {   p1 = "pshufw";
                        p2 = mmreg[reg];
                        p3 = getEA(rex, c);
                        goto Ldone;
                    }
                case 0x71:
                case 0x72:
                case 0x73:
                    if (reg == 2 || (reg == 4 && opcode != 0x73) ||
                        reg == 6)
                    {   __gshared const char[6][9] opp =
                        [   "psrlw","psraw","psllw",
                            "psrld","psrad","pslld",
                            "psrlq","psllq","psllq",
                        ];

                        p1 = opp[(opcode - 0x71) * 3 + (reg >> 2)].ptr;
                        p2 = (opsize != defopsize) ? getEAxmm(rex, c) : getEA(rex, c);
                        p3 = immed8(c + 2 + EAbytes(c + 1));
                        goto Ldone;
                    }
                    if (opsize != defopsize && opcode == 0x73 && (reg == 7 || reg == 3))
                    {
                        p1 = (reg == 7) ? "pslldq" : "psrldq";
                        p2 = getEAxmm(rex, c);
                        p3 = immed8(c + 2 + EAbytes(c + 1));
                        goto Ldone;
                    }
                    break;

                case 0x77:
                    p1 = "emms";
                    goto Ldone;

                case 0x7C:
                    if (opsize != defopsize)
                    {
                        p1 = "haddpd";
                        p2 = xmmreg[reg];
                        p3 = getEAxmm(rex, c);
                        goto Ldone;
                    }
                    break;
                case 0x7D:
                    if (opsize != defopsize)
                    {
                        p1 = "hsubpd";
                        p2 = xmmreg[reg];
                        p3 = getEAxmm(rex, c);
                        goto Ldone;
                    }
                    break;
                case 0x7E:
                    p1 = "movd";
                    if (opsize != defopsize)
                    {
                        p2 = getEA(rex, c);
                        p3 = xmmreg[reg];
                        goto Ldone;
                    }
                    goto Lmovdq;
                case 0x7F:
                    if (opsize != defopsize)
                    {
                        p1 = "movdqa";
                        p2 = getEAxmm(rex, c);
                        p3 = xmmreg[(code[c + 2] >> 3) & 7];
                        goto Ldone;
                    }
                    p1 = "movq";
                Lmovdq:
                    p2 = getEA(rex, c);
                    p3 = mmreg[reg];
                    goto Ldone;
                case 0xa0:
                    p1 = "push";
                    p2 = "FS";
                    goto Ldone;
                case 0xa1:
                    p1 = "pop";
                    p2 = "FS";
                    goto Ldone;
                case 0xA2:
                    p1 = "cpuid";
                    goto Ldone;
                case 0xA3:
                    p1 = "bt";
                    goto Lshd;
                case 0xA4:
                    p1 = SHLD;
                    p4 = immed8(c + 2 + EAbytes(c + 1));
                    goto Lshd;
                case 0xA5:
                    p1 = SHLD;
                    p4 = bytereg[1];    /* "CL"         */
                    goto Lshd;
                case 0xA8:
                    p1 = "push";
                    p2 = "GS";
                    goto Ldone;
                case 0xA9:
                    p1 = "pop";
                    p2 = "GS";
                    goto Ldone;
                case 0xAA:
                    p1 = "rsm";
                    goto Ldone;
                case 0xAB:
                    p1 = "bts";
                    goto Lshd;
                case 0xAC:
                    p1 = SHRD;
                    p4 = immed8(c + 2 + EAbytes(c + 1));
                    goto Lshd;
                case 0xAD:
                    p1 = SHRD;
                    p4 = bytereg[1];    /* "CL"         */
                Lshd:
                    p2 = getEA(rex, c);
                    reg = (code[c + 2] >> 3) & 7;
                    p3 = ereg[reg] + opsize;
                    goto Ldone;
                case 0xAE:
                    switch (code[c + 2])
                    {
                        case 0xE8:      p1 = "lfence";  goto Ldone;
                        case 0xF0:      p1 = "mfence";  goto Ldone;
                        case 0xF8:      p1 = "sfence";  goto Ldone;
                        default:
                            break;
                    }
                    if ((code[c + 2] & 0xC0) != 0xC0)
                    {
                        __gshared const char[9][8] group15 =
                        [   "fxsave","fxrstor","ldmxcsr","stmxcsr","xsave","xrstor","xsaveopt","clflush" ];
                        uint regf = (code[c + 2] >> 3) & 7;
                        p1 = group15[regf].ptr;
                        if (regf == 4 && rex & REX_W)
                            p1 = "xsave64";
                        else if (regf == 5 && rex & REX_W)
                            p1 = "xrstor64";
                        else if (regf == 6 && rex & REX_W)
                            p1 = "xsaveopt64";
                        else
                            p1 = group15[regf].ptr;
                        p2 = getEA(rex, c);
                        goto Ldone;
                    }
                    goto Ldone;
                case 0xAF:
                    p1 = IMUL;
                    break;
                case 0xB0:
                case 0xB1:
                    p1 = "cmpxchg";
                    goto Lshd;
                case 0xB2:
                    p1 = "lss";
                    break;
                case 0xB3:
                    p1 = "btr";
                    goto Lshd;
                case 0xB4:
                    p1 = "lfs";
                    break;
                case 0xB5:
                    p1 = "lgs";
                    break;
                case 0xB6:
                    p1 = "movzx";
                    break;
                case 0xB7:
                case 0xBF:
                {
                    const opsizesave = opsize;
                    p1 = (opcode == 0xB7) ? "movzx" : "movsx";
                    p2 = ereg[reg] + opsize;
                    opsize = true;         // operand is always a word
                    p3 = getEA(rex, c);
                    opsize = opsizesave;
                    goto Ldone;
                }
                case 0xBA:
                {
                    __gshared const char*[8] pszGrp8 = [ "bad0", "bad1", "bad2",
                        "bad3", "bt", "bts", "btr", "btc" ];
                    p1 = pszGrp8[reg];
                    p2 = getEA(rex, c);
                    p3 = immed8(c + 2 + EAbytes(c + 1));
                    goto Ldone;
                }
                case 0xBB:
                    p1 = "btc";
                    goto Lshd;
                case 0xBC:
                    p1 = "bsf";
                    break;
                case 0xBD:
                    p1 = "bsr";
                    break;
                case 0xBE:
                    p1 = "movsx";
                    break;
                case 0xC1:
                case 0xC0:
                    p1 = "xadd";
                    p2 = ereg[reg];
                    p3 = getEA(rex, c);
                    goto Ldone;
                case 0xC2:
                    p1 = (opsize != defopsize) ? "cmppd" : "cmpps";
                    xmm_xmm_imm8(1);
                    goto Ldone;
                Lxmm:
                    p2 = xmmreg[(code[c + 2] >> 3) & 7];
                    p3 = getEA(rex, c);
                    goto Ldone;
                Lmm:
                    p2 = mmreg[(code[c + 2] >> 3) & 7];
                    p3 = getEA(rex, c);
                    goto Ldone;
                case 0xC3:
                    p1 = "movnti";
                    p2 = getEA(rex, c);
                    p3 = ereg[reg];
                    goto Ldone;
                case 0xC4:
                    p1 = "pinsrw";
                    p2 = (opsize != defopsize) ? xmmreg[reg] : mmreg[reg];
                    p3 = getEA(rex, c);
                    p4 = immed8(c + 2 + EAbytes(c + 1));
                    goto Ldone;
                case 0xC5:
                    if ((code[c + 2] & 0xC0) == 0xC0)
                    {   uint m = code[c + 2] & 7;
                        p1 = "pextrw";
                        p2 = ereg[reg];
                        p3 = (opsize != defopsize) ? xmmreg[m] : mmreg[m];
                        p4 = immed8(c + 2 + EAbytes(c + 1));
                        goto Ldone;
                    }
                    break;
                case 0xC6:
                    p1 = (opsize != defopsize) ? "shufpd" : "shufps";
                    xmm_xmm_imm8(0);
                    //p4 = immed8(c + 2 + EAbytes(c + 1));
                    goto Ldone;
                case 0xC7:
                    if (reg == 1)
                    {
                        /+
                            0F C7 /1 CMPXCHG8B m64
                            REX.W + 0F C7 /1 CMPXCHG16B m128
                        +/
                        p1 = rex & REX_W ? "cmpxchg16b" : "cmpxchg8b";
                        p2 = getEA(rex, c);
                        goto Ldone;
                    }
                    if ((code[c + 2] & 0xC0) != 0xC0)
                    {
                        __gshared const char[9][8] grp15 =
                        [   "?0","?1","?2","?3","xsavec","?5","?6","?7" ];
                        uint regf = (code[c + 2] >> 3) & 7;
                        p1 = grp15[regf].ptr;
                        if (regf == 4 && rex & REX_W)
                            p1 = "xsavec64";
                        else
                            p1 = grp15[regf].ptr;
                        p2 = getEA(rex, c);
                        goto Ldone;
                    }
                    break;
                case 0xC8:
                case 0xC9:
                case 0xCA:
                case 0xCB:
                case 0xCC:
                case 0xCD:
                case 0xCE:
                case 0xCF:
                    p1 = "bswap";
                    p2 = ereg[opcode-0xc8];
                    goto Ldone;
                case 0xD0:
                    if (opsize != defopsize)
                    {
                        p1 = "addsubpd";
                        p2 = xmmreg[reg];
                        p3 = getEAxmm(rex, c);
                        goto Ldone;
                    }
                    break;
                case 0xD6:
                    if (opsize != defopsize)
                    {
                        p1 = "movq";
                        p2 = getEAxmm(rex, c);
                        p3 = xmmreg[reg];
                        goto Ldone;
                    }
                    break;
                case 0xD7:
                    p1 = "pmovmskb";
                    p2 = ereg[reg];
                    if (opsize == defopsize)
                        p3 = getEA(rex, c);
                    else
                        p3 = getEAxmm(rex, c);
                    goto Ldone;
                case 0xE7:
                    if (opsize == defopsize)
                    {   p1 = "movntq";
                        p2 = getEA(rex, c);
                        p3 = mmreg[reg];
                    }
                    else
                    {   p1 = "movntdq";
                        p2 = getEA(rex, c);
                        p3 = xmmreg[reg];
                    }
                    goto Ldone;
                case 0xE6:
                    if (opsize == defopsize)
                        break;
                    p1 = "cvttpd2dq";
                    goto Lxmm;
                case 0xF7:
                    if (opsize == defopsize)
                    {
                        p1 = "maskmovq";
                        goto Lmm;
                    }
                    else
                    {   p1 = "maskmovdqu";
                        p2 = xmmreg[(code[c + 2] >> 3) & 7];
                        inssize2[0xF7] = Y|3;
                        p3 = getEA(rex, c);
                        inssize2[0xF7] = X|3;
                        goto Ldone;
                    }
                default:
                    break;
            }
            if (opcode >= 0x40 && opcode <= 0x4F)
            {   __gshared const char*[16] cmov =
                [ "cmovo","cmovno","cmovb","cmovnb","cmovz","cmovnz","cmovbe","cmovnbe",
                  "cmovs","cmovns","cmovp","cmovnp","cmovl","cmovnl","cmovle","cmovnle",
                ];

                p1 = cmov[opcode - 0x40];
                p2 = ereg[reg] + opsize;
                p3 = getEA(rex, c);
            }
            else if (opcode >= 0x60 && opcode <= 0x76)
            {   __gshared const char*[24] ps =
                [   "punpcklbw","punpcklwd","punpckldq","packsswb",
                    "pcmpgtb","pcmpgtw","pcmpgtd","packuswb",
                    "punpckhbw","punpckhwd","punpckhdq","packssdw",
                    "punpcklqdq","punpckhqdq","movd","movq",
                    null,null,null,null,
                    "pcmpeqb","pcmpeqw","pcmpeqd",null,
                ];

                if (ps[opcode - 0x60])
                {   p1 = ps[opcode - 0x60];
                    p2 = mmreg[reg];
                    p3 = getEA(rex, c);
                    if (opsize != defopsize)
                    {
                        switch (opcode)
                        {
                            case 0x60:
                            case 0x61:
                            case 0x62:
                            case 0x63:
                            case 0x64:
                            case 0x65:
                            case 0x66:
                            case 0x67:
                            case 0x68:
                            case 0x69:
                            case 0x6A:
                            case 0x6B:
                            case 0x6C:
                            case 0x6D:
                            case 0x74:
                            case 0x75:
                            case 0x76:
                                p2 = xmmreg[reg];
                                p3 = getEAxmm(rex, c);
                                break;

                            case 0x6E:
                                p2 = xmmreg[reg];
                                break;

                            default:
                                break;
                        }
                    }
                }
            }
            else if (opcode >= 0x90 && opcode <= 0x9F)
            {   __gshared const char*[16] set =
                [ "seto","setno","setb","setnb","setz","setnz","setbe","setnbe",
                  "sets","setns","setp","setnp","setl","setnl","setle","setnle",
                ];

                p1 = set[opcode - 0x90];
                p2 = getEA(rex, c);
            }
            else if (opcode >= 0xD0)
            {
                enum .string dash = "----";
                __gshared const char*[48] psx =
                [ dash,"psrlw","psrld","psrlq","paddq","pmullw",dash,dash,
                  "psubusb","psubusw","pminub","pand","paddusb","paddusw","pmaxub","pandn",
                  "pavgb","psraw","psrad","pavgw","pmulhuw","pmulhw",dash,dash,
                  "psubsb","psubsw","pminsw","por","paddsb","paddsw","pmaxsw","pxor",
                  dash,"psllw","pslld","psllq","pmuludq","pmaddwd","psadbw",dash,
                  "psubb","psubw","psubd","psubq","paddb","paddw","paddd",dash,
                ];

                if (psx[opcode - 0xD0])
                {
                    p1 = psx[opcode - 0xD0];
                    p2 = mmreg[reg];
                    p3 = getEA(rex, c);
                    if (opsize != defopsize)
                    {
                        switch (opcode)
                        {
                            case 0xD1:
                            case 0xD2:
                            case 0xD3:
                            case 0xD4:
                            case 0xD5:
                            case 0xD8:
                            case 0xD9:
                            case 0xDA:
                            case 0xDB:
                            case 0xDC:
                            case 0xDD:
                            case 0xDE:
                            case 0xDF:
                            case 0xE0:
                            case 0xE1:
                            case 0xE2:
                            case 0xE3:
                            case 0xE4:
                            case 0xE5:
                            case 0xE8:
                            case 0xE9:
                            case 0xEA:
                            case 0xEB:
                            case 0xEC:
                            case 0xED:
                            case 0xEE:
                            case 0xEF:
                            case 0xF1:
                            case 0xF2:
                            case 0xF3:
                            case 0xF4:
                            case 0xF5:
                            case 0xF6:
                            case 0xF8:
                            case 0xF9:
                            case 0xFA:
                            case 0xFB:
                            case 0xFC:
                            case 0xFD:
                            case 0xFE:
                                p2 = xmmreg[reg];
                                p3 = getEAxmm(rex, c);
                                break;
                            default:
                                break;
                        }
                    }
                }
            }
            else if (inssize2[opcode] & W)      /* conditional jump     */
            {   p1 = jmpop[opcode & 0x0F];
                uint offset = opsize ? word(code, c) : dword(code, c);
                p2 = labelcode(c + 2, offset, 0, opsize);
            }
            else
            {
                //printf("ereg = %p, reg = %d, opsize = %d opcode = %02x\n", ereg, reg, opsize, opcode);
                p2 = ereg[reg] + opsize;
                if (rex & REX_W)
                    p2 = rreg[reg];
                p3 = getEA(rex, c);
            }
         Ldone:
        }
        else
        {
            o3 = opcode >> 3;
            p1 = astring[o3];
            i = (opcode & 7);
            //printf("test1: o3 = %d, i = %d\n", o3, i);
            if (i >= 6 && opcode < 0x40)
            {   p1 = (i == 7) ? "pop" : "push";
                    p2 = segreg[o3 & 3];
                    if (o3 >= 4)
                    {   if (i == 6)
                                    p1 = "seg";
                            else
                            {   p1 = bstring[o3 - 4];
                                    p2 = "";
                            }
                    }
            }
            else if (opcode >= 0x40)
            {   if (rex & REX_B)
                    i += 8;
                p2 = ereg[i] + opsize;
                if ((o3 == 10 || o3 == 11) && model == 64)
                    p2 = rreg[i];               // PUSH/POP rreg
            }
            else
            {   switch (i)
                {   case 0: p2 = getEA(rex, c);
                            p3 = BREGNAME(rex, reg);
                            break;
                    case 1: p2 = getEA(rex, c);
                            p3 = REGNAME(rex, reg);
                            break;
                    case 2: p2 = BREGNAME(rex, reg);
                            p3 = getEA(rex, c);
                            break;
                    case 3: p2 = REGNAME(rex, reg);
                            p3 = getEA(rex, c);
                            break;
                    case 4: p2 = "AL";
                            p3 = immed8(c + 1);
                            break;
                    case 5: p2 = ereg[0] + opsize;
                            p3 = immed16(code, c + 1, opsize ? 2 : 4);
                            break;
                    default:
                            break;
                }
            }
        }
    }
    else if ((opcode & 0xF0) == 0x70)
    {   p1 = jmpop[opcode & 0xF];
        p2 = shortlabel(c + 2, cast(byte)code[c + 1]);
    }
    else if (opcode >= 0x80 && opcode < 0x84)
    {
        __gshared const char*[8] regstring =
        [   "add","or","adc","sbb","and","sub","xor","cmp" ];

        i = c + 1 + EAbytes(c);
        p1 = regstring[reg];
        p2 = getEA(rex, c);
        switch (opcode & 3)
        {   case 0:
            case 2:     p3 = immed8(i);         break;
            case 3:     p3 = immeds(i);         break;
            case 1:     p3 = immed16(code, i, opsize ? 2 : 4);     break;
            default:    assert(0);
        }
    }
    else if (opcode >= 0x84 && opcode < 0x8C)
    {
        p1 = (opcode <= 0x85) ? "test" :
             (opcode <= 0x87) ? XCHG : MOV;
        if (rex & REX_R)
            reg |= 8;
        switch (opcode & 3)
        {   case 0:     p2 = getEA(rex, c);     p3 = BREGNAME(rex, reg); break;
            case 1:     p2 = getEA(rex, c);     p3 = REGNAME(rex, reg); break;
            case 2:     p2 = BREGNAME(rex, reg);  p3 = getEA(rex, c);   break;
            case 3:     p2 = REGNAME(rex, reg); p3 = getEA(rex, c); break;
            default:    assert(0);
        }
    }
    else if (opcode >= 0x91 && opcode <= 0x97)  /* XCHG */
    {
        p2 = REGNAME(rex, 0);
        p3 = ereg[opcode & 7] + opsize;
    }
    else if (opcode >= 0xB0 && opcode < 0xB8)
    {
        uint r = opcode & 7;
        if (rex & REX_B)
            r |= 8;
        p2 = BREGNAME(rex, r);
        p3 = immed8(c + 1);
    }
    else if (opcode >= 0xB8 && opcode < 0xC0)   /* MOV reg,iw   */
    {
        uint r = opcode & 7;
        int sz2 = opsize ? 2 : 4;
        if (rex & REX_B)
            r |= 8;
        if (rex & REX_W)
        {   p2 = rreg[r];
            sz2 = 8;
        }
        else
            p2 = ereg[r] + opsize;
        p3 = immed16(code, c + 1, sz2);
    }
    else if (opcode >= 0xD8 && opcode <= 0xDF)
    {
        get87string(c,p0.ptr,fwait);
        return;
    }
    else
    {
        switch (opcode)
        {
            case 0xC0:
            case 0xC1:  p3 = immed8(c + 1 + EAbytes(c)); goto shifts;
            case 0xD0:
            case 0xD1:  p3 = "1";               goto shifts;
            case 0xD2:
            case 0xD3:  p3 = "CL";              goto shifts;
            shifts:
                {   __gshared const char*[8] shift =
                    [   "rol","ror","rcl","rcr","shl","shr","?6","sar" ];

                    p1 = shift[reg];
                    p2 = getEA(rex, c);
                }
                    break;
            case 0x60:
                    if (opsize)
                        p1 = "pusha";
                    else
                        p1 = "pushad";
                    break;
            case 0x61:
                    if (opsize)
                        p1 = "popa";
                    else
                        p1 = "popad";
                    break;
            case 0x62:
                p1 = "bound";
                p2 = ereg[reg]+opsize;
                p3 = getEA(rex, c);
                break;
            case 0x63:
                if (model == 64)
                {   p1 = "movsxd";
                    p2 = rreg[reg];
                    p3 = getEA(rex, c);
                }
                else
                {   p1 = "arpl";
                    p2 = getEA(rex, c);
                    p3 = wordreg[reg];
                }
                break;

            case 0x64:
                    p1 = "seg";
                    p2 = "FS";
                    break;
            case 0x65:
                    p1 = "seg";
                    p2 = "GS";
                    break;
            case 0x66:
                    p1 = "opsize";
                    break;
            case 0x67:
                    p1 = "adsize";
                    break;
            case 0x68:
                    p2 = immed16(code, c + 1, opsize ? 2 : 4);
                    goto Lpush;
            case 0x69:
            case 0x6B:
                    p1 = IMUL;
                    p2 = ereg[reg] + opsize;
                    p3 = getEA(rex, c);
                    i = c + 1 + EAbytes(c);
                    p4 = (opcode == 0x69) ? immed16(code, i, opsize ? 2 : 4)
                                          : immeds(i);
                    break;
            case 0x6C:
                p1 = "insb";
                break;
            case 0x6d:
                if (opsize)
                    p1 = "insw";
                else
                    p1 = "insd";
                break;
            case 0x6e:
                p1 = "outsb";
                break;
            case 0x6f:
                if (opsize)
                    p1 = "outsw";
                else
                    p1 = "outsd";
                break;
            case 0x6A:
                    p2 = immeds(c + 1);
            Lpush:
                    p1 = "push";
                    if (opsize != defopsize)
                    {   sprintf(buf.ptr,"dword ptr %s",p2);
                        p2 = buf.ptr + opsize;
                    }
                    break;
            case 0x8C:
                    p1 = MOV;
                    p2 = getEA(rex, c);
                    p3 = segreg[reg];
                    break;
            case 0x8D:
                    p1 = "lea";
                    if (rex & REX_W)
                        p2 = rreg[reg];
                    else
                        p2 = ereg[reg] + opsize;
                    p3 = getEA(rex, c);
                    break;
            case 0x8E:
                    p1 = MOV;
                    p2 = segreg[reg];
                    p3 = getEA(rex, c);
                    break;
            case 0x8F:
                    if (reg == 0)
                    {   p1 = "pop";
                            p2 = getEA(rex, c);
                    }
                    break;
            case 0x9A:
            case 0xEA:
                    p2 = "far ptr";
                    sep = " ";
                    uint offset = opsize ? word(code, c) : dword(code, c);
                    p3 = labelcode(c + 1, offset, 1, opsize);
                    break;
            case 0xA0:
                    p2 = "AL";
                    s3 = segover;
                    uint value = adsize ? dword(code, c + 1) : word(code, c + 1);
                    p3 = mem(c + 1, adsize ? 4 : 2, value);
                    break;
            case 0xA1:
                    p2 = ereg[AX] + opsize;
                    s3 = segover;
                    uint value = adsize ? dword(code, c + 1) : word(code, c + 1);
                    p3 = mem(c + 1, adsize ? 4 : 2, value);
                    break;
            case 0xA2:
                    s2 = segover;
                    uint value = adsize ? dword(code, c + 1) : word(code, c + 1);
                    p2 = mem(c + 1, adsize ? 4 : 2, value);
                    p3 = "AL";
                    break;
            case 0xA3:
                    s2 = segover;
                    uint value = adsize ? dword(code, c + 1) : word(code, c + 1);
                    p2 = mem(c + 1, adsize ? 4 : 2, value);
                    p3 = ereg[AX] + opsize;
                    break;
            case 0xA8:
            case 0xE4:
                    p2 = "AL";
                    p3 = immed8(c + 1);
                    break;
            case 0xE6:
                    p2 = immed8(c + 1);
                    p3 = "AL";
                    break;
            case 0xA9:                  /* TEST */
                    p2 = ereg[AX] + opsize;
                    p3 = immed16(code, c + 1, opsize ? 2 : 4);
                    break;
            case 0xC2:                  /* RETN */
            case 0xCA:                  /* RETF */
                {   const opsizesave = opsize;
                    opsize = 1;         // operand is always a word
                    p2 = immed16(code, c + 1, 2);
                    opsize = opsizesave;
                    break;
                }
            case 0xC4:                  /* LES  */
            case 0xC5:                  /* LDS  */
                    p2 = ereg[reg] + opsize;
                    p3 = getEA(rex, c);
                    break;
            case 0xC6:
                    if (reg == 0)
                    {
                        p1 = MOV;
                        p2 = getEA(rex, c);
                        p3 = immed8(c + 1 + EAbytes(c));
                    }
                    break;
            case 0xC7:
                    if (reg == 0)
                    {
                        p1 = MOV;
                        p2 = getEA(rex, c);
                        p3 = immed16(code, c + 1 + EAbytes(c), opsize ? 2 : 4);
                    }
                    break;
            case 0xC8:                  /* ENTER imm16,imm8     */
            {
                    __gshared char[2+4+1] tmp;

                    p2 = strcpy(tmp.ptr,wordtostring(word(code, c + 1)));
                    p3 = immed8(c + 3);
                    break;
            }
            case 0xCC:                  /* INT 3 */
                    p2 = "3";
                    break;
            case 0xCD:                  /* INT  */
                    p2 = immed8(c + 1);
                    break;
            case 0xE0:                  /* LOOPNZ       */
            case 0xE1:                  /* LOOPZ        */
            case 0xE2:                  /* LOOP         */
            case 0xE3:                  /* JCXZ         */
            case 0xEB:                  /* JMP SHORT    */
                    p2 = shortlabel(c + 2, cast(byte)code[c + 1]);
                    break;
            case 0xE5:
                    p2 = ereg[AX] + opsize;
                    p3 = immed8(c + 1);
                    break;
            case 0xE7:
                    p2 = immed8(c + 1);
                    p3 = ereg[AX] + opsize;
                    break;
            case 0xE8:
            case 0xE9:
                    p2 = nearptr ? "near ptr" : " ";
                    sep = "";
                    uint offset = opsize ? word(code, c + 1) : dword(code, c + 1);
                    p3 = labelcode(c + 1, offset, 0, opsize);
                    break;
            case 0xEC:
                    p2 = "AL,DX";
                    break;
            case 0xED:
                    p2 = ereg[AX] + opsize;
                    p3 = "DX";
                    break;
            case 0xEE:
                    p2 = "DX,AL";
                    break;
            case 0xEF:
                    p2 = "DX";
                    p3 = ereg[AX] + opsize;
                    break;
            case 0xF6:
            case 0xF7:
                    p1 = mulop[reg];
                    p2 = getEA(rex, c);
                    if (reg == 0)
                    {   p3 = (opcode == 0xF6) ?
                                    immed8(c + 1 + EAbytes(c)) :
                                    immed16(code, c + 1 + EAbytes(c), opsize ? 2 : 4);
                    }
                    break;
            case 0xFE:
            case 0xFF:
                    if (reg < 2)
                    {   p1 = (reg == 0) ? "inc" : "dec";
                    }
                    else if (reg < 7 && opcode == 0xFF)
                    {
                        __gshared const char*[5] op =
                        [   "call","callf","jmp","jmpf","push" ];

                        p1 = op[reg - 2];
                    }
                    p2 = getEA(rex, c);
                    break;
            default:
                    break;
        }
    }
    puts(p0.ptr);
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
const(char)* memoryDefault(uint c, uint sz, addr offset)
{
    __gshared char[12 + 1] EA;
    sprintf(EA.ptr,"[0%Xh]",offset);
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

    sprintf(buf.ptr, ((cast(long)offset < 10) ? "%lld" : "0%llXh"), offset);
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
const(char)* labelcodeDefault(uint c, uint offset, bool farflag, bool is16bit)
{
    //printf("offset = %x\n", offset);
    __gshared char[1 + uint.sizeof * 3 + 1] buf;
    sprintf(buf.ptr, "L%x", offset);
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
const(char)* shortlabelDefault(uint pc, int offset)
{
    __gshared char[1 + ulong.sizeof * 3 + 1] buf;
    sprintf(buf.ptr, "L%x", pc + offset);
    return buf.ptr;
}

/*****************************
 * Load word at code[c].
 */

uint word(ubyte[] code, uint c)
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
const(char)* wordtostring(uint w)
{
    __gshared char[1 + w.sizeof * 3 + 1 + 1] EA;

    sprintf(EA.ptr, ((w < 10) ? "%ld" : "0%lXh"), w);
    return EA.ptr;
}


/*************
 * Size in bytes of each instruction.
 * 0 means illegal instruction.
 *      X:      EA is MMX register
 *      Y:      EA is XMM register
 *      B:      transfer with byte offset
 *      W:      transfer with word/dword offset
 *      U:      unconditional transfer (jmps and returns)
 *      M:      if there is a modregrm field (EV1 is reserved for modregrm)
 *      T:      if there is a second operand (EV2)
 *      E:      if second operand is only 8 bits
 *      A:      a short version exists for the AX reg
 *      R:      a short version exists for regs
 * bits 2..0:   size of instruction (excluding optional bytes)
 */

enum X = (0x800 | M);
enum Y = (0x1000 | M);
enum B = 0x400;
enum R = 0x200;
enum U = 0x100;
enum M = 0x80;
enum T = 0x40;
enum E = 0x20;
enum A = 0x10;
enum W = 0x08;

__gshared uint[256] inssize =
[
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 00 */
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 08 */
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 10 */
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 18 */
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 20 */
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 28 */
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 30 */
    M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 38 */
    1,1,1,1,                1,1,1,1,                /* 40 */
    1,1,1,1,                1,1,1,1,                /* 48 */
    1,1,1,1,                1,1,1,1,                /* 50 */
    1,1,1,1,                1,1,1,1,                /* 58 */
    1,1,M|2,M|2,            1,1,1,1,                /* 60 */
    T|3,M|T|4,T|E|2,M|T|E|3, 1,1,1,1,               /* 68 */
    B|T|E|2,B|T|E|2,B|T|E|2,B|T|E|2, B|T|E|2,B|T|E|2,B|T|E|2,B|T|E|2,
    B|T|E|2,B|T|E|2,B|T|E|2,B|T|E|2, B|T|E|2,B|T|E|2,B|T|E|2,B|T|E|2,
    M|T|E|A|3,M|T|A|4,M|T|E|3,M|T|E|3,      M|2,M|2,M|2,M|A|R|2,    /* 80 */
    M|A|2,M|A|2,M|A|2,M|A|2,                M|2,M|2,M|2,M|R|2,      /* 88 */
    1,1,1,1,                1,1,1,1,                /* 90 */
    1,1,T|5,1,              1,1,1,1,                /* 98 */
    T|3,T|3,T|3,T|3,        1,1,1,1,                /* A0 */
    T|E|2,T|3,1,1,          1,1,1,1,                /* A8 */
    T|E|2,T|E|2,T|E|2,T|E|2,        T|E|2,T|E|2,T|E|2,T|E|2,        /* B0 */
    T|3,T|3,T|3,T|3,                T|3,T|3,T|3,T|3,                /* B8 */
    M|T|E|3,M|T|E|3,U|T|3,U|1,      M|2,M|2,M|T|E|R|3,M|T|R|4,      /* C0 */
    T|E|4,1,U|T|3,U|1,              1,T|E|2,1,U|1,                  /* C8 */
    M|2,M|2,M|2,M|2,        T|E|2,T|E|2,1,1,        /* D0 */
    M|2,M|2,M|2,M|2,        M|2,M|2,M|2,M|2,        /* D8 */
    B|T|E|2,B|T|E|2,B|T|E|2,B|T|E|2, T|E|2,T|E|2,T|E|2,T|E|2, /* E0 */
    W|T|3,W|U|T|3,U|T|5,B|U|T|E|2,  1,1,1,1,                /* E8 */
    1,1,1,1,                1,1,M|A|2,M|A|2,                /* F0 */
    1,1,1,1,                1,1,M|2,M|R|2                   /* F8 */
];

/* 386 instruction sizes        */

__gshared const ubyte[256] inssize32 =
[
    2,2,2,2,        2,5,1,1,                /* 00 */
    2,2,2,2,        2,5,1,1,                /* 08 */
    2,2,2,2,        2,5,1,1,                /* 10 */
    2,2,2,2,        2,5,1,1,                /* 18 */
    2,2,2,2,        2,5,1,1,                /* 20 */
    2,2,2,2,        2,5,1,1,                /* 28 */
    2,2,2,2,        2,5,1,1,                /* 30 */
    2,2,2,2,        2,5,1,1,                /* 38 */
    1,1,1,1,        1,1,1,1,                /* 40 */
    1,1,1,1,        1,1,1,1,                /* 48 */
    1,1,1,1,        1,1,1,1,                /* 50 */
    1,1,1,1,        1,1,1,1,                /* 58 */
    1,1,2,2,        1,1,1,1,                /* 60 */
    5,6,2,3,        1,1,1,1,                /* 68 */
    2,2,2,2,        2,2,2,2,                /* 70 */
    2,2,2,2,        2,2,2,2,                /* 78 */
    3,6,3,3,        2,2,2,2,                /* 80 */
    2,2,2,2,        2,2,2,2,                /* 88 */
    1,1,1,1,        1,1,1,1,                /* 90 */
    1,1,7,1,        1,1,1,1,                /* 98 */
    5,5,5,5,        1,1,1,1,                /* A0 */
    2,5,1,1,        1,1,1,1,                /* A8 */
    2,2,2,2,        2,2,2,2,                /* B0 */
    5,5,5,5,        5,5,5,5,                /* B8 */
    3,3,3,1,        2,2,3,6,                /* C0 */
    4,1,3,1,        1,2,1,1,                /* C8 */
    2,2,2,2,        2,2,1,1,                /* D0 */
    /* For the floating instructions, don't leave room for the FWAIT */
    2,2,2,2,        2,2,2,2,                /* D8 */

    2,2,2,2,        2,2,2,2,                /* E0 */
    5,5,7,2,        1,1,1,1,                /* E8 */
    1,1,1,1,        1,1,2,2,                /* F0 */
    1,1,1,1,        1,1,2,2                 /* F8 */
];

/* For 2 byte opcodes starting with 0x0F        */
__gshared uint[256] inssize2 =
[
    M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 00
    M|3,M|3,M|3,2,          M|3,M|3,M|3,X|T|E|4,    // 08
    Y|3,Y|3,Y|3,Y|3, Y|3,Y|3,Y|3,Y|3,       // 10
    M|3,M|3,M|3,2,   M|3,M|3,M|3,M|3,       // 18
    M|3,M|3,M|3,M|3, M|3,M|3,M|3,2,         // 20
    Y|3,Y|3,X|3,Y|3, Y|3,Y|3,Y|3,Y|3,       // 28
    2,2,2,2,                2,2,2,2,                // 30
    Y|4,M|3,Y|T|E|5,M|3,    M|3,M|3,M|3,M|3,        // 38
    M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 40
    M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 48
    Y|3,Y|3,Y|3,Y|3,        Y|3,Y|3,Y|3,Y|3,        // 50
    Y|3,Y|3,Y|3,Y|3,        Y|3,Y|3,Y|3,Y|3,        // 58
    X|3,X|3,X|3,X|3,        X|3,X|3,X|3,X|3,        // 60
    X|3,X|3,X|3,X|3,        X|3,X|3,M|3,X|3,        // 68
    X|T|E|4,X|T|E|4,X|T|E|4,X|T|E|4, X|3,X|3,X|3,2, // 70
    2,2,2,2,                X|3,X|3,M|3,X|3,        // 78
    W|T|4,W|T|4,W|T|4,W|T|4, W|T|4,W|T|4,W|T|4,W|T|4, // 80
    W|T|4,W|T|4,W|T|4,W|T|4, W|T|4,W|T|4,W|T|4,W|T|4, // 88
    M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // 90
    M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // 98
    2,2,2,M|3,      M|T|E|4,M|3,M|3,M|3,    // A0
    M|3,M|3,M|3,M|3,        M|T|E|4,M|3,M|3,M|3,    // A8
    M|E|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,     // B0
    M|3,M|3,M|T|E|4,M|3, M|3,M|3,M|3,M|3,   // B8
    M|3,M|3,Y|T|E|4,M|3, M|T|E|4,M|T|E|4,Y|T|E|4,M|3,       // C0
    2,2,2,2,        2,2,2,2,                // C8
    X|3,X|3,X|3,X|3, X|3,X|3,X|3,X|3,       // D0
    X|3,X|3,X|3,X|3, X|3,X|3,Y|3,X|3,       // D8
    X|3,X|3,X|3,X|3, X|3,X|3,Y|3,Y|3,       // E0
    X|3,X|3,X|3,X|3, X|3,X|3,Y|3,X|3,       // E8
    Y|3,X|3,X|3,X|3, X|3,X|3,X|3,X|3,       // F0
    X|3,X|3,X|3,X|3, X|3,X|3,X|3,2          // F8
];

__gshared const
{
    char*[16] rreg       = [ "RAX","RCX","RDX","RBX","RSP","RBP","RSI","RDI",
                             "R8","R9","R10","R11","R12","R13","R14","R15" ];
    char*[16] ereg       = [ "EAX","ECX","EDX","EBX","ESP","EBP","ESI","EDI",
                             "R8D","R9D","R10D","R11D","R12D","R13D","R14D","R15D" ];
    char*[16] wordreg    = [ "AX","CX","DX","BX","SP","BP","SI","DI",
                             "R8W","R9W","R10W","R11W","R12W","R13W","R14W","R15W" ];
    char*[16] byteregrex = [ "AL","CL","DL","BL","SPL","BPL","SIL","DIL",
                             "R8B","R9B","R10B","R11B","R12B","R13B","R14B","R15B" ];
    char*[8]  bytereg    = [ "AL","CL","DL","BL","AH","CH","DH","BH" ];
    char*[8]  mmreg      = [ "MM0","MM1","MM2","MM3","MM4","MM5","MM6","MM7" ];
    char*[16] xmmreg     = [ "XMM0","XMM1","XMM2","XMM3","XMM4","XMM5","XMM6","XMM7",
                             "XMM8","XMM9","XMM10","XMM11","XMM12","XMM13","XMM14","XMM15" ];
    char*[16] ymmreg     = [ "YMM0","YMM1","YMM2","YMM3","YMM4","YMM5","YMM6","YMM7",
                             "YMM8","YMM9","YMM10","YMM11","YMM12","YMM13","YMM14","YMM15" ];
}

/************************************* Tests ***********************************/

unittest
{
    int line16 = __LINE__;
    string[20] cases16 =      // 16 bit code gen
    [
        "      55            push    BP",
        "      8B EC         mov     BP,SP",
        "      8B 46 04      mov     AX,4[BP]",
        "      83 C0 05      add     AX,5",
        "      5D            pop     BP",
        "      C3            ret",
        "      83 7E 08 00   cmp     word ptr 8[BP],0",
        "      74 05         je      L7",
        "      D1 66 08      shl     word ptr 8[BP],1",
        "      EB F5         jmp short Lfffffff7",
        "      C4 5E 04      les     BX,4[BP]",
        "26    8B 07         mov     AX,ES:[BX]",
        "26    03 47 10      add     AX,ES:010h[BX]",
        "      8B 4E 08      mov     CX,8[BP]",
        "      83 C1 FD      add     CX,0FFFFFFFDh",
        "      D1 E1         shl     CX,1",
        "      03 D9         add     BX,CX",
        "26    03 07         add     AX,ES:[BX]",
        "      03 06 00 00   add     AX,[00h]",
        "      31 C0         xor     AX,AX",
    ];

    int line32 = __LINE__;
    string[16] cases32 =      // 32 bit code gen
    [
        "8B 44 24 04         mov        EAX,4[ESP]",
        "83 C0 05            add        EAX,5",
        "83 7C 24 08 00      cmp        dword ptr 8[ESP],0",
        "74 06               je         L8",
        "D1 64 24 08         shl        dword ptr 8[ESP],1",
        "EB F3               jmp short  Lfffffff5",
        "8B 00               mov        EAX,[EAX]",
        "8B 4C 24 04         mov        ECX,4[ESP]",
        "03 41 20            add        EAX,020h[ECX]",
        "8B 54 24 08         mov        EDX,8[ESP]",
        "83 C2 FD            add        EDX,0FFFFFFFDh",
        "03 04 91            add        EAX,[EDX*4][ECX]",
        "03 05 00 00 00 00   add        EAX,[00h]",
        "C3                  ret",
        "31 C0               xor        EAX,EAX",
        "0F 31               rdtsc",
    ];

    int line64 = __LINE__;
    string[24] cases64 =      // 64 bit code gen
    [
        "31 C0               xor  EAX,EAX",
        "48 89 4C 24 08      mov  8[RSP],RCX",
        "48 89 D0            mov  RAX,RDX",
        "48 03 44 24 08      add  RAX,8[RSP]",
        "C3                  ret",
        "0F 30               wrmsr",
        "0F 31               rdtsc",
        "0F 32               rdmsr",
        "0F 33               rdpmc",
        "0F 34               sysenter",
        "0F 35               sysexit",
        "BE 12 00 00 00      mov  ESI,012h",
        "BF 00 00 00 00      mov  EDI,0",
        "41 0F C7 09         cmpxchg8b [R9]",
        "49 0F C7 09         cmpxchg16b [R9]",
        "0F 01 F9            rdtscp",
        "66 41 0F 70 C7 66   pshufd    XMM0,XMM15,066h",
        "F2 41 0F 70 C7 F1   pshuflw   XMM0,XMM15,0F1h",
        "F3 41 0F 70 C7 C2   pshufhw   XMM0,XMM15,0C2h",
        "66 41 0F C6 C7 CF   shufpd    XMM0,XMM15,0CFh",
        "66 0F C6 00 CF      shufpd    XMM0,[RAX],0CFh",
        "66 0F C2 00 CF      cmppd     XMM0,[RAX],0CFh",
        "F3 41 0F C2 C7 AF   cmpss     XMM0,XMM15,0C7h",
        "66 0F 73 FF 99      pslldq    XMM7,099h",
    ];

    char[BUFMAX] buf;
    ubyte[BUFMAX] buf2;
    bool errors;

    void testcase(int line, string s, uint size)
    {
        auto codput = Output!ubyte(buf2[]);
        size_t j;
        auto code = hexToUbytes(codput, j, s);
        string expected = s[j .. $];

        addr m;
        auto length = calccodsize(code, 0, m, size);

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
            printf("Fail%d: %d '%.*s' '%.*s'\n",
                size, cast(int)(line + 2),
                cast(int)expected.length, expected.ptr, cast(int)result.length, result.ptr);
            errors = true;
        }
    }

    foreach (i; 0 .. cases16.length)
        testcase(line16, cases16[i], 16);

    foreach (i; 0 .. cases32.length)
        testcase(line32, cases32[i], 32);

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
