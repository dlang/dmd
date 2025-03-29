/**
 * Construct linked list of generated code
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/codebuilder.d, backend/_codebuilder.d)
 * Documentation: https://dlang.org/phobos/dmd_backend_codebuilder.html
 */

module dmd.backend.codebuilder;

import core.stdc.stdio;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.mem;
import dmd.backend.ty;
import dmd.backend.type;

@safe:

struct CodeBuilder
{
  private:

    code* head;
    code** pTail;

    enum BADINS = 0x1234_5678;
//    enum BADINS = 0xF900_0FA0;

  nothrow:
  public:
    //this() { pTail = &head; }
    //this(code* c);

    @trusted
    void ctor()
    {
        pTail = &head;
    }

    @trusted
    void ctor(code* c)
    {
        head = c;
        pTail = c ? &code_last(c).next : &head;
    }

    code* finish()
    {
        return head;
    }

    code* peek() { return head; }       // non-destructively look at the list

    @trusted
    void reset() { head = null; pTail = &head; }

    void append(ref CodeBuilder cdb)
    {
        if (cdb.head)
        {
            *pTail = cdb.head;
            pTail = cdb.pTail;
        }
    }

    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2)
    {
        append(cdb1);
        append(cdb2);
    }

    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2, ref CodeBuilder cdb3)
    {
        append(cdb1);
        append(cdb2);
        append(cdb3);
    }

    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2, ref CodeBuilder cdb3, ref CodeBuilder cdb4)
    {
        append(cdb1);
        append(cdb2);
        append(cdb3);
        append(cdb4);
    }

    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2, ref CodeBuilder cdb3, ref CodeBuilder cdb4, ref CodeBuilder cdb5)
    {
        append(cdb1);
        append(cdb2);
        append(cdb3);
        append(cdb4);
        append(cdb5);
    }

    @trusted
    void append(code* c)
    {
        if (c)
        {
            CodeBuilder cdb = void;
            cdb.ctor(c);
            append(cdb);
        }
    }

    void gen(code* cs)
    {
        /* this is a high usage routine */
        debug assert(cs);
assert(cs.Iop != BADINS);
        assert(I64 || cs.Irex == 0);
        code* ce = code_malloc();
        *ce = *cs;
        //printf("ce = %p %02x\n", ce, ce.Iop);
        //code_print(ce);
        ccheck(ce);
        simplify_code(ce);
        ce.next = null;

        *pTail = ce;
        pTail = &ce.next;
    }

    void gen1(opcode_t op)
    {
        //debug printf("gen1(%08x)\n", op);
assert(op != BADINS);
        code* ce = code_calloc();
        ce.Iop = op;
        ccheck(ce);
        assert(op != LEA);

        *pTail = ce;
        pTail = &ce.next;
    }

    void gen2(opcode_t op, uint rm)
    {
assert(op != BADINS);
        code* ce = code_calloc();
        ce.Iop = op;
        ce.Iea = rm;
        ccheck(ce);

        *pTail = ce;
        pTail = &ce.next;
    }

    /***************************************
     * Generate floating point instruction.
     */
    void genf2(opcode_t op, uint rm)
    {
assert(op != BADINS);
        genfwait(this);
        gen2(op, rm);
    }

    void gen2sib(opcode_t op, uint rm, uint sib)
    {
        code* ce = code_calloc();
        ce.Iop = op;
        ce.Irm = cast(ubyte)rm;
        ce.Isib = cast(ubyte)sib;
        ce.Irex = cast(ubyte)((rm | (sib & (REX_B << 16))) >> 16);
        if (sib & (REX_R << 16))
            ce.Irex |= REX_X;
        ccheck(ce);

        *pTail = ce;
        pTail = &ce.next;
    }

    /********************************
     * Generate an ASM sequence.
     */
    @trusted
    void genasm(const ubyte[] bytes)
    {
        code* ce = code_calloc();
        ce.Iop = ASM;
        ce.IFL1 = FL.asm_;
        ce.IEV1.len = bytes.length;
        ce.IEV1.bytes = cast(char*) mem_malloc(bytes.length);
        memcpy(ce.IEV1.bytes,bytes.ptr,bytes.length);

        *pTail = ce;
        pTail = &ce.next;
    }

    @trusted
    void genasm(_LabelDsymbol* label)
    {
        code* ce = code_calloc();
        ce.Iop = ASM;
        ce.Iflags = CFaddrsize;
        ce.IFL1 = FL.blockoff;
        ce.IEV1.Vsym = cast(Symbol*)label;

        *pTail = ce;
        pTail = &ce.next;
    }

    @trusted
    void genasm(block* label)
    {
        code* ce = code_calloc();
        ce.Iop = ASM;
        ce.Iflags = CFaddrsize;
        ce.IFL1 = FL.blockoff;
        ce.IEV1.Vblock = label;
        label.Bflags |= BFL.label;

        *pTail = ce;
        pTail = &ce.next;
    }

    @trusted
    void gencs1(opcode_t op, uint ea, FL FL1, Symbol* s)
    {
assert(op != BADINS);
        code cs;
        cs.Iop = op;
        cs.Iflags = 0;
        cs.Iea = ea;
        ccheck(&cs);
        cs.IFL1 = FL1;
        cs.IEV1.Vsym = s;
        cs.IEV1.Voffset = 0;

        gen(&cs);
    }

    @trusted
    void gencs(opcode_t op, uint ea, FL FL2, Symbol* s)
    {
assert(op != BADINS);
        code cs;
        cs.Iop = op;
        cs.Iflags = 0;
        cs.Iea = ea;
        ccheck(&cs);
        cs.IFL2 = FL2;
        cs.IEV2.Vsym = s;
        cs.IEV2.Voffset = 0;

        gen(&cs);
    }

    @trusted
    void genc2(opcode_t op, uint ea, targ_size_t EV2)
    {
assert(op != BADINS);
        code cs;
        cs.Iop = op;
        cs.Iflags = 0;
        cs.Iea = ea;
        ccheck(&cs);
        cs.Iflags = CFoff;
        cs.IFL2 = FL.const_;
        cs.IEV2.Vsize_t = EV2;

        gen(&cs);
    }

    @trusted
    void genc1(opcode_t op, uint ea, FL FL1, targ_size_t EV1)
    {
assert(op != BADINS);
        code cs;
        assert(FL1 < FL.max + 1);
        cs.Iop = op;
        cs.Iflags = CFoff;
        cs.Iea = ea;
        ccheck(&cs);
        cs.IFL1 = FL1;
        cs.IEV1.Vsize_t = EV1;

        gen(&cs);
    }

    @trusted
    void genc(opcode_t op, uint ea, FL FL1, targ_size_t EV1, FL FL2, targ_size_t EV2)
    {
assert(op != BADINS);
        code cs;
        assert(FL1 < FL.max + 1);
        cs.Iop = op;
        cs.Iea = ea;
        ccheck(&cs);
        cs.Iflags = CFoff;
        cs.IFL1 = FL1;
        cs.IEV1.Vsize_t = EV1;
        assert(FL2 < FL.max + 1);
        cs.IFL2 = FL2;
        cs.IEV2.Vsize_t = EV2;

        gen(&cs);
    }

    /********************************
     * Generate 'instruction' which is actually a line number.
     */
    @trusted
    void genlinnum(Srcpos srcpos)
    {
        code cs;
        //srcpos.print("genlinnum");
        cs.Iop = PSOP.linnum;
        cs.Iflags = 0;
        cs.Iea = 0;
        cs.IEV1.Vsrcpos = srcpos;
        gen(&cs);
    }

    /********************************
     * Generate 'instruction' which tells the address resolver that the stack has
     * changed.
     */
    @trusted
    void genadjesp(int offset)
    {
        if (!I16 && offset)
        {
            code cs;
            cs.Iop = PSOP.adjesp;
            cs.Iflags = 0;
            cs.Iea = 0;
            cs.IEV1.Vint = offset;
            gen(&cs);
        }
    }

    /********************************
     * Generate 'instruction' which tells the scheduler that the fpu stack has
     * changed.
     */
    @trusted
    void genadjfpu(int offset)
    {
        if (!I16 && offset)
        {
            code cs;
            cs.Iop = PSOP.adjfpu;
            cs.Iflags = 0;
            cs.Iea = 0;
            cs.IEV1.Vint = offset;
            gen(&cs);
        }
    }

    void gennop()
    {
        gen1(NOP);
    }

    /**************************
     * Generate code to deal with floatreg.
     */
    @trusted
    void genfltreg(opcode_t opcode,int reg,targ_size_t offset)
    {
        cgstate.floatreg = true;
        cgstate.reflocal = true;
        if ((opcode & ~7) == 0xD8)
            genfwait(this);
        genc1(opcode,modregxrm(2,reg,BPRM),FL.fltreg,offset);
    }

    @trusted
    void genxmmreg(opcode_t opcode,reg_t xreg,targ_size_t offset, tym_t tym)
    {
        assert(isXMMreg(xreg));
        cgstate.floatreg = true;
        cgstate.reflocal = true;
        genc1(opcode,modregxrm(2,xreg - XMM0,BPRM),FL.fltreg,offset);
        checkSetVex(last(), tym);
    }

    /*****************
     * Returns:
     *  code that pTail points to
     */
    @trusted
    code* last()
    {
        // g++ and clang++ complain about offsetof() because of the code::code() constructor.
        // return (code *)((char *)pTail - offsetof(code, next));
        // So do our own.
        return cast(code*)(cast(void*)pTail - (cast(void*)&(*pTail).next - cast(void*)*pTail));
    }

    /*************************************
     * Handy function to answer the question: who the heck is generating this piece of code?
     */
    static void ccheck(code* cs)
    {
    //    if (cs.Iop == LEA && (cs.Irm & 0x3F) == 0x34 && cs.Isib == 7) *(char*)0=0;
    //    if (cs.Iop == 0x31) *(char*)0=0;
    //    if (cs.Irm == 0x3D) *(char*)0=0;
    //    if (cs.Iop == LEA && cs.Irm == 0xCB) *(char*)0=0;
    }

    /***********
     * Print opcodes
     */
    @trusted
    void print()
    {
        printf("---\n");
        for (code* c = head; c; c = c.next)
            printf("%02x\n", c.Iop);
    }
}
