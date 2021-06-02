/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1987-1995 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cg87.d, backend/cg87.d)
 */

module dmd.backend.cg87;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.codebuilder;
import dmd.backend.mem;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.evalu8 : el_toldoubled;

extern (C++):

nothrow:
@safe:

// NOTE: this could be a TLS global which would allow this variable to be used in
//       a multi-threaded version of the backend
__gshared Globals87 global87;

private:

int REGSIZE();

private extern (D) uint mask(uint m) { return 1 << m; }
void callcdxxx(ref CodeBuilder cdb, elem *e, regm_t *pretregs, OPER op);


// Constants that the 8087 supports directly
// BUG: rewrite for 80 bit long doubles
enum PI            = 3.14159265358979323846;
enum LOG2          = 0.30102999566398119521;
enum LN2           = 0.6931471805599453094172321;
enum LOG2T         = 3.32192809488736234787;
enum LOG2E         = 1.4426950408889634074;   // 1/LN2

enum FWAIT = 0x9B;            // FWAIT opcode

/* Mark variable referenced by e as not a register candidate            */
@trusted
uint notreg(elem* e) { return e.EV.Vsym.Sflags &= ~GTregcand; }

/* Generate the appropriate ESC instruction     */
ubyte ESC(uint MF, uint b) { return cast(ubyte)(0xD8 + (MF << 1) + b); }
enum
{   // Values for MF
    MFfloat         = 0,
    MFlong          = 1,
    MFdouble        = 2,
    MFword          = 3
}

/*********************************
 */

struct Dconst
{
    int round;
    Symbol *roundto0;
    Symbol *roundtonearest;
}

private __gshared Dconst oldd;

enum NDPP = 0;       // print out debugging info

@trusted
bool NOSAHF() { return I64 || config.fpxmmregs; }     // can't use SAHF instruction

enum CW_roundto0 = 0xFBF;
enum CW_roundtonearest = 0x3BF;


/**********************************
 * When we need to temporarilly save 8087 registers, we record information
 * about the save into an array of NDP structs.
 */

@trusted
private void getlvalue87(ref CodeBuilder cdb,code *pcs,elem *e,regm_t keepmsk)
{
    // the x87 instructions cannot read XMM registers
    if (e.Eoper == OPvar || e.Eoper == OPrelconst)
        e.EV.Vsym.Sflags &= ~GTregcand;

    getlvalue(cdb, pcs, e, keepmsk);
    if (ADDFWAIT())
        pcs.Iflags |= CFwait;
    if (I32)
        pcs.Iflags &= ~CFopsize;
    else if (I64)
        pcs.Irex &= ~REX_W;
}

/****************************************
 * Store/load to ndp save location i
 */

@trusted
private void ndp_fstp(ref CodeBuilder cdb, int i, tym_t ty)
{
    switch (tybasic(ty))
    {
        case TYfloat:
        case TYifloat:
        case TYcfloat:
            cdb.genc1(0xD9,modregrm(2,3,BPRM),FLndp,i); // FSTP m32real i[BP]
            break;

        case TYdouble:
        case TYdouble_alias:
        case TYidouble:
        case TYcdouble:
            cdb.genc1(0xDD,modregrm(2,3,BPRM),FLndp,i); // FSTP m64real i[BP]
            break;

        case TYldouble:
        case TYildouble:
        case TYcldouble:
            cdb.genc1(0xDB,modregrm(2,7,BPRM),FLndp,i); // FSTP m80real i[BP]
            break;

        default:
            assert(0);
    }
}

@trusted
private void ndp_fld(ref CodeBuilder cdb, int i, tym_t ty)
{
    switch (tybasic(ty))
    {
        case TYfloat:
        case TYifloat:
        case TYcfloat:
            cdb.genc1(0xD9,modregrm(2,0,BPRM),FLndp,i);
            break;

        case TYdouble:
        case TYdouble_alias:
        case TYidouble:
        case TYcdouble:
            cdb.genc1(0xDD,modregrm(2,0,BPRM),FLndp,i);
            break;

        case TYldouble:
        case TYildouble:
        case TYcldouble:
            cdb.genc1(0xDB,modregrm(2,5,BPRM),FLndp,i); // FLD m80real i[BP]
            break;

        default:
            assert(0);
    }
}

/**************************
 * Return index of empty slot in global87.save[].
 */

@trusted
private int getemptyslot()
{
    int i;

    for (i = 0; i < global87.save.length; ++i)
        if (global87.save[i].e == null)
            return i;

    global87.save.push(NDP());
    return i;
}

/*********************************
 * Pop 8087 stack.
 */

void pop87() { pop87(__LINE__, __FILE__); }

@trusted
void pop87(int line, const(char)* file)
{
    int i;

    if (NDPP)
        printf("pop87(%s(%d): stackused=%d)\n", file, line, global87.stackused);

    --global87.stackused;
    assert(global87.stackused >= 0);
    for (i = 0; i < global87.stack.length - 1; i++)
        global87.stack[i] = global87.stack[i + 1];
    // end of stack is nothing
    global87.stack[$ - 1] = NDP();
}


/*******************************
 * Push 8087 stack. Generate and return any code
 * necessary to preserve anything that might run off the end of the stack.
 */

void push87(ref CodeBuilder cdb) { push87(cdb,__LINE__,__FILE__); }

@trusted
void push87(ref CodeBuilder cdb, int line, const(char)* file)
{
    // if we would lose the top register off of the stack
    if (global87.stack[7].e != null)
    {
        int i = getemptyslot();
        global87.save[i] = global87.stack[7];
        cdb.genf2(0xD9,0xF6);                         // FDECSTP
        genfwait(cdb);
        ndp_fstp(cdb, i, global87.stack[7].e.Ety);       // FSTP i[BP]
        assert(global87.stackused == 8);
        if (NDPP) printf("push87() : overflow\n");
    }
    else
    {
        if (NDPP) printf("push87(%s(%d): %d)\n", file, line, global87.stackused);
        global87.stackused++;
        assert(global87.stackused <= 8);
    }
    // Shift the stack up
    for (int i = 7; i > 0; i--)
        global87.stack[i] = global87.stack[i - 1];
    global87.stack[0] = NDP();
}

/*****************************
 * Note elem e as being in ST(i) as being a value we want to keep.
 */

void note87(elem *e, uint offset, int i)
{
    note87(e, offset, i, __LINE__);
}

@trusted
void note87(elem *e, uint offset, int i, int linnum)
{
    if (NDPP)
        printf("note87(e = %p.%d, i = %d, stackused = %d, line = %d)\n",e,offset,i,global87.stackused,linnum);

    static if (0)
    {
        if (global87.stack[i].e)
            printf("global87.stack[%d].e = %p\n",i,global87.stack[i].e);
    }

    debug if (i >= global87.stackused)
    {
        printf("note87(e = %p.%d, i = %d, stackused = %d, line = %d)\n",e,offset,i,global87.stackused,linnum);
        elem_print(e);
    }
    assert(i < global87.stackused);

    while (e.Eoper == OPcomma)
        e = e.EV.E2;
    global87.stack[i].e = e;
    global87.stack[i].offset = offset;
}

/****************************************************
 * Exchange two entries in 8087 stack.
 */

@trusted
void xchg87(int i, int j)
{
    NDP save;

    save = global87.stack[i];
    global87.stack[i] = global87.stack[j];
    global87.stack[j] = save;
}

/****************************
 * Make sure that elem e is in register ST(i). Reload it if necessary.
 * Input:
 *      i       0..3    8087 register number
 *      flag    1       don't bother with FXCH
 */

private void makesure87(ref CodeBuilder cdb,elem *e,uint offset,int i,uint flag)
{
    makesure87(cdb,e,offset,i,flag,__LINE__);
}

@trusted
private void makesure87(ref CodeBuilder cdb,elem *e,uint offset,int i,uint flag,int linnum)
{
    debug if (NDPP) printf("makesure87(e=%p, offset=%d, i=%d, flag=%d, line=%d)\n",e,offset,i,flag,linnum);

    while (e.Eoper == OPcomma)
        e = e.EV.E2;
    assert(e && i < 4);
L1:
    if (global87.stack[i].e != e || global87.stack[i].offset != offset)
    {
        debug if (global87.stack[i].e)
            printf("global87.stack[%d].e = %p, .offset = %d\n",i,global87.stack[i].e,global87.stack[i].offset);

        assert(global87.stack[i].e == null);
        int j;
        for (j = 0; 1; j++)
        {
            if (j >= global87.save.length && e.Eoper == OPcomma)
            {
                e = e.EV.E2;              // try right side
                goto L1;
            }

            debug if (j >= global87.save.length)
                printf("e = %p, global87.save.length = %llu\n",e, cast(ulong) global87.save.length);

            assert(j < global87.save.length);
            //printf("\tglobal87.save[%d] = %p, .offset = %d\n", j, global87.save[j].e, global87.save[j].offset);
            if (e == global87.save[j].e && offset == global87.save[j].offset)
                break;
        }
        push87(cdb);
        genfwait(cdb);
        ndp_fld(cdb, j, e.Ety);         // FLD j[BP]
        if (!(flag & 1))
        {
            while (i != 0)
            {
                cdb.genf2(0xD9,0xC8 + i);       // FXCH ST(i)
                i--;
            }
        }
        global87.save[j] = NDP();               // back in 8087
    }
    //global87.stack[i].e = null;
}

/****************************
 * Save in memory any values in the 8087 that we want to keep.
 */

@trusted
void save87(ref CodeBuilder cdb)
{
    bool any = false;
    while (global87.stack[0].e && global87.stackused)
    {
        // Save it
        int i = getemptyslot();
        if (NDPP) printf("saving %p in temporary global87.save[%d]\n",global87.stack[0].e,i);
        global87.save[i] = global87.stack[0];

        genfwait(cdb);
        ndp_fstp(cdb,i,global87.stack[0].e.Ety); // FSTP i[BP]
        pop87();
        any = true;
    }
    if (any)                          // if any stores
        genfwait(cdb);   // wait for last one to finish
}

/******************************************
 * Save any noted values that would be destroyed by n pushes
 */

@trusted
void save87regs(ref CodeBuilder cdb, uint n)
{
    assert(n <= 7);
    uint j = 8 - n;
    if (global87.stackused > j)
    {
        for (uint k = 8; k > j; k--)
        {
            cdb.genf2(0xD9,0xF6);     // FDECSTP
            genfwait(cdb);
            if (k <= global87.stackused)
            {
                int i = getemptyslot();
                ndp_fstp(cdb, i, global87.stack[k - 1].e.Ety);   // FSTP i[BP]
                global87.save[i] = global87.stack[k - 1];
                global87.stack[k - 1] = NDP();
            }
        }

        for (uint k = 8; k > j; k--)
        {
            if (k > global87.stackused)
            {   cdb.genf2(0xD9,0xF7); // FINCSTP
                genfwait(cdb);
            }
        }
        global87.stackused = j;
    }
}

/*****************************************************
 * Save/restore ST0 or ST01
 */

@trusted
void gensaverestore87(regm_t regm, ref CodeBuilder cdbsave, ref CodeBuilder cdbrestore)
{
    //printf("gensaverestore87(%s)\n", regm_str(regm));
    assert(regm == mST0 || regm == mST01);

    int i = getemptyslot();
    global87.save[i].e = el_calloc();       // this blocks slot [i] for the life of this function
    ndp_fstp(cdbsave, i, TYldouble);

    CodeBuilder cdb2a;
    cdb2a.ctor();
    ndp_fld(cdb2a, i, TYldouble);

    if (regm == mST01)
    {
        int j = getemptyslot();
        global87.save[j].e = el_calloc();
        ndp_fstp(cdbsave, j, TYldouble);
        ndp_fld(cdbrestore, j, TYldouble);
    }

    cdbrestore.append(cdb2a);
}

/*************************************
 * Find which, if any, slot on stack holds elem e.
 */

@trusted
private int cse_get(elem *e, uint offset)
{
    int i;

    for (i = 0; 1; i++)
    {
        if (i == global87.stackused)
        {
            i = -1;
            //printf("cse not found\n");
            //elem_print(e);
            break;
        }
        if (global87.stack[i].e == e &&
            global87.stack[i].offset == offset)
        {   //printf("cse found %d\n",i);
            //elem_print(e);
            break;
        }
    }
    return i;
}

/*************************************
 * Reload common subexpression.
 */

void comsub87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    //printf("comsub87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    // Look on 8087 stack
    int i = cse_get(e, 0);

    if (tycomplex(e.Ety))
    {
        uint sz = tysize(e.Ety);
        int j = cse_get(e, sz / 2);
        if (i >= 0 && j >= 0)
        {
            push87(cdb);
            push87(cdb);
            cdb.genf2(0xD9,0xC0 + i);         // FLD ST(i)
            cdb.genf2(0xD9,0xC0 + j + 1);     // FLD ST(j + 1)
            fixresult_complex87(cdb,e,mST01,pretregs);
        }
        else
            // Reload
            loaddata(cdb,e,pretregs);
    }
    else
    {
        if (i >= 0)
        {
            push87(cdb);
            cdb.genf2(0xD9,0xC0 + i); // FLD ST(i)
            if (*pretregs & XMMREGS)
                fixresult87(cdb,e,mST0,pretregs);
            else
                fixresult(cdb,e,mST0,pretregs);
        }
        else
            // Reload
            loaddata(cdb,e,pretregs);
    }
}


/*******************************
 * Decide if we need to gen an FWAIT.
 */

void genfwait(ref CodeBuilder cdb)
{
    if (ADDFWAIT())
        cdb.gen1(FWAIT);
}


/***************************
 * Put the 8087 flags into the CPU flags.
 */

@trusted
private void cg87_87topsw(ref CodeBuilder cdb)
{
    /* Note that SAHF is not available on some early I64 processors
     * and will cause a seg fault
     */
    assert(!NOSAHF);
    getregs(cdb,mAX);
    if (config.target_cpu >= TARGET_80286)
        cdb.genf2(0xDF,0xE0);             // FSTSW AX
    else
    {
        cdb.genfltreg(0xD8+5,7,0);        // FSTSW floatreg[BP]
        genfwait(cdb);          // FWAIT
        cdb.genfltreg(0x8A,4,1);          // MOV AH,floatreg+1[BP]
    }
    cdb.gen1(0x9E);                       // SAHF
    code_orflag(cdb.last(),CFpsw);
}

/*****************************************
 * Jump to ctarget if condition code C2 is set.
 */

@trusted
private void genjmpifC2(ref CodeBuilder cdb, code *ctarget)
{
    if (NOSAHF)
    {
        getregs(cdb,mAX);
        cdb.genf2(0xDF,0xE0);                                    // FSTSW AX
        cdb.genc2(0xF6,modregrm(3,0,4),4);                       // TEST AH,4
        genjmp(cdb, JNE, FLcode, cast(block *)ctarget); // JNE ctarget
    }
    else
    {
        cg87_87topsw(cdb);
        genjmp(cdb, JP, FLcode, cast(block *)ctarget);  // JP ctarget
    }
}

/***************************
 * Set the PSW based on the state of ST0.
 * Input:
 *      pop     if stack should be popped after test
 * Returns:
 *      start of code appended to c.
 */

@trusted
private void genftst(ref CodeBuilder cdb,elem *e,int pop)
{
    if (NOSAHF)
    {
        push87(cdb);
        cdb.gen2(0xD9,0xEE);          // FLDZ
        cdb.gen2(0xDF,0xE9);          // FUCOMIP ST1
        pop87();
        if (pop)
        {
            cdb.genf2(0xDD,modregrm(3,3,0)); // FPOP
            pop87();
        }
    }
    else if (config.flags4 & CFG4fastfloat)  // if fast floating point
    {
        cdb.genf2(0xD9,0xE4);                // FTST
        cg87_87topsw(cdb);                   // put 8087 flags in CPU flags
        if (pop)
        {
            cdb.genf2(0xDD,modregrm(3,3,0)); // FPOP
            pop87();
        }
    }
    else if (config.target_cpu >= TARGET_80386)
    {
        // FUCOMP doesn't raise exceptions on QNANs, unlike FTST
        push87(cdb);
        cdb.gen2(0xD9,0xEE);                 // FLDZ
        cdb.gen2(pop ? 0xDA : 0xDD,0xE9);    // FUCOMPP / FUCOMP
        pop87();
        if (pop)
            pop87();
        cg87_87topsw(cdb);                   // put 8087 flags in CPU flags
    }
    else
    {
        // Call library function which does not raise exceptions
        regm_t regm = 0;

        callclib(cdb,e,CLIB.ftest,&regm,0);
        if (pop)
        {
            cdb.genf2(0xDD,modregrm(3,3,0)); // FPOP
            pop87();
        }
    }
}

/*************************************
 * Determine if there is a special 8087 instruction to load
 * constant e.
 * Input:
 *      im      0       load real part
 *              1       load imaginary part
 * Returns:
 *      opcode if found
 *      0 if not
 */

@trusted
ubyte loadconst(elem *e, int im)
{
    elem_debug(e);
    assert(im == 0 || im == 1);

    immutable float[7] fval =
        [0.0,1.0,PI,LOG2T,LOG2E,LOG2,LN2];
    immutable double[7] dval =
        [0.0,1.0,PI,LOG2T,LOG2E,LOG2,LN2];

    static if (real.sizeof < 10)
    {
        import dmd.root.longdouble;
        immutable targ_ldouble[7] ldval =
        [ld_zero,ld_one,ld_pi,ld_log2t,ld_log2e,ld_log2,ld_ln2];
    }
    else
    {
        enum M_PI_L        = 0x1.921fb54442d1846ap+1L;       // 3.14159 fldpi
        enum M_LOG2T_L     = 0x1.a934f0979a3715fcp+1L;       // 3.32193 fldl2t
        enum M_LOG2E_L     = 0x1.71547652b82fe178p+0L;       // 1.4427 fldl2e
        enum M_LOG2_L      = 0x1.34413509f79fef32p-2L;       // 0.30103 fldlg2
        enum M_LN2_L       = 0x1.62e42fefa39ef358p-1L;       // 0.693147 fldln2
        immutable targ_ldouble[7] ldval =
        [0.0,1.0,M_PI_L,M_LOG2T_L,M_LOG2E_L,M_LOG2_L,M_LN2_L];
    }

    immutable ubyte[7 + 1] opcode =
        /* FLDZ,FLD1,FLDPI,FLDL2T,FLDL2E,FLDLG2,FLDLN2,0 */
        [0xEE,0xE8,0xEB,0xE9,0xEA,0xEC,0xED,0];

    int i;
    targ_float f;
    targ_double d;
    targ_ldouble ld;
    int sz;
    int zero;
    void *p;
    immutable ubyte[16] zeros;

    if (im == 0)
    {
        switch (tybasic(e.Ety))
        {
            case TYfloat:
            case TYifloat:
            case TYcfloat:
                f = e.EV.Vfloat;
                sz = 4;
                p = &f;
                break;

            case TYdouble:
            case TYdouble_alias:
            case TYidouble:
            case TYcdouble:
                d = e.EV.Vdouble;
                sz = 8;
                p = &d;
                break;

            case TYldouble:
            case TYildouble:
            case TYcldouble:
                ld = e.EV.Vldouble;
                sz = 10;
                p = &ld;
                break;

            default:
                assert(0);
        }
    }
    else
    {
        switch (tybasic(e.Ety))
        {
            case TYcfloat:
                f = e.EV.Vcfloat.im;
                sz = 4;
                p = &f;
                break;

            case TYcdouble:
                d = e.EV.Vcdouble.im;
                sz = 8;
                p = &d;
                break;

            case TYcldouble:
                ld = e.EV.Vcldouble.im;
                sz = 10;
                p = &ld;
                break;

            default:
                assert(0);
        }
    }

    // Note that for this purpose, -0 is not regarded as +0,
    // since FLDZ loads a +0
    assert(sz <= zeros.length);
    zero = (memcmp(p, zeros.ptr, sz) == 0);
    if (zero && config.target_cpu >= TARGET_PentiumPro)
        return 0xEE;            // FLDZ is the only one with 1 micro-op

    // For some reason, these instructions take more clocks
    if (config.flags4 & CFG4speed && config.target_cpu >= TARGET_Pentium)
        return 0;

    if (zero)
        return 0xEE;

    for (i = 1; i < fval.length; i++)
    {
        switch (sz)
        {
            case 4:
                if (fval[i] != f)
                    continue;
                break;
            case 8:
                if (dval[i] != d)
                    continue;
                break;
            case 10:
                if (ldval[i] != ld)
                    continue;
                break;
            default:
                assert(0);
        }
        break;
    }
    return opcode[i];
}

/******************************
 * Given the result of an expression is in retregs,
 * generate necessary code to return result in *pretregs.
 */

@trusted
void fixresult87(ref CodeBuilder cdb,elem *e,regm_t retregs,regm_t *pretregs, bool isReturnValue = false)
{
    //printf("fixresult87(e = %p, retregs = x%x, *pretregs = x%x)\n", e,retregs,*pretregs);
    //printf("fixresult87(e = %p, retregs = %s, *pretregs = %s)\n", e,regm_str(retregs),regm_str(*pretregs));
    assert(!*pretregs || retregs);

    if ((*pretregs | retregs) & mST01)
    {
        fixresult_complex87(cdb, e, retregs, pretregs, isReturnValue);
        return;
    }

    tym_t tym = tybasic(e.Ety);
    uint sz = _tysize[tym];
    //printf("tym = x%x, sz = %d\n", tym, sz);

    /* if retregs needs to be transferred into the 8087 */
    if (*pretregs & mST0 && retregs & (mBP | ALLREGS))
    {
        debug if (sz > DOUBLESIZE)
        {
            elem_print(e);
            printf("retregs = %s\n", regm_str(retregs));
        }
        assert(sz <= DOUBLESIZE);
        if (!I16)
        {

            if (*pretregs & mPSW)
            {   // Set flags
                regm_t r = retregs | mPSW;
                fixresult(cdb,e,retregs,&r);
            }
            push87(cdb);
            if (sz == REGSIZE || (I64 && sz == 4))
            {
                const reg = findreg(retregs);
                cdb.genfltreg(STO,reg,0);           // MOV fltreg,reg
                cdb.genfltreg(0xD9,0,0);            // FLD float ptr fltreg
            }
            else
            {
                const msreg = findregmsw(retregs);
                const lsreg = findreglsw(retregs);
                cdb.genfltreg(STO,lsreg,0);         // MOV fltreg,lsreg
                cdb.genfltreg(STO,msreg,4);         // MOV fltreg+4,msreg
                cdb.genfltreg(0xDD,0,0);            // FLD double ptr fltreg
            }
        }
        else
        {
            regm_t regm = (sz == FLOATSIZE) ? FLOATREGS : DOUBLEREGS;
            regm |= *pretregs & mPSW;
            fixresult(cdb,e,retregs,&regm);
            regm = 0;           // don't worry about result from CLIB.xxx
            callclib(cdb,e,
                    ((sz == FLOATSIZE) ? CLIB.fltto87 : CLIB.dblto87),
                    &regm,0);
        }
    }
    else if (*pretregs & (mBP | ALLREGS) && retregs & mST0)
    {
        assert(sz <= DOUBLESIZE);
        uint mf = (sz == FLOATSIZE) ? MFfloat : MFdouble;
        if (*pretregs & mPSW && !(retregs & mPSW))
            genftst(cdb,e,0);
        // FSTP floatreg
        pop87();
        cdb.genfltreg(ESC(mf,1),3,0);
        genfwait(cdb);
        reg_t reg;
        allocreg(cdb,pretregs,&reg,(sz == FLOATSIZE) ? TYfloat : TYdouble);
        if (sz == FLOATSIZE)
        {
            if (!I16)
                cdb.genfltreg(LOD,reg,0);
            else
            {
                cdb.genfltreg(LOD,reg,REGSIZE);
                cdb.genfltreg(LOD,findreglsw(*pretregs),0);
            }
        }
        else
        {   assert(sz == DOUBLESIZE);
            if (I16)
            {
                cdb.genfltreg(LOD,AX,6);
                cdb.genfltreg(LOD,BX,4);
                cdb.genfltreg(LOD,CX,2);
                cdb.genfltreg(LOD,DX,0);
            }
            else if (I32)
            {
                cdb.genfltreg(LOD,reg,REGSIZE);
                cdb.genfltreg(LOD,findreglsw(*pretregs),0);
            }
            else // I64
            {
                cdb.genfltreg(LOD,reg,0);
                code_orrex(cdb.last(), REX_W);
            }
        }
    }
    else if (*pretregs == 0 && retregs == mST0)
    {
        cdb.genf2(0xDD,modregrm(3,3,0));    // FPOP
        pop87();
    }
    else
    {
        if (*pretregs & mPSW)
        {
            if (!(retregs & mPSW))
            {
                genftst(cdb,e,!(*pretregs & (mST0 | XMMREGS))); // FTST
            }
        }
        if (*pretregs & mST0 && retregs & XMMREGS)
        {
            assert(sz <= DOUBLESIZE);
            uint mf = (sz == FLOATSIZE) ? MFfloat : MFdouble;
            // MOVD floatreg,XMM?
            const reg = findreg(retregs);
            cdb.genxmmreg(xmmstore(tym),reg,0,tym);
            push87(cdb);
            cdb.genfltreg(ESC(mf,1),0,0);                 // FLD float/double ptr fltreg
        }
        else if (retregs & mST0 && *pretregs & XMMREGS)
        {
            assert(sz <= DOUBLESIZE);
            uint mf = (sz == FLOATSIZE) ? MFfloat : MFdouble;
            // FSTP floatreg
            pop87();
            cdb.genfltreg(ESC(mf,1),3,0);
            genfwait(cdb);
            // MOVD XMM?,floatreg
            reg_t reg;
            allocreg(cdb,pretregs,&reg,(sz == FLOATSIZE) ? TYfloat : TYdouble);
            cdb.genxmmreg(xmmload(tym),reg,0,tym);
        }
        else
            assert(!(*pretregs & mST0) || (retregs & mST0));
    }
    if (*pretregs & mST0)
        note87(e,0,0);
}

/********************************
 * Generate in-line 8087 code for the following operators:
 *      add
 *      min
 *      mul
 *      div
 *      cmp
 */

// Reverse the order that the op is done in
__gshared const ubyte[9] oprev = [ cast(ubyte)-1,0,1,2,3,5,4,7,6 ];

@trusted
void orth87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    //printf("orth87(+e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    // we could be evaluating / for side effects only
    assert(*pretregs != 0);

    elem *e1 = e.EV.E1;
    elem *e2 = e.EV.E2;
    uint sz2 = tysize(e1.Ety);
    if (tycomplex(e1.Ety))
        sz2 /= 2;

    OPER eoper = e.Eoper;
    if (eoper == OPmul && e2.Eoper == OPconst && el_toldoubled(e.EV.E2) == 2.0L)
    {
        // Perform "mul 2.0" as fadd ST(0), ST
        regm_t retregs = mST0;
        codelem(cdb,e1,&retregs,false);
        cdb.genf2(0xDC, 0xC0);                    // fadd ST(0), ST;
        fixresult87(cdb,e,mST0,pretregs);         // result is in ST(0).
        freenode(e2);
        return;
    }

    uint op;
    if (OTrel(eoper))
        eoper = OPeqeq;
    bool imaginary;
    static uint X(OPER op, uint ty1, uint ty2) { return (op << 16) + ty1 * 256 + ty2; }
    switch (X(eoper, tybasic(e1.Ety), tybasic(e2.Ety)))
    {
        case X(OPadd, TYfloat, TYfloat):
        case X(OPadd, TYdouble, TYdouble):
        case X(OPadd, TYdouble_alias, TYdouble_alias):
        case X(OPadd, TYldouble, TYldouble):
        case X(OPadd, TYldouble, TYdouble):
        case X(OPadd, TYdouble, TYldouble):
        case X(OPadd, TYifloat, TYifloat):
        case X(OPadd, TYidouble, TYidouble):
        case X(OPadd, TYildouble, TYildouble):
            op = 0;                             // FADDP
            break;

        case X(OPmin, TYfloat, TYfloat):
        case X(OPmin, TYdouble, TYdouble):
        case X(OPmin, TYdouble_alias, TYdouble_alias):
        case X(OPmin, TYldouble, TYldouble):
        case X(OPmin, TYldouble, TYdouble):
        case X(OPmin, TYdouble, TYldouble):
        case X(OPmin, TYifloat, TYifloat):
        case X(OPmin, TYidouble, TYidouble):
        case X(OPmin, TYildouble, TYildouble):
            op = 4;                             // FSUBP
            break;

        case X(OPmul, TYfloat, TYfloat):
        case X(OPmul, TYdouble, TYdouble):
        case X(OPmul, TYdouble_alias, TYdouble_alias):
        case X(OPmul, TYldouble, TYldouble):
        case X(OPmul, TYldouble, TYdouble):
        case X(OPmul, TYdouble, TYldouble):
        case X(OPmul, TYifloat, TYifloat):
        case X(OPmul, TYidouble, TYidouble):
        case X(OPmul, TYildouble, TYildouble):
        case X(OPmul, TYfloat, TYifloat):
        case X(OPmul, TYdouble, TYidouble):
        case X(OPmul, TYldouble, TYildouble):
        case X(OPmul, TYifloat, TYfloat):
        case X(OPmul, TYidouble, TYdouble):
        case X(OPmul, TYildouble, TYldouble):
            op = 1;                             // FMULP
            break;

        case X(OPdiv, TYfloat, TYfloat):
        case X(OPdiv, TYdouble, TYdouble):
        case X(OPdiv, TYdouble_alias, TYdouble_alias):
        case X(OPdiv, TYldouble, TYldouble):
        case X(OPdiv, TYldouble, TYdouble):
        case X(OPdiv, TYdouble, TYldouble):
        case X(OPdiv, TYifloat, TYifloat):
        case X(OPdiv, TYidouble, TYidouble):
        case X(OPdiv, TYildouble, TYildouble):
            op = 6;                             // FDIVP
            break;

        case X(OPmod, TYfloat, TYfloat):
        case X(OPmod, TYdouble, TYdouble):
        case X(OPmod, TYdouble_alias, TYdouble_alias):
        case X(OPmod, TYldouble, TYldouble):
        case X(OPmod, TYfloat, TYifloat):
        case X(OPmod, TYdouble, TYidouble):
        case X(OPmod, TYldouble, TYildouble):
        case X(OPmod, TYifloat, TYifloat):
        case X(OPmod, TYidouble, TYidouble):
        case X(OPmod, TYildouble, TYildouble):
        case X(OPmod, TYifloat, TYfloat):
        case X(OPmod, TYidouble, TYdouble):
        case X(OPmod, TYildouble, TYldouble):
            op = cast(uint) -1;
            break;

        case X(OPeqeq, TYfloat, TYfloat):
        case X(OPeqeq, TYdouble, TYdouble):
        case X(OPeqeq, TYdouble_alias, TYdouble_alias):
        case X(OPeqeq, TYldouble, TYldouble):
        case X(OPeqeq, TYifloat, TYifloat):
        case X(OPeqeq, TYidouble, TYidouble):
        case X(OPeqeq, TYildouble, TYildouble):
        {
            assert(OTrel(e.Eoper));
            assert((*pretregs & mST0) == 0);
            regm_t retregs = mST0;
            codelem(cdb,e1,&retregs,false);
            note87(e1,0,0);
            regm_t resregm = mPSW;

            if (rel_exception(e.Eoper) || config.flags4 & CFG4fastfloat)
            {
                if (e2.Eoper == OPconst && !boolres(e2))
                {
                    if (NOSAHF)
                    {
                        push87(cdb);
                        cdb.gen2(0xD9,0xEE);             // FLDZ
                        cdb.gen2(0xDF,0xF1);             // FCOMIP ST1
                        pop87();
                    }
                    else
                    {
                        cdb.genf2(0xD9,0xE4);            // FTST
                        cg87_87topsw(cdb);
                    }
                    cdb.genf2(0xDD,modregrm(3,3,0));     // FPOP
                    pop87();
                }
                else if (NOSAHF)
                {
                    note87(e1,0,0);
                    load87(cdb,e2,0,&retregs,e1,-1);
                    makesure87(cdb,e1,0,1,0);
                    resregm = 0;
                    //cdb.genf2(0xD9,0xC8 + 1);          // FXCH ST1
                    cdb.gen2(0xDF,0xF1);                 // FCOMIP ST1
                    pop87();
                    cdb.genf2(0xDD,modregrm(3,3,0));     // FPOP
                    pop87();
                }
                else
                {
                    load87(cdb,e2, 0, pretregs, e1, 3);  // FCOMPP
                }
            }
            else
            {
                if (e2.Eoper == OPconst && !boolres(e2) &&
                    config.target_cpu < TARGET_80386)
                {
                    regm_t regm = 0;

                    callclib(cdb,e,CLIB.ftest0,&regm,0);
                    pop87();
                }
                else
                {
                    note87(e1,0,0);
                    load87(cdb,e2,0,&retregs,e1,-1);
                    makesure87(cdb,e1,0,1,0);
                    resregm = 0;
                    if (NOSAHF)
                    {
                        cdb.gen2(0xDF,0xE9);              // FUCOMIP ST1
                        pop87();
                        cdb.genf2(0xDD,modregrm(3,3,0));  // FPOP
                        pop87();
                    }
                    else if (config.target_cpu >= TARGET_80386)
                    {
                        cdb.gen2(0xDA,0xE9);      // FUCOMPP
                        cg87_87topsw(cdb);
                        pop87();
                        pop87();
                    }
                    else
                        // Call a function instead so that exceptions
                        // are not generated.
                        callclib(cdb,e,CLIB.fcompp,&resregm,0);
                }
            }

            freenode(e2);
            return;
        }

        case X(OPadd, TYcfloat, TYcfloat):
        case X(OPadd, TYcdouble, TYcdouble):
        case X(OPadd, TYcldouble, TYcldouble):
        case X(OPadd, TYcfloat, TYfloat):
        case X(OPadd, TYcdouble, TYdouble):
        case X(OPadd, TYcldouble, TYldouble):
        case X(OPadd, TYfloat, TYcfloat):
        case X(OPadd, TYdouble, TYcdouble):
        case X(OPadd, TYldouble, TYcldouble):
            goto Lcomplex;

        case X(OPadd, TYifloat, TYcfloat):
        case X(OPadd, TYidouble, TYcdouble):
        case X(OPadd, TYildouble, TYcldouble):
            goto Lcomplex2;

        case X(OPmin, TYcfloat, TYcfloat):
        case X(OPmin, TYcdouble, TYcdouble):
        case X(OPmin, TYcldouble, TYcldouble):
        case X(OPmin, TYcfloat, TYfloat):
        case X(OPmin, TYcdouble, TYdouble):
        case X(OPmin, TYcldouble, TYldouble):
        case X(OPmin, TYfloat, TYcfloat):
        case X(OPmin, TYdouble, TYcdouble):
        case X(OPmin, TYldouble, TYcldouble):
            goto Lcomplex;

        case X(OPmin, TYifloat, TYcfloat):
        case X(OPmin, TYidouble, TYcdouble):
        case X(OPmin, TYildouble, TYcldouble):
            goto Lcomplex2;

        case X(OPmul, TYcfloat, TYcfloat):
        case X(OPmul, TYcdouble, TYcdouble):
        case X(OPmul, TYcldouble, TYcldouble):
            goto Lcomplex;

        case X(OPdiv, TYcfloat, TYcfloat):
        case X(OPdiv, TYcdouble, TYcdouble):
        case X(OPdiv, TYcldouble, TYcldouble):
        case X(OPdiv, TYfloat, TYcfloat):
        case X(OPdiv, TYdouble, TYcdouble):
        case X(OPdiv, TYldouble, TYcldouble):
        case X(OPdiv, TYifloat, TYcfloat):
        case X(OPdiv, TYidouble, TYcdouble):
        case X(OPdiv, TYildouble, TYcldouble):
            goto Lcomplex;

        case X(OPdiv, TYifloat,   TYfloat):
        case X(OPdiv, TYidouble,  TYdouble):
        case X(OPdiv, TYildouble, TYldouble):
            op = 6;                             // FDIVP
            break;

        Lcomplex:
        {
            loadComplex(cdb,e1);
            loadComplex(cdb,e2);
            makesure87(cdb, e1, sz2, 2, 0);
            makesure87(cdb, e1, 0, 3, 0);
            regm_t retregs = mST01;
            if (eoper == OPadd)
            {
                cdb.genf2(0xDE, 0xC0+2);    // FADDP ST(2),ST
                cdb.genf2(0xDE, 0xC0+2);    // FADDP ST(2),ST
                pop87();
                pop87();
            }
            else if (eoper == OPmin)
            {
                cdb.genf2(0xDE, 0xE8+2);    // FSUBP ST(2),ST
                cdb.genf2(0xDE, 0xE8+2);    // FSUBP ST(2),ST
                pop87();
                pop87();
            }
            else
            {
                int clib = eoper == OPmul ? CLIB.cmul : CLIB.cdiv;
                callclib(cdb, e, clib, &retregs, 0);
            }
            fixresult_complex87(cdb, e, retregs, pretregs);
            return;
        }

        Lcomplex2:
        {
            regm_t retregs = mST0;
            codelem(cdb,e1, &retregs, false);
            note87(e1, 0, 0);
            loadComplex(cdb,e2);
            makesure87(cdb, e1, 0, 2, 0);
            retregs = mST01;
            if (eoper == OPadd)
            {
                cdb.genf2(0xDE, 0xC0+2);   // FADDP ST(2),ST
            }
            else if (eoper == OPmin)
            {
                cdb.genf2(0xDE, 0xE8+2);   // FSUBP ST(2),ST
                cdb.genf2(0xD9, 0xE0);     // FCHS
            }
            else
                assert(0);
            pop87();
            cdb.genf2(0xD9, 0xC8 + 1);     // FXCH ST(1)
            fixresult_complex87(cdb, e, retregs, pretregs);
            return;
        }

        case X(OPeqeq, TYcfloat, TYcfloat):
        case X(OPeqeq, TYcdouble, TYcdouble):
        case X(OPeqeq, TYcldouble, TYcldouble):
        case X(OPeqeq, TYcfloat, TYifloat):
        case X(OPeqeq, TYcdouble, TYidouble):
        case X(OPeqeq, TYcldouble, TYildouble):
        case X(OPeqeq, TYcfloat, TYfloat):
        case X(OPeqeq, TYcdouble, TYdouble):
        case X(OPeqeq, TYcldouble, TYldouble):
        case X(OPeqeq, TYifloat, TYcfloat):
        case X(OPeqeq, TYidouble, TYcdouble):
        case X(OPeqeq, TYildouble, TYcldouble):
        case X(OPeqeq, TYfloat, TYcfloat):
        case X(OPeqeq, TYdouble, TYcdouble):
        case X(OPeqeq, TYldouble, TYcldouble):
        case X(OPeqeq, TYfloat, TYifloat):
        case X(OPeqeq, TYdouble, TYidouble):
        case X(OPeqeq, TYldouble, TYildouble):
        case X(OPeqeq, TYifloat, TYfloat):
        case X(OPeqeq, TYidouble, TYdouble):
        case X(OPeqeq, TYildouble, TYldouble):
        {
            loadComplex(cdb,e1);
            loadComplex(cdb,e2);
            makesure87(cdb, e1, sz2, 2, 0);
            makesure87(cdb, e1, 0, 3, 0);
            regm_t retregs = 0;
            callclib(cdb, e, CLIB.ccmp, &retregs, 0);
            return;
        }

        case X(OPadd, TYfloat, TYifloat):
        case X(OPadd, TYdouble, TYidouble):
        case X(OPadd, TYldouble, TYildouble):
        case X(OPadd, TYifloat, TYfloat):
        case X(OPadd, TYidouble, TYdouble):
        case X(OPadd, TYildouble, TYldouble):

        case X(OPmin, TYfloat, TYifloat):
        case X(OPmin, TYdouble, TYidouble):
        case X(OPmin, TYldouble, TYildouble):
        case X(OPmin, TYifloat, TYfloat):
        case X(OPmin, TYidouble, TYdouble):
        case X(OPmin, TYildouble, TYldouble):
        {
            regm_t retregs = mST0;
            codelem(cdb,e1, &retregs, false);
            note87(e1, 0, 0);
            codelem(cdb,e2, &retregs, false);
            makesure87(cdb, e1, 0, 1, 0);
            if (eoper == OPmin)
                cdb.genf2(0xD9, 0xE0);     // FCHS
            if (tyimaginary(e1.Ety))
                cdb.genf2(0xD9, 0xC8 + 1); // FXCH ST(1)
            retregs = mST01;
            fixresult_complex87(cdb, e, retregs, pretregs);
            return;
        }

        case X(OPadd, TYcfloat, TYifloat):
        case X(OPadd, TYcdouble, TYidouble):
        case X(OPadd, TYcldouble, TYildouble):
            op = 0;
            goto Lci;

        case X(OPmin, TYcfloat, TYifloat):
        case X(OPmin, TYcdouble, TYidouble):
        case X(OPmin, TYcldouble, TYildouble):
            op = 4;
            goto Lci;

        Lci:
        {
            loadComplex(cdb,e1);
            regm_t retregs = mST0;
            load87(cdb,e2,sz2,&retregs,e1,op);
            freenode(e2);
            retregs = mST01;
            makesure87(cdb, e1,0,1,0);
            fixresult_complex87(cdb,e, retregs, pretregs);
            return;
        }

        case X(OPmul, TYcfloat, TYfloat):
        case X(OPmul, TYcdouble, TYdouble):
        case X(OPmul, TYcldouble, TYldouble):
            imaginary = false;
            goto Lcmul;

        case X(OPmul, TYcfloat, TYifloat):
        case X(OPmul, TYcdouble, TYidouble):
        case X(OPmul, TYcldouble, TYildouble):
            imaginary = true;
        Lcmul:
        {
            loadComplex(cdb,e1);
            if (imaginary)
            {
                cdb.genf2(0xD9, 0xE0);          // FCHS
                cdb.genf2(0xD9,0xC8 + 1);       // FXCH ST(1)
                if (elemisone(e2))
                {
                    freenode(e2);
                    fixresult_complex87(cdb, e, mST01, pretregs);
                    return;
                }
            }
            regm_t retregs = mST0;
            codelem(cdb,e2, &retregs, false);
            makesure87(cdb, e1, sz2, 1, 0);
            makesure87(cdb, e1, 0, 2, 0);
            cdb.genf2(0xDC,0xC8 + 2);           // FMUL ST(2), ST
            cdb.genf2(0xDE,0xC8 + 1);           // FMULP ST(1), ST
            pop87();
            fixresult_complex87(cdb, e, mST01, pretregs);
            return;
        }

        case X(OPmul, TYfloat, TYcfloat):
        case X(OPmul, TYdouble, TYcdouble):
        case X(OPmul, TYldouble, TYcldouble):
            imaginary = false;
            goto Lcmul2;

        case X(OPmul, TYifloat, TYcfloat):
        case X(OPmul, TYidouble, TYcdouble):
        case X(OPmul, TYildouble, TYcldouble):
            imaginary = true;
        Lcmul2:
        {
            regm_t retregs = mST0;
            codelem(cdb,e1, &retregs, false);
            note87(e1, 0, 0);
            loadComplex(cdb,e2);
            makesure87(cdb, e1, 0, 2, 0);
            cdb.genf2(0xD9, imaginary ? 0xE0 : 0xC8 + 1); // FCHS / FXCH ST(1)
            cdb.genf2(0xD9,0xC8 + 2);        // FXCH ST(2)
            cdb.genf2(0xDC,0xC8 + 2);        // FMUL ST(2), ST
            cdb.genf2(0xDE,0xC8 + 1);        // FMULP ST(1), ST
            pop87();
            fixresult_complex87(cdb, e, mST01, pretregs);
            return;
        }

        case X(OPdiv, TYcfloat, TYfloat):
        case X(OPdiv, TYcdouble, TYdouble):
        case X(OPdiv, TYcldouble, TYldouble):
        {
            loadComplex(cdb,e1);
            regm_t retregs = mST0;
            codelem(cdb,e2, &retregs, false);
            makesure87(cdb, e1, sz2, 1, 0);
            makesure87(cdb, e1, 0, 2, 0);
            cdb.genf2(0xDC,0xF8 + 2);            // FDIV ST(2), ST
            cdb.genf2(0xDE,0xF8 + 1);            // FDIVP ST(1), ST
            pop87();
            fixresult_complex87(cdb, e, mST01, pretregs);
            return;
        }

        case X(OPdiv, TYcfloat, TYifloat):
        case X(OPdiv, TYcdouble, TYidouble):
        case X(OPdiv, TYcldouble, TYildouble):
        {
            loadComplex(cdb,e1);
            cdb.genf2(0xD9,0xC8 + 1);        // FXCH ST(1)
            xchg87(0, 1);
            cdb.genf2(0xD9, 0xE0);               // FCHS
            regm_t retregs = mST0;
            codelem(cdb,e2, &retregs, false);
            makesure87(cdb, e1, 0, 1, 0);
            makesure87(cdb, e1, sz2, 2, 0);
            cdb.genf2(0xDC,0xF8 + 2);        // FDIV ST(2), ST
            cdb.genf2(0xDE,0xF8 + 1);             // FDIVP ST(1), ST
            pop87();
            fixresult_complex87(cdb, e, mST01, pretregs);
            return;
        }

        case X(OPmod, TYcfloat, TYfloat):
        case X(OPmod, TYcdouble, TYdouble):
        case X(OPmod, TYcldouble, TYldouble):
        case X(OPmod, TYcfloat, TYifloat):
        case X(OPmod, TYcdouble, TYidouble):
        case X(OPmod, TYcldouble, TYildouble):
        {
            /*
                        fld     E1.re
                        fld     E1.im
                        fld     E2
                        fxch    ST(1)
                FM1:    fprem
                        fstsw   word ptr sw
                        fwait
                        mov     AH, byte ptr sw+1
                        jp      FM1
                        fxch    ST(2)
                FM2:    fprem
                        fstsw   word ptr sw
                        fwait
                        mov     AH, byte ptr sw+1
                        jp      FM2
                        fstp    ST(1)
                        fxch    ST(1)
             */
            loadComplex(cdb,e1);
            regm_t retregs = mST0;
            codelem(cdb,e2, &retregs, false);
            makesure87(cdb, e1, sz2, 1, 0);
            makesure87(cdb, e1, 0, 2, 0);
            cdb.genf2(0xD9, 0xC8 + 1);             // FXCH ST(1)

            cdb.gen2(0xD9, 0xF8);                  // FPREM
            code *cfm1 = cdb.last();
            genjmpifC2(cdb, cfm1);                 // JC2 FM1
            cdb.genf2(0xD9, 0xC8 + 2);             // FXCH ST(2)

            cdb.gen2(0xD9, 0xF8);                  // FPREM
            code *cfm2 = cdb.last();

            genjmpifC2(cdb, cfm2);                 // JC2 FM2
            cdb.genf2(0xDD,0xD8 + 1);              // FSTP ST(1)
            cdb.genf2(0xD9, 0xC8 + 1);             // FXCH ST(1)

            pop87();
            fixresult_complex87(cdb, e, mST01, pretregs);
            return;
        }

        default:

            debug
            elem_print(e);

            assert(0);
    }

    int reverse = 0;
    int e2oper = e2.Eoper;

    /* Move double-sized operand into the second position if there's a chance
     * it will allow combining a load with an operation (DMD Bugzilla 2905)
     */
    if ( ((tybasic(e1.Ety) == TYdouble)
          && ((e1.Eoper == OPvar) || (e1.Eoper == OPconst))
          && (tybasic(e2.Ety) != TYdouble)) ||
        (e1.Eoper == OPconst) ||
        (e1.Eoper == OPvar &&
         ((e1.Ety & (mTYconst | mTYimmutable) && !OTleaf(e2oper)) ||
          (e2oper == OPd_f &&
            (e2.EV.E1.Eoper == OPs32_d || e2.EV.E1.Eoper == OPs64_d || e2.EV.E1.Eoper == OPs16_d) &&
            e2.EV.E1.EV.E1.Eoper == OPvar
          ) ||
          ((e2oper == OPs32_d || e2oper == OPs64_d || e2oper == OPs16_d) &&
            e2.EV.E1.Eoper == OPvar
          )
         )
        )
       )
    {   // Reverse order of evaluation
        e1 = e.EV.E2;
        e2 = e.EV.E1;
        op = oprev[op + 1];
        reverse ^= 1;
    }

    regm_t retregs1 = mST0;
    codelem(cdb,e1,&retregs1,false);
    note87(e1,0,0);

    if (config.flags4 & CFG4fdivcall && e.Eoper == OPdiv)
    {
        regm_t retregs = mST0;
        load87(cdb,e2,0,&retregs,e1,-1);
        makesure87(cdb, e1,0,1,0);
        if (op == 7)                    // if reverse divide
            cdb.genf2(0xD9,0xC8 + 1);       // FXCH ST(1)
        callclib(cdb,e,CLIB.fdiv87,&retregs,0);
        pop87();
        regm_t resregm = mST0;
        freenode(e2);
        fixresult87(cdb,e,resregm,pretregs);
    }
    else if (e.Eoper == OPmod)
    {
        /*
         *              fld     tbyte ptr y
         *              fld     tbyte ptr x             // ST = x, ST1 = y
         *      FM1:    // We don't use fprem1 because for some inexplicable
         *              // reason we get -5 when we do _modulo(15, 10)
         *              fprem                           // ST = ST % ST1
         *              fstsw   word ptr sw
         *              fwait
         *              mov     AH,byte ptr sw+1        // get msb of status word in AH
         *              sahf                            // transfer to flags
         *              jp      FM1                     // continue till ST < ST1
         *              fstp    ST(1)                   // leave remainder on stack
         */
        regm_t retregs = mST0;
        load87(cdb,e2,0,&retregs,e1,-1);
        makesure87(cdb,e1,0,1,0);       // now have x,y on stack; need y,x
        if (!reverse)                           // if not reverse modulo
            cdb.genf2(0xD9,0xC8 + 1);           // FXCH ST(1)

        cdb.gen2(0xD9, 0xF8);                   // FM1: FPREM
        code *cfm1 = cdb.last();
        genjmpifC2(cdb, cfm1);                  // JC2 FM1
        cdb.genf2(0xDD,0xD8 + 1);               // FSTP ST(1)

        pop87();
        freenode(e2);
        fixresult87(cdb,e,mST0,pretregs);
    }
    else
    {
        load87(cdb,e2,0,pretregs,e1,op);
        freenode(e2);
    }
    if (*pretregs & mST0)
        note87(e,0,0);
    //printf("orth87(-e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
}

/*****************************
 * Load e into ST01.
 */

@trusted
private void loadComplex(ref CodeBuilder cdb,elem *e)
{
    regm_t retregs;

    int sz = tysize(e.Ety);
    switch (tybasic(e.Ety))
    {
        case TYfloat:
        case TYdouble:
        case TYldouble:
            retregs = mST0;
            codelem(cdb,e,&retregs,false);
            // Convert to complex with a 0 for the imaginary part
            push87(cdb);
            cdb.gen2(0xD9,0xEE);              // FLDZ
            break;

        case TYifloat:
        case TYidouble:
        case TYildouble:
            // Convert to complex with a 0 for the real part
            push87(cdb);
            cdb.gen2(0xD9,0xEE);              // FLDZ
            retregs = mST0;
            codelem(cdb,e,&retregs,false);
            break;

        case TYcfloat:
        case TYcdouble:
        case TYcldouble:
            sz /= 2;
            retregs = mST01;
            codelem(cdb,e,&retregs,false);
            break;

        default:
            assert(0);
    }
    note87(e, 0, 1);
    note87(e, sz, 0);
}

/*************************
 * If op == -1, load expression e into ST0.
 * else compute (eleft op e), eleft is in ST0.
 * Must follow same logic as cmporder87();
 */

@trusted
void load87(ref CodeBuilder cdb,elem *e,uint eoffset,regm_t *pretregs,elem *eleft,OPER op)
{
    code cs;
    regm_t retregs;
    reg_t reg;
    uint mf1;
    ubyte ldop;
    int i;

    if (NDPP)
        printf("+load87(e=%p, eoffset=%d, *pretregs=%s, eleft=%p, op=%d, stackused = %d)\n",e,eoffset,regm_str(*pretregs),eleft,op,global87.stackused);

    assert(!(NOSAHF && op == 3));
    elem_debug(e);
    if (ADDFWAIT())
        cs.Iflags = CFwait;
    else
        cs.Iflags = 0;
    cs.Irex = 0;
    OPER opr = oprev[op + 1];
    tym_t ty = tybasic(e.Ety);
    uint mf = (ty == TYfloat || ty == TYifloat || ty == TYcfloat) ? MFfloat : MFdouble;
    bool noted = false;
    if ((ty == TYldouble || ty == TYildouble) &&
        op != -1 && e.Eoper != OPd_ld)
        goto Ldefault;
L5:
    switch (e.Eoper)
    {
        case OPcomma:
            if (op != -1)
            {
                note87(eleft,eoffset,0);
                noted = true;
            }
            docommas(cdb,&e);
            goto L5;

        case OPvar:
            notreg(e);
            goto L2;

        case OPind:
        L2:
            if (op != -1)
            {
                if (e.Ecount && e.Ecount != e.Ecomsub &&
                    (i = cse_get(e, 0)) >= 0)
                {
                    immutable ubyte[8] b2 = [0xC0,0xC8,0xD0,0xD8,0xE0,0xE8,0xF0,0xF8];

                    cdb.genf2(0xD8,b2[op] + i);        // Fop ST(i)
                }
                else
                {
                    getlvalue87(cdb,&cs,e,0);
                    makesure87(cdb,eleft,eoffset,0,0);
                    cs.Iop = ESC(mf,0);
                    cs.Irm |= modregrm(0,op,0);
                    cdb.gen(&cs);
                }
            }
            else
            {
                push87(cdb);
                switch (ty)
                {
                    case TYfloat:
                    case TYdouble:
                    case TYifloat:
                    case TYidouble:
                    case TYcfloat:
                    case TYcdouble:
                    case TYdouble_alias:
                        loadea(cdb,e,&cs,ESC(mf,1),0,0,0,0); // FLD var
                        break;
                    case TYldouble:
                    case TYildouble:
                    case TYcldouble:
                        loadea(cdb,e,&cs,0xDB,5,0,0,0);      // FLD var
                        break;
                    default:
                        printf("ty = x%x\n", ty);
                        assert(0);
                }
                note87(e,0,0);
            }
            break;

        case OPd_f:
        case OPf_d:
        case OPd_ld:
            mf1 = (tybasic(e.EV.E1.Ety) == TYfloat || tybasic(e.EV.E1.Ety) == TYifloat)
                    ? MFfloat : MFdouble;
            if (op != -1 && global87.stackused && !noted)
                note87(eleft,eoffset,0);    // don't trash this value
            if (e.EV.E1.Eoper == OPvar || e.EV.E1.Eoper == OPind)
            {
                static if (1)
                {
                  L4:
                    getlvalue87(cdb,&cs,e.EV.E1,0);
                    cs.Iop = ESC(mf1,0);
                    if (op != -1)
                    {
                        cs.Irm |= modregrm(0,op,0);
                        makesure87(cdb,eleft,eoffset,0,0);
                    }
                    else
                    {
                        cs.Iop |= 1;
                        push87(cdb);
                    }
                    cdb.gen(&cs);                     // FLD / Fop
                }
                else
                {
                    loadea(cdb,e.EV.E1,&cs,ESC(mf1,1),0,0,0,0); /* FLD e.EV.E1 */
                }

                // Variable cannot be put into a register anymore
                if (e.EV.E1.Eoper == OPvar)
                    notreg(e.EV.E1);
                freenode(e.EV.E1);
            }
            else
            {
                retregs = mST0;
                codelem(cdb,e.EV.E1,&retregs,false);
                if (op != -1)
                {
                    makesure87(cdb,eleft,eoffset,1,0);
                    cdb.genf2(0xDE,modregrm(3,opr,1)); // FopRP
                    pop87();
                }
            }
            break;

        case OPs64_d:
            if (e.EV.E1.Eoper == OPvar ||
                (e.EV.E1.Eoper == OPind && e.EV.E1.Ecount == 0))
            {
                getlvalue87(cdb,&cs,e.EV.E1,0);
                cs.Iop = 0xDF;
                push87(cdb);
                cs.Irm |= modregrm(0,5,0);
                cdb.gen(&cs);                     // FILD m64
                // Variable cannot be put into a register anymore
                if (e.EV.E1.Eoper == OPvar)
                    notreg(e.EV.E1);
                freenode(e.EV.E1);
            }
            else if (I64)
            {
                retregs = ALLREGS;
                codelem(cdb,e.EV.E1,&retregs,false);
                reg = findreg(retregs);
                cdb.genfltreg(STO,reg,0);         // MOV floatreg,reg
                code_orrex(cdb.last(), REX_W);
                push87(cdb);
                cdb.genfltreg(0xDF,5,0);          // FILD long long ptr floatreg
            }
            else
            {
                retregs = ALLREGS;
                codelem(cdb,e.EV.E1,&retregs,false);
                reg = findreglsw(retregs);
                cdb.genfltreg(STO,reg,0);         // MOV floatreg,reglsw
                reg = findregmsw(retregs);
                cdb.genfltreg(STO,reg,4);         // MOV floatreg+4,regmsw
                push87(cdb);
                cdb.genfltreg(0xDF,5,0);          // FILD long long ptr floatreg
            }
            if (op != -1)
            {
                makesure87(cdb,eleft,eoffset,1,0);
                cdb.genf2(0xDE,modregrm(3,opr,1)); // FopRP
                pop87();
            }
            break;

        case OPconst:
            ldop = loadconst(e, 0);
            if (ldop)
            {
                push87(cdb);
                cdb.genf2(0xD9,ldop);          // FLDx
                if (op != -1)
                {
                    cdb.genf2(0xDE,modregrm(3,opr,1));        // FopRP
                    pop87();
                }
            }
            else
            {
                assert(0);
            }
            break;

        case OPu16_d:
        {
            /* This opcode should never be generated        */
            /* (probably shouldn't be for 16 bit code too)  */
            assert(!I32);

            if (op != -1 && !noted)
                note87(eleft,eoffset,0);    // don't trash this value
            retregs = ALLREGS & mLSW;
            codelem(cdb,e.EV.E1,&retregs,false);
            regwithvalue(cdb,ALLREGS & mMSW,0,&reg,0);  // 0-extend
            retregs |= mask(reg);
            mf1 = MFlong;
            goto L3;
        }

        case OPs16_d:       mf1 = MFword;   goto L6;
        case OPs32_d:       mf1 = MFlong;   goto L6;
        L6:
            if (e.Ecount)
                goto Ldefault;
            if (op != -1 && !noted)
                note87(eleft,eoffset,0);    // don't trash this value
            if (e.EV.E1.Eoper == OPvar ||
                (e.EV.E1.Eoper == OPind && e.EV.E1.Ecount == 0))
            {
                goto L4;
            }
            else
            {
                retregs = ALLREGS;
                codelem(cdb,e.EV.E1,&retregs,false);
            L3:
                if (I16 && e.Eoper != OPs16_d)
                {
                    /* MOV floatreg+2,reg   */
                    reg = findregmsw(retregs);
                    cdb.genfltreg(STO,reg,REGSIZE);
                    retregs &= mLSW;
                }
                reg = findreg(retregs);
                cdb.genfltreg(STO,reg,0);         // MOV floatreg,reg
                if (op != -1)
                {
                    makesure87(cdb,eleft,eoffset,0,0);
                    cdb.genfltreg(ESC(mf1,0),op,0);   // Fop floatreg
                }
                else
                {
                    /* FLD long ptr floatreg        */
                    push87(cdb);
                    cdb.genfltreg(ESC(mf1,1),0,0);
                }
            }
            break;
        default:
        Ldefault:
            retregs = mST0;
            codelem(cdb,e,&retregs,2);

            if (op != -1)
            {
                makesure87(cdb,eleft,eoffset,1,(op == 0 || op == 1));
                pop87();
                if (op == 4 || op == 6)     // sub or div
                {
                    code *cl = cdb.last();
                    if (cl && cl.Iop == 0xD9 && cl.Irm == 0xC9)   // FXCH ST(1)
                    {   cl.Iop = NOP;
                        opr = op;           // reverse operands
                    }
                }
                cdb.genf2(0xDE,modregrm(3,opr,1));        // FopRP
            }
            break;
    }
    if (op == 3)                    // FCOMP
    {   pop87();                    // extra pop was done
        cg87_87topsw(cdb);
    }
    fixresult87(cdb,e,((op == 3) ? mPSW : mST0),pretregs);
    if (NDPP)
        printf("-load87(e=%p, eoffset=%d, *pretregs=%s, eleft=%p, op=%d, stackused = %d)\n",e,eoffset,regm_str(*pretregs),eleft,op,global87.stackused);
}

/********************************
 * Determine if a compare is to be done forwards (return 0)
 * or backwards (return 1).
 * Must follow same logic as load87().
 */

@trusted
int cmporder87(elem *e)
{
    //printf("cmporder87(%p)\n",e);
  L1:
    switch (e.Eoper)
    {
        case OPcomma:
            e = e.EV.E2;
            goto L1;

        case OPd_f:
        case OPf_d:
        case OPd_ld:
            if (e.EV.E1.Eoper == OPvar || e.EV.E1.Eoper == OPind)
                goto ret0;
            else
                goto ret1;

        case OPconst:
            if (loadconst(e, 0) || tybasic(e.Ety) == TYldouble
                                || tybasic(e.Ety) == TYildouble)
            {
                //printf("ret 1, loadconst(e) = %d\n", loadconst(e));
                goto ret1;
            }
            goto ret0;

        case OPvar:
        case OPind:
            if (tybasic(e.Ety) == TYldouble ||
                tybasic(e.Ety) == TYildouble)
                goto ret1;
            goto ret0;

        case OPu16_d:
        case OPs16_d:
        case OPs32_d:
            goto ret0;

        case OPs64_d:
            goto ret1;

        default:
            goto ret1;
    }

ret1:
    return 1;

ret0:
    return 0;
}

/*******************************
 * Perform an assignment to a long double/double/float.
 */

@trusted
void eq87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    code cs;
    opcode_t op1;
    uint op2;

    //printf("+eq87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    assert(e.Eoper == OPeq);
    regm_t retregs = mST0 | (*pretregs & mPSW);
    codelem(cdb,e.EV.E2,&retregs,false);
    tym_t ty1 = tybasic(e.EV.E1.Ety);
    switch (ty1)
    {
        case TYdouble_alias:
        case TYidouble:
        case TYdouble:      op1 = ESC(MFdouble,1);  op2 = 3; break;

        case TYifloat:
        case TYfloat:       op1 = ESC(MFfloat,1);   op2 = 3; break;

        case TYildouble:
        case TYldouble:     op1 = 0xDB;             op2 = 7; break;

        default:
            assert(0);
    }
    if (*pretregs & (mST0 | ALLREGS | mBP | XMMREGS)) // if want result on stack too
    {
        if (ty1 == TYldouble || ty1 == TYildouble)
        {
            push87(cdb);
            cdb.genf2(0xD9,0xC0);           // FLD ST(0)
            pop87();
        }
        else
            op2 = 2;                        // FST e.EV.E1
    }
    else
    {   // FSTP e.EV.E1
        pop87();
    }

    static if (0)
    {
        // Doesn't work if ST(0) gets saved to the stack by getlvalue()
        loadea(cdb,e.EV.E1,&cs,op1,op2,0,0,0);
    }
    else
    {
        cs.Irex = 0;
        cs.Iflags = 0;
        cs.Iop = op1;
        if (*pretregs & (mST0 | ALLREGS | mBP | XMMREGS)) // if want result on stack too
        {   // Make sure it's still there
            elem *e2 = e.EV.E2;
            while (e2.Eoper == OPcomma)
                e2 = e2.EV.E2;
            note87(e2,0,0);
            getlvalue87(cdb, &cs, e.EV.E1, 0);
            makesure87(cdb,e2,0,0,1);
        }
        else
        {
            getlvalue87(cdb, &cs, e.EV.E1, 0);
        }
        cs.Irm |= modregrm(0,op2,0);            // OR in reg field
        cdb.gen(&cs);
        if (tysize(TYldouble) == 12)
        {
            /* This deals with the fact that 10 byte reals really
             * occupy 12 bytes by zeroing the extra 2 bytes.
             */
            if (op1 == 0xDB)
            {
                cs.Iop = 0xC7;                      // MOV EA+10,0
                NEWREG(cs.Irm, 0);
                cs.IEV1.Voffset += 10;
                cs.IFL2 = FLconst;
                cs.IEV2.Vint = 0;
                cs.Iflags |= CFopsize;
                cdb.gen(&cs);
            }
        }
        else if (tysize(TYldouble) == 16)
        {
            /* This deals with the fact that 10 byte reals really
             * occupy 16 bytes by zeroing the extra 6 bytes.
             */
            if (op1 == 0xDB)
            {
                cs.Irex &= ~REX_W;
                cs.Iop = 0xC7;                      // MOV EA+10,0
                NEWREG(cs.Irm, 0);
                cs.IEV1.Voffset += 10;
                cs.IFL2 = FLconst;
                cs.IEV2.Vint = 0;
                cs.Iflags |= CFopsize;
                cdb.gen(&cs);

                cs.IEV1.Voffset += 2;
                cs.Iflags &= ~CFopsize;
                cdb.gen(&cs);
            }
        }
    }
    genfwait(cdb);
    freenode(e.EV.E1);
    fixresult87(cdb,e,mST0 | mPSW,pretregs);
}

/*******************************
 * Perform an assignment to a long double/double/float.
 */

@trusted
void complex_eq87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    code cs;
    opcode_t op1;
    uint op2;
    uint sz;
    int fxch = 0;

    //printf("complex_eq87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    assert(e.Eoper == OPeq);
    cs.Iflags = ADDFWAIT() ? CFwait : 0;
    cs.Irex = 0;
    regm_t retregs = mST01 | (*pretregs & mPSW);
    codelem(cdb,e.EV.E2,&retregs,false);
    tym_t ty1 = tybasic(e.EV.E1.Ety);
    switch (ty1)
    {
        case TYcdouble:     op1 = ESC(MFdouble,1);  op2 = 3; break;
        case TYcfloat:      op1 = ESC(MFfloat,1);   op2 = 3; break;
        case TYcldouble:    op1 = 0xDB;             op2 = 7; break;
        default:
            assert(0);
    }
    if (*pretregs & (mST01 | mXMM0 | mXMM1))  // if want result on stack too
    {
        if (ty1 == TYcldouble)
        {
            push87(cdb);
            push87(cdb);
            cdb.genf2(0xD9,0xC0 + 1);       // FLD ST(1)
            cdb.genf2(0xD9,0xC0 + 1);       // FLD ST(1)
            pop87();
            pop87();
        }
        else
        {   op2 = 2;                        // FST e.EV.E1
            fxch = 1;
        }
    }
    else
    {   // FSTP e.EV.E1
        pop87();
        pop87();
    }
    sz = tysize(ty1) / 2;
    if (*pretregs & (mST01 | mXMM0 | mXMM1))
    {
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.Iop = op1;
        getlvalue87(cdb, &cs, e.EV.E1, 0);
        cs.IEV1.Voffset += sz;
        cs.Irm |= modregrm(0, op2, 0);
        makesure87(cdb,e.EV.E2, sz, 0, 0);
        cdb.gen(&cs);
        genfwait(cdb);
        makesure87(cdb,e.EV.E2,  0, 1, 0);
    }
    else
    {
        loadea(cdb,e.EV.E1,&cs,op1,op2,sz,0,0);
        genfwait(cdb);
    }
    if (fxch)
        cdb.genf2(0xD9,0xC8 + 1);       // FXCH ST(1)
    cs.IEV1.Voffset -= sz;
    cdb.gen(&cs);
    if (fxch)
        cdb.genf2(0xD9,0xC8 + 1);       // FXCH ST(1)
    if (tysize(TYldouble) == 12)
    {
        if (op1 == 0xDB)
        {
            cs.Iop = 0xC7;              // MOV EA+10,0
            NEWREG(cs.Irm, 0);
            cs.IEV1.Voffset += 10;
            cs.IFL2 = FLconst;
            cs.IEV2.Vint = 0;
            cs.Iflags |= CFopsize;
            cdb.gen(&cs);
            cs.IEV1.Voffset += 12;
            cdb.gen(&cs);               // MOV EA+22,0
        }
    }
    if (tysize(TYldouble) == 16)
    {
        if (op1 == 0xDB)
        {
            cs.Iop = 0xC7;              // MOV EA+10,0
            NEWREG(cs.Irm, 0);
            cs.IEV1.Voffset += 10;
            cs.IFL2 = FLconst;
            cs.IEV2.Vint = 0;
            cs.Iflags |= CFopsize;
            cdb.gen(&cs);

            cs.IEV1.Voffset += 2;
            cs.Iflags &= ~CFopsize;
            cdb.gen(&cs);

            cs.IEV1.Voffset += 14;
            cs.Iflags |= CFopsize;
            cdb.gen(&cs);

            cs.IEV1.Voffset += 2;
            cs.Iflags &= ~CFopsize;
            cdb.gen(&cs);
        }
    }
    genfwait(cdb);
    freenode(e.EV.E1);
    fixresult_complex87(cdb, e,mST01 | mPSW,pretregs);
}

/*******************************
 * Perform an assignment while converting to integral type,
 * i.e. handle (e1 = (int) e2)
 */

@trusted
private void cnvteq87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    code cs;
    opcode_t op1;
    uint op2;

    assert(e.Eoper == OPeq);
    assert(!*pretregs);
    regm_t retregs = mST0;
    elem_debug(e.EV.E2);
    codelem(cdb,e.EV.E2.EV.E1,&retregs,false);

    switch (e.EV.E2.Eoper)
    {   case OPd_s16:
            op1 = ESC(MFword,1);
            op2 = 3;
            break;
        case OPd_s32:
        case OPd_u16:
            op1 = ESC(MFlong,1);
            op2 = 3;
            break;
        case OPd_s64:
            op1 = 0xDF;
            op2 = 7;
            break;
        default:
            assert(0);
    }
    freenode(e.EV.E2);

    genfwait(cdb);
    genrnd(cdb, CW_roundto0);               // FLDCW roundto0

    pop87();
    cs.Iflags = ADDFWAIT() ? CFwait : 0;
    if (e.EV.E1.Eoper == OPvar)
        notreg(e.EV.E1);                    // cannot be put in register anymore
    loadea(cdb,e.EV.E1,&cs,op1,op2,0,0,0);

    genfwait(cdb);
    genrnd(cdb, CW_roundtonearest);         // FLDCW roundtonearest

    freenode(e.EV.E1);
}

/**********************************
 * Perform +=, -=, *= and /= for doubles.
 */

@trusted
void opass87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    code cs;
    uint op;
    opcode_t opld;
    opcode_t op1;
    uint op2;
    tym_t ty1 = tybasic(e.EV.E1.Ety);

    switch (ty1)
    {
        case TYdouble_alias:
        case TYidouble:
        case TYdouble:      op1 = ESC(MFdouble,1);  op2 = 3; break;
        case TYifloat:
        case TYfloat:       op1 = ESC(MFfloat,1);   op2 = 3; break;
        case TYildouble:
        case TYldouble:     op1 = 0xDB;             op2 = 7; break;

        case TYcfloat:
        case TYcdouble:
        case TYcldouble:
            if (e.Eoper == OPmodass)
               opmod_complex87(cdb, e, pretregs);
            else
               opass_complex87(cdb, e, pretregs);
            return;

        default:
            assert(0);
    }
    switch (e.Eoper)
    {
        case OPpostinc:
        case OPaddass:      op = 0 << 3;    opld = 0xC1;    break;  // FADD
        case OPpostdec:
        case OPminass:      op = 5 << 3;    opld = 0xE1; /*0xE9;*/  break;  // FSUBR
        case OPmulass:      op = 1 << 3;    opld = 0xC9;    break;  // FMUL
        case OPdivass:      op = 7 << 3;    opld = 0xF1;    break;  // FDIVR
        case OPmodass:      break;
        default:            assert(0);
    }
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E2,&retregs,false);     // evaluate rvalue
    note87(e.EV.E2,0,0);
    getlvalue87(cdb,&cs,e.EV.E1,e.Eoper==OPmodass?mAX:0);
    makesure87(cdb,e.EV.E2,0,0,0);
    if (config.flags4 & CFG4fdivcall && e.Eoper == OPdivass)
    {
        push87(cdb);
        cs.Iop = op1;
        if (ty1 == TYldouble || ty1 == TYildouble)
            cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
        cdb.gen(&cs);
        cdb.genf2(0xD9,0xC8 + 1);           // FXCH ST(1)
        callclib(cdb,e,CLIB.fdiv87,&retregs,0);
        pop87();
    }
    else if (e.Eoper == OPmodass)
    {
        /*
         *          fld     tbyte ptr y
         *          fld     tbyte ptr x             // ST = x, ST1 = y
         *  FM1:    // We don't use fprem1 because for some inexplicable
         *          // reason we get -5 when we do _modulo(15, 10)
         *          fprem                           // ST = ST % ST1
         *          fstsw   word ptr sw
         *          fwait
         *          mov     AH,byte ptr sw+1        // get msb of status word in AH
         *          sahf                            // transfer to flags
         *          jp      FM1                     // continue till ST < ST1
         *          fstp    ST(1)                   // leave remainder on stack
         */
        code *c1;

        push87(cdb);
        cs.Iop = op1;
        if (ty1 == TYldouble || ty1 == TYildouble)
            cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
        cdb.gen(&cs);                       // FLD   e.EV.E1

        cdb.gen2(0xD9, 0xF8);               // FPREM
        code *cfm1 = cdb.last();
        genjmpifC2(cdb, cfm1);              // JC2 FM1
        cdb.genf2(0xDD,0xD8 + 1);           // FSTP ST(1)

        pop87();
    }
    else if (ty1 == TYldouble || ty1 == TYildouble)
    {
        push87(cdb);
        cs.Iop = op1;
        cs.Irm |= modregrm(0, 5, 0);        // FLD tbyte ptr ...
        cdb.gen(&cs);                       // FLD   e.EV.E1
        cdb.genf2(0xDE,opld);               // FopP  ST(1)
        pop87();
    }
    else
    {
        cs.Iop = op1 & ~1;
        cs.Irm |= op;
        cdb.gen(&cs);                       // Fop e.EV.E1
    }
    if (*pretregs & mPSW)
        genftst(cdb,e,0);                   // FTST ST0
    // if want result in registers
    if (*pretregs & (mST0 | ALLREGS | mBP))
    {
        if (ty1 == TYldouble || ty1 == TYildouble)
        {
            push87(cdb);
            cdb.genf2(0xD9,0xC0);           // FLD ST(0)
            pop87();
        }
        else
            op2 = 2;                        // FST e.EV.E1
    }
    else
    {   // FSTP
        pop87();
    }
    cs.Iop = op1;
    NEWREG(cs.Irm,op2);                     // FSTx e.EV.E1
    freenode(e.EV.E1);
    cdb.gen(&cs);
    genfwait(cdb);
    fixresult87(cdb,e,mST0 | mPSW,pretregs);
}

/***********************************
 * Perform %= where E1 is complex and E2 is real or imaginary.
 */

@trusted
private void opmod_complex87(ref CodeBuilder cdb, elem *e,regm_t *pretregs)
{

    /*          fld     E2
                fld     E1.re
        FM1:    fprem
                fstsw   word ptr sw
                fwait
                mov     AH, byte ptr sw+1
                jp      FM1
                fxch    ST(1)
                fld     E1.im
        FM2:    fprem
                fstsw   word ptr sw
                fwait
                mov     AH, byte ptr sw+1
                jp      FM2
                fstp    ST(1)
     */

    code cs;

    tym_t ty1 = tybasic(e.EV.E1.Ety);
    uint sz2 = _tysize[ty1] / 2;

    regm_t retregs = mST0;
    codelem(cdb,e.EV.E2,&retregs,false);         // FLD E2
    note87(e.EV.E2,0,0);
    getlvalue87(cdb,&cs,e.EV.E1,0);
    makesure87(cdb,e.EV.E2,0,0,0);

    push87(cdb);
    switch (ty1)
    {
        case TYcdouble:  cs.Iop = ESC(MFdouble,1);      break;
        case TYcfloat:   cs.Iop = ESC(MFfloat,1);       break;
        case TYcldouble: cs.Iop = 0xDB; cs.Irm |= modregrm(0, 5, 0); break;
        default:
            assert(0);
    }
    cdb.gen(&cs);                               // FLD E1.re

    cdb.gen2(0xD9, 0xF8);                       // FPREM
    code *cfm1 = cdb.last();
    genjmpifC2(cdb, cfm1);                      // JC2 FM1
    cdb.genf2(0xD9, 0xC8 + 1);                  // FXCH ST(1)

    push87(cdb);
    cs.IEV1.Voffset += sz2;
    cdb.gen(&cs);                               // FLD E1.im

    cdb.gen2(0xD9, 0xF8);                       // FPREM
    code *cfm2 = cdb.last();
    genjmpifC2(cdb, cfm2);                      // JC2 FM2
    cdb.genf2(0xDD,0xD8 + 1);                   // FSTP ST(1)

    pop87();

    if (*pretregs & (mST01 | mPSW))
    {
        cs.Irm |= modregrm(0, 2, 0);
        cdb.gen(&cs);            // FST mreal.im
        cs.IEV1.Voffset -= sz2;
        cdb.gen(&cs);            // FST mreal.re
        retregs = mST01;
    }
    else
    {
        cs.Irm |= modregrm(0, 3, 0);
        cdb.gen(&cs);            // FSTP mreal.im
        cs.IEV1.Voffset -= sz2;
        cdb.gen(&cs);            // FSTP mreal.re
        pop87();
        pop87();
        retregs = 0;
    }
    freenode(e.EV.E1);
    genfwait(cdb);
    fixresult_complex87(cdb,e,retregs,pretregs);
}

/**********************************
 * Perform +=, -=, *= and /= for the lvalue being complex.
 */

@trusted
private void opass_complex87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    regm_t retregs;
    regm_t idxregs;
    code cs;
    uint op;
    opcode_t op2;

    tym_t ty1 = tybasic(e.EV.E1.Ety);
    uint sz2 = _tysize[ty1] / 2;
    switch (e.Eoper)
    {
        case OPpostinc:
        case OPaddass:  op = 0 << 3;            // FADD
                        op2 = 0xC0;             // FADDP ST(i),ST
                        break;

        case OPpostdec:
        case OPminass:  op = 5 << 3;            // FSUBR
                        op2 = 0xE0;             // FSUBRP ST(i),ST
                        break;

        case OPmulass:  op = 1 << 3;            // FMUL
                        op2 = 0xC8;             // FMULP ST(i),ST
                        break;

        case OPdivass:  op = 7 << 3;            // FDIVR
                        op2 = 0xF0;             // FDIVRP ST(i),ST
                        break;

        default:        assert(0);
    }

    if (!tycomplex(e.EV.E2.Ety) &&
        (e.Eoper == OPmulass || e.Eoper == OPdivass))
    {
        retregs = mST0;
        codelem(cdb,e.EV.E2, &retregs, false);
        note87(e.EV.E2, 0, 0);
        getlvalue87(cdb,&cs, e.EV.E1, 0);
        makesure87(cdb,e.EV.E2,0,0,0);
        push87(cdb);
        cdb.genf2(0xD9,0xC0);                   // FLD ST(0)
        goto L1;
    }
    else
    {
        loadComplex(cdb,e.EV.E2);
        getlvalue87(cdb,&cs,e.EV.E1,0);
        makesure87(cdb,e.EV.E2,sz2,0,0);
        makesure87(cdb,e.EV.E2,0,1,0);
    }

    switch (e.Eoper)
    {
        case OPpostinc:
        case OPaddass:
        case OPpostdec:
        case OPminass:
        L1:
            if (ty1 == TYcldouble)
            {
                push87(cdb);
                push87(cdb);
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
                cdb.gen(&cs);                   // FLD e.EV.E1.re
                cs.IEV1.Voffset += sz2;
                cdb.gen(&cs);                   // FLD e.EV.E1.im
                cdb.genf2(0xDE, op2 + 2);       // FADDP/FSUBRP ST(2),ST
                cdb.genf2(0xDE, op2 + 2);       // FADDP/FSUBRP ST(2),ST
                pop87();
                pop87();
                if (tyimaginary(e.EV.E2.Ety))
                {
                    if (e.Eoper == OPmulass)
                    {
                        cdb.genf2(0xD9, 0xE0);   // FCHS
                        cdb.genf2(0xD9, 0xC8+1); // FXCH ST(1)
                    }
                    else if (e.Eoper == OPdivass)
                    {
                        cdb.genf2(0xD9, 0xC8+1); // FXCH ST(1)
                        cdb.genf2(0xD9, 0xE0);   // FCHS
                    }
                }
            L2:
                if (*pretregs & (mST01 | mPSW))
                {
                    push87(cdb);
                    push87(cdb);
                    cdb.genf2(0xD9,0xC1);       // FLD ST(1)
                    cdb.genf2(0xD9,0xC1);       // FLD ST(1)
                    retregs = mST01;
                }
                else
                    retregs = 0;
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0,7,0);
                cdb.gen(&cs);                   // FSTP e.EV.E1.im
                cs.IEV1.Voffset -= sz2;
                cdb.gen(&cs);                   // FSTP e.EV.E1.re
                pop87();
                pop87();

            }
            else
            {
                ubyte rmop = cast(ubyte)(cs.Irm | op);
                ubyte rmfst = cs.Irm | modregrm(0,2,0);
                ubyte rmfstp = cs.Irm | modregrm(0,3,0);
                ubyte iopfst = (ty1 == TYcfloat) ? 0xD9 : 0xDD;
                opcode_t iop = (ty1 == TYcfloat) ? 0xD8 : 0xDC;

                cs.Iop = iop;
                cs.Irm = rmop;
                cs.IEV1.Voffset += sz2;
                cdb.gen(&cs);                           // FSUBR mreal.im
                if (tyimaginary(e.EV.E2.Ety) && (e.Eoper == OPmulass || e.Eoper == OPdivass))
                {
                    if (e.Eoper == OPmulass)
                        cdb.genf2(0xD9, 0xE0);          // FCHS
                    cdb.genf2(0xD9,0xC8 + 1);           // FXCH ST(1)
                    cs.IEV1.Voffset -= sz2;
                    cdb.gen(&cs);                       // FMUL mreal.re
                    if (e.Eoper == OPdivass)
                        cdb.genf2(0xD9, 0xE0);          // FCHS
                    if (*pretregs & (mST01 | mPSW))
                    {
                        cs.Iop = iopfst;
                        cs.Irm = rmfst;
                        cs.IEV1.Voffset += sz2;
                        cdb.gen(&cs);                   // FST mreal.im
                        cdb.genf2(0xD9,0xC8 + 1);       // FXCH ST(1)
                        cs.IEV1.Voffset -= sz2;
                        cdb.gen(&cs);                   // FST mreal.re
                        cdb.genf2(0xD9,0xC8 + 1);       // FXCH ST(1)
                        retregs = mST01;
                    }
                    else
                    {
                        cs.Iop = iopfst;
                        cs.Irm = rmfstp;
                        cs.IEV1.Voffset += sz2;
                        cdb.gen(&cs);                   // FSTP mreal.im
                        pop87();
                        cs.IEV1.Voffset -= sz2;
                        cdb.gen(&cs);                   // FSTP mreal.re
                        pop87();
                        retregs = 0;
                    }
                    goto L3;
                }

                if (*pretregs & (mST01 | mPSW))
                {
                    cs.Iop = iopfst;
                    cs.Irm = rmfst;
                    cdb.gen(&cs);               // FST mreal.im
                    cdb.genf2(0xD9,0xC8 + 1);   // FXCH ST(1)
                    cs.Iop = iop;
                    cs.Irm = rmop;
                    cs.IEV1.Voffset -= sz2;
                    cdb.gen(&cs);               // FSUBR mreal.re
                    cs.Iop = iopfst;
                    cs.Irm = rmfst;
                    cdb.gen(&cs);               // FST mreal.re
                    cdb.genf2(0xD9,0xC8 + 1);   // FXCH ST(1)
                    retregs = mST01;
                }
                else
                {
                    cs.Iop = iopfst;
                    cs.Irm = rmfstp;
                    cdb.gen(&cs);               // FSTP mreal.im
                    pop87();
                    cs.Iop = iop;
                    cs.Irm = rmop;
                    cs.IEV1.Voffset -= sz2;
                    cdb.gen(&cs);               // FSUBR mreal.re
                    cs.Iop = iopfst;
                    cs.Irm = rmfstp;
                    cdb.gen(&cs);               // FSTP mreal.re
                    pop87();
                    retregs = 0;
                }
            }
        L3:
            freenode(e.EV.E1);
            genfwait(cdb);
            fixresult_complex87(cdb,e,retregs,pretregs);
            return;

        case OPmulass:
            push87(cdb);
            push87(cdb);
            if (ty1 == TYcldouble)
            {
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
                cdb.gen(&cs);                   // FLD e.EV.E1.re
                cs.IEV1.Voffset += sz2;
                cdb.gen(&cs);                   // FLD e.EV.E1.im
                retregs = mST01;
                callclib(cdb, e, CLIB.cmul, &retregs, 0);
                goto L2;
            }
            else
            {
                cs.Iop = (ty1 == TYcfloat) ? 0xD9 : 0xDD;
                cs.Irm |= modregrm(0, 0, 0);    // FLD tbyte ptr ...
                cdb.gen(&cs);                   // FLD e.EV.E1.re
                cs.IEV1.Voffset += sz2;
                cdb.gen(&cs);                   // FLD e.EV.E1.im
                retregs = mST01;
                callclib(cdb, e, CLIB.cmul, &retregs, 0);
                if (*pretregs & (mST01 | mPSW))
                {
                    cs.Irm |= modregrm(0, 2, 0);
                    cdb.gen(&cs);               // FST mreal.im
                    cs.IEV1.Voffset -= sz2;
                    cdb.gen(&cs);               // FST mreal.re
                    retregs = mST01;
                }
                else
                {
                    cs.Irm |= modregrm(0, 3, 0);
                    cdb.gen(&cs);               // FSTP mreal.im
                    cs.IEV1.Voffset -= sz2;
                    cdb.gen(&cs);               // FSTP mreal.re
                    pop87();
                    pop87();
                    retregs = 0;
                }
                goto L3;
            }

        case OPdivass:
            push87(cdb);
            push87(cdb);
            idxregs = idxregm(&cs);             // mask of index regs used
            if (ty1 == TYcldouble)
            {
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
                cdb.gen(&cs);                   // FLD e.EV.E1.re
                cdb.genf2(0xD9,0xC8 + 2);       // FXCH ST(2)
                cs.IEV1.Voffset += sz2;
                cdb.gen(&cs);                   // FLD e.EV.E1.im
                cdb.genf2(0xD9,0xC8 + 2);       // FXCH ST(2)
                retregs = mST01;
                callclib(cdb, e, CLIB.cdiv, &retregs, idxregs);
                goto L2;
            }
            else
            {
                cs.Iop = (ty1 == TYcfloat) ? 0xD9 : 0xDD;
                cs.Irm |= modregrm(0, 0, 0);    // FLD tbyte ptr ...
                cdb.gen(&cs);                   // FLD e.EV.E1.re
                cdb.genf2(0xD9,0xC8 + 2);       // FXCH ST(2)
                cs.IEV1.Voffset += sz2;
                cdb.gen(&cs);                   // FLD e.EV.E1.im
                cdb.genf2(0xD9,0xC8 + 2);       // FXCH ST(2)
                retregs = mST01;
                callclib(cdb, e, CLIB.cdiv, &retregs, idxregs);
                if (*pretregs & (mST01 | mPSW))
                {
                    cs.Irm |= modregrm(0, 2, 0);
                    cdb.gen(&cs);               // FST mreal.im
                    cs.IEV1.Voffset -= sz2;
                    cdb.gen(&cs);               // FST mreal.re
                    retregs = mST01;
                }
                else
                {
                    cs.Irm |= modregrm(0, 3, 0);
                    cdb.gen(&cs);               // FSTP mreal.im
                    cs.IEV1.Voffset -= sz2;
                    cdb.gen(&cs);               // FSTP mreal.re
                    pop87();
                    pop87();
                    retregs = 0;
                }
                goto L3;
            }

        default:
            assert(0);
    }
}

/**************************
 * OPnegass
 */

@trusted
void cdnegass87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    regm_t retregs;
    uint op;

    //printf("cdnegass87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    elem *e1 = e.EV.E1;
    tym_t tyml = tybasic(e1.Ety);            // type of lvalue
    int sz = _tysize[tyml];

    code cs;
    getlvalue87(cdb,&cs,e1,0);

    /* If the EA is really an XMM register, modEA() will fail.
     * So disallow putting e1 into a register.
     * A better way would be to negate the XMM register in place.
     */
    if (e1.Eoper == OPvar)
        e1.EV.Vsym.Sflags &= ~GTregcand;

    modEA(cdb,&cs);
    cs.Irm |= modregrm(0,6,0);
    cs.Iop = 0x80;
    if (tysize(TYldouble) > 10)
    {
        if (tyml == TYldouble || tyml == TYildouble)
            cs.IEV1.Voffset += 10 - 1;
        else if (tyml == TYcldouble)
            cs.IEV1.Voffset += tysize(TYldouble) + 10 - 1;
        else
            cs.IEV1.Voffset += sz - 1;
    }
    else
        cs.IEV1.Voffset += sz - 1;
    cs.IFL2 = FLconst;
    cs.IEV2.Vuns = 0x80;
    cdb.gen(&cs);                       // XOR 7[EA],0x80
    if (tycomplex(tyml))
    {
        cs.IEV1.Voffset -= sz / 2;
        cdb.gen(&cs);                   // XOR 7[EA],0x80
    }

    if (*pretregs)
    {
        switch (tyml)
        {
            case TYifloat:
            case TYfloat:               cs.Iop = 0xD9;  op = 0; break;
            case TYidouble:
            case TYdouble:
            case TYdouble_alias:        cs.Iop = 0xDD;  op = 0; break;
            case TYildouble:
            case TYldouble:             cs.Iop = 0xDB;  op = 5; break;
            default:
                assert(0);
        }
        NEWREG(cs.Irm,op);
        cs.IEV1.Voffset -= sz - 1;
        push87(cdb);
        cdb.gen(&cs);                   // FLD EA
        retregs = mST0;
    }
    else
        retregs = 0;

    freenode(e1);
    fixresult87(cdb,e,retregs,pretregs);
}

/************************
 * Take care of OPpostinc and OPpostdec.
 */

@trusted
void post87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    uint op;
    opcode_t op1;
    reg_t reg;

    //printf("post87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    code cs;
    assert(*pretregs);
    getlvalue87(cdb,&cs,e.EV.E1,0);
    tym_t ty1 = tybasic(e.EV.E1.Ety);
    switch (ty1)
    {
        case TYdouble_alias:
        case TYidouble:
        case TYdouble:
        case TYcdouble:     op1 = ESC(MFdouble,1);  reg = 0;        break;
        case TYifloat:
        case TYfloat:
        case TYcfloat:      op1 = ESC(MFfloat,1);   reg = 0;        break;
        case TYildouble:
        case TYldouble:
        case TYcldouble:    op1 = 0xDB;             reg = 5;        break;
        default:
            assert(0);
    }
    NEWREG(cs.Irm, reg);
    if (reg == 5)
        reg = 7;
    else
        reg = 3;
    cs.Iop = op1;
    push87(cdb);
    cdb.gen(&cs);                   // FLD e.EV.E1
    if (tycomplex(ty1))
    {
        uint sz = _tysize[ty1] / 2;

        push87(cdb);
        cs.IEV1.Voffset += sz;
        cdb.gen(&cs);               // FLD e.EV.E1
        regm_t retregs = mST0;      // note kludge to only load real part
        codelem(cdb,e.EV.E2,&retregs,false); // load rvalue
        cdb.genf2(0xD8,             // FADD/FSUBR ST,ST2
            (e.Eoper == OPpostinc) ? 0xC0 + 2 : 0xE8 + 2);
        NEWREG(cs.Irm,reg);
        pop87();
        cs.IEV1.Voffset -= sz;
        cdb.gen(&cs);               // FSTP e.EV.E1
        genfwait(cdb);
        freenode(e.EV.E1);
        fixresult_complex87(cdb, e, mST01, pretregs);
        return;
    }

    if (*pretregs & (mST0 | ALLREGS | mBP | XMMREGS))
    {   // Want the result in a register
        push87(cdb);
        cdb.genf2(0xD9,0xC0);       // FLD ST0
    }
    if (*pretregs & mPSW)           // if result in flags
        genftst(cdb,e,0);           // FTST ST0
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E2,&retregs,false);    // load rvalue
    pop87();
    op = (e.Eoper == OPpostinc) ? modregrm(3,0,1) : modregrm(3,5,1);
    cdb.genf2(0xDE,op);             // FADDP/FSUBRP ST1
    NEWREG(cs.Irm,reg);
    pop87();
    cdb.gen(&cs);                   // FSTP e.EV.E1
    genfwait(cdb);
    freenode(e.EV.E1);
    fixresult87(cdb,e,mPSW | mST0,pretregs);
}

/************************
 * Do the following opcodes:
 *      OPd_u64
 *      OPld_u64
 */
void cdd_u64(ref CodeBuilder cdb, elem *e, regm_t *pretregs)
{
    assert(I32 || I64);
    assert(*pretregs);
    if (I32)
        cdd_u64_I32(cdb, e, pretregs);
    else
        cdd_u64_I64(cdb, e, pretregs);
}

@trusted
private void cdd_u64_I32(ref CodeBuilder cdb, elem *e, regm_t *pretregs)
{
    /* Generate:
            mov         EDX,0x8000_0000
            mov         floatreg+0,0
            mov         floatreg+4,EDX
            mov         floatreg+8,0x0FBF403e       // (roundTo0<<16) | adjust
            fld         real ptr floatreg           // adjust (= 1/real.epsilon)
            fcomp
            fstsw       AX
            fstcw       floatreg+12
            fldcw       floatreg+10                 // roundTo0
            test        AH,1
            jz          L1                          // jae L1

            fld         real ptr floatreg           // adjust
            fsubp       ST(1), ST
            fistp       floatreg
            mov         EAX,floatreg
            add         EDX,floatreg+4
            fldcw       floatreg+12
            jmp         L2

    L1:
            fistp       floatreg
            mov         EAX,floatreg
            mov         EDX,floatreg+4
            fldcw       floatreg+12
    L2:
     */
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1, &retregs, false);
    tym_t tym = e.Ety;
    retregs = *pretregs;
    if (!retregs)
        retregs = ALLREGS;
    reg_t reg, reg2;
    allocreg(cdb,&retregs,&reg,tym);
    reg  = findreglsw(retregs);
    reg2 = findregmsw(retregs);
    movregconst(cdb,reg2,0x80000000,0);
    getregs(cdb,mask(reg2) | mAX);

    cdb.genfltreg(0xC7,0,0);
    code *cf1 = cdb.last();
    cf1.IFL2 = FLconst;
    cf1.IEV2.Vint = 0;                             // MOV floatreg+0,0
    cdb.genfltreg(STO,reg2,4);                      // MOV floatreg+4,EDX
    cdb.genfltreg(0xC7,0,8);
    code *cf3 = cdb.last();
    cf3.IFL2 = FLconst;
    cf3.IEV2.Vint = 0xFBF403E;                     // MOV floatreg+8,(roundTo0<<16)|adjust

    push87(cdb);
    cdb.genfltreg(0xDB,5,0);                        // FLD real ptr floatreg
    cdb.gen2(0xD8,0xD9);                            // FCOMP
    pop87();
    cdb.gen2(0xDF,0xE0);                            // FSTSW AX
    cdb.genfltreg(0xD9,7,12);                       // FSTCW floatreg+12
    cdb.genfltreg(0xD9,5,10);                       // FLDCW floatreg+10
    cdb.genc2(0xF6,modregrm(3,0,4),1);              // TEST AH,1
    code *cnop1 = gennop(null);
    genjmp(cdb,JE,FLcode,cast(block *)cnop1);       // JZ L1

    cdb.genfltreg(0xDB,5,0);                        // FLD real ptr floatreg
    cdb.genf2(0xDE,0xE8+1);                         // FSUBP ST(1),ST
    cdb.genfltreg(0xDF,7,0);                        // FISTP dword ptr floatreg
    cdb.genfltreg(LOD,reg,0);                       // MOV reg,floatreg
    cdb.genfltreg(0x03,reg2,4);                     // ADD reg,floatreg+4
    cdb.genfltreg(0xD9,5,12);                       // FLDCW floatreg+12
    code *cnop2 = gennop(null);
    genjmp(cdb,JMP,FLcode,cast(block *)cnop2);      // JMP L2

    cdb.append(cnop1);
    cdb.genfltreg(0xDF,7,0);                        // FISTP dword ptr floatreg
    cdb.genfltreg(LOD,reg,0);                       // MOV reg,floatreg
    cdb.genfltreg(LOD,reg2,4);                      // MOV reg,floatreg+4
    cdb.genfltreg(0xD9,5,12);                       // FLDCW floatreg+12
    cdb.append(cnop2);

    pop87();
    fixresult(cdb,e,retregs,pretregs);
}

@trusted
private void cdd_u64_I64(ref CodeBuilder cdb, elem *e, regm_t *pretregs)
{
    /* Generate:
            mov         EDX,0x8000_0000
            mov         floatreg+0,0
            mov         floatreg+4,EDX
            mov         floatreg+8,0x0FBF403e       // (roundTo0<<16) | adjust
            fld         real ptr floatreg           // adjust
            fcomp
            fstsw       AX
            fstcw       floatreg+12
            fldcw       floatreg+10                 // roundTo0
            test        AH,1
            jz          L1                          // jae L1

            fld         real ptr floatreg           // adjust
            fsubp       ST(1), ST
            fistp       floatreg
            mov         RAX,floatreg
            shl         RDX,32
            add         RAX,RDX
            fldcw       floatreg+12
            jmp         L2

    L1:
            fistp       floatreg
            mov         RAX,floatreg
            fldcw       floatreg+12
    L2:
     */
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1, &retregs, false);
    tym_t tym = e.Ety;
    retregs = *pretregs;
    if (!retregs)
        retregs = ALLREGS;
    reg_t reg;
    allocreg(cdb,&retregs,&reg,tym);
    regm_t regm2 = ALLREGS & ~retregs & ~mAX;
    reg_t reg2;
    allocreg(cdb,&regm2,&reg2,tym);
    movregconst(cdb,reg2,0x80000000,0);
    getregs(cdb,mask(reg2) | mAX);

    cdb.genfltreg(0xC7,0,0);
    code *cf1 = cdb.last();
    cf1.IFL2 = FLconst;
    cf1.IEV2.Vint = 0;                             // MOV floatreg+0,0
    cdb.genfltreg(STO,reg2,4);                      // MOV floatreg+4,EDX
    cdb.genfltreg(0xC7,0,8);
    code *cf3 = cdb.last();
    cf3.IFL2 = FLconst;
    cf3.IEV2.Vint = 0xFBF403E;                     // MOV floatreg+8,(roundTo0<<16)|adjust

    push87(cdb);
    cdb.genfltreg(0xDB,5,0);                        // FLD real ptr floatreg
    cdb.gen2(0xD8,0xD9);                            // FCOMP
    pop87();
    cdb.gen2(0xDF,0xE0);                            // FSTSW AX
    cdb.genfltreg(0xD9,7,12);                       // FSTCW floatreg+12
    cdb.genfltreg(0xD9,5,10);                       // FLDCW floatreg+10
    cdb.genc2(0xF6,modregrm(3,0,4),1);              // TEST AH,1
    code *cnop1 = gennop(null);
    genjmp(cdb,JE,FLcode,cast(block *)cnop1);       // JZ L1

    cdb.genfltreg(0xDB,5,0);                        // FLD real ptr floatreg
    cdb.genf2(0xDE,0xE8+1);                         // FSUBP ST(1),ST
    cdb.genfltreg(0xDF,7,0);                        // FISTP dword ptr floatreg
    cdb.genfltreg(LOD,reg,0);                       // MOV reg,floatreg
    code_orrex(cdb.last(), REX_W);
    cdb.genc2(0xC1,(REX_W << 16) | modregrmx(3,4,reg2),32); // SHL reg2,32
    cdb.gen2(0x03,(REX_W << 16) | modregxrmx(3,reg,reg2));  // ADD reg,reg2
    cdb.genfltreg(0xD9,5,12);                       // FLDCW floatreg+12
    code *cnop2 = gennop(null);
    genjmp(cdb,JMP,FLcode,cast(block *)cnop2);      // JMP L2

    cdb.append(cnop1);
    cdb.genfltreg(0xDF,7,0);                        // FISTP dword ptr floatreg
    cdb.genfltreg(LOD,reg,0);                       // MOV reg,floatreg
    code_orrex(cdb.last(), REX_W);
    cdb.genfltreg(0xD9,5,12);                       // FLDCW floatreg+12
    cdb.append(cnop2);

    pop87();
    fixresult(cdb,e,retregs,pretregs);
}

/************************
 * Do the following opcodes:
 *      OPd_u32
 */
@trusted
void cdd_u32(ref CodeBuilder cdb, elem *e, regm_t *pretregs)
{
    assert(I32 || I64);

    /* Generate:
            mov         floatreg+8,0x0FBF0000   // (roundTo0<<16)
            fstcw       floatreg+12
            fldcw       floatreg+10             // roundTo0
            fistp       floatreg
            fldcw       floatreg+12
            mov         EAX,floatreg
     */
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1, &retregs, false);
    tym_t tym = e.Ety;
    retregs = *pretregs & ALLREGS;
    if (!retregs)
        retregs = ALLREGS;
    reg_t reg;
    allocreg(cdb,&retregs,&reg,tym);

    cdb.genfltreg(0xC7,0,8);
    code *cf3 = cdb.last();
    cf3.IFL2 = FLconst;
    cf3.IEV2.Vint = 0x0FBF0000;                 // MOV floatreg+8,(roundTo0<<16)

    cdb.genfltreg(0xD9,7,12);                    // FSTCW floatreg+12
    cdb.genfltreg(0xD9,5,10);                    // FLDCW floatreg+10

    cdb.genfltreg(0xDF,7,0);                     // FISTP dword ptr floatreg
    cdb.genfltreg(0xD9,5,12);                    // FLDCW floatreg+12
    cdb.genfltreg(LOD,reg,0);                    // MOV reg,floatreg

    pop87();
    fixresult(cdb,e,retregs,pretregs);
}

/************************
 * Do the following opcodes:
 *      OPd_s16
 *      OPd_s32
 *      OPd_u16
 *      OPd_s64
 */

@trusted
void cnvt87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    regm_t retregs;
    uint mf,rf;
    reg_t reg;
    int clib;

    //printf("cnvt87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    assert(*pretregs);
    tym_t tym = e.Ety;
    int sz = tysize(tym);
    int szoff = sz;

    switch (e.Eoper)
    {
        case OPd_s16:
            clib = CLIB.dblint87;
            mf = ESC(MFword,1);
            rf = 3;
            break;

        case OPd_u16:
            szoff = 4;
            goto case OPd_s32;

        case OPd_s32:
            clib = CLIB.dbllng87;
            mf = ESC(MFlong,1);
            rf = 3;
            break;

        case OPd_s64:
            clib = CLIB.dblllng;
            mf = 0xDF;
            rf = 7;
            break;

        default:
            assert(0);
    }

    if (I16)                       // C may change the default control word
    {
        if (clib == CLIB.dblllng)
        {   retregs = I32 ? DOUBLEREGS_32 : DOUBLEREGS_16;
            codelem(cdb,e.EV.E1,&retregs,false);
            callclib(cdb,e,clib,pretregs,0);
        }
        else
        {   retregs = mST0; //I32 ? DOUBLEREGS_32 : DOUBLEREGS_16;
            codelem(cdb,e.EV.E1,&retregs,false);
            callclib(cdb,e,clib,pretregs,0);
            pop87();
        }
    }
    else if (1)
    {   //  Generate:
        //  sub     ESP,12
        //  fstcw   8[ESP]
        //  fldcw   roundto0
        //  fistp   long64 ptr [ESP]
        //  fldcw   8[ESP]
        //  pop     lsw
        //  pop     msw
        //  add     ESP,4

        uint szpush = szoff + 2;
        if (config.flags3 & CFG3pic)
            szpush += 2;
        szpush = (szpush + REGSIZE - 1) & ~(REGSIZE - 1);

        retregs = mST0;
        codelem(cdb,e.EV.E1,&retregs,false);

        if (szpush == REGSIZE)
            cdb.gen1(0x50 + AX);                // PUSH EAX
        else
            cod3_stackadj(cdb, szpush);
        genfwait(cdb);
        cdb.genc1(0xD9,modregrm(2,7,4) + 256*modregrm(0,4,SP),FLconst,szoff); // FSTCW szoff[ESP]

        genfwait(cdb);

        if (config.flags3 & CFG3pic)
        {
            cdb.genc(0xC7,modregrm(2,0,4) + 256*modregrm(0,4,SP),FLconst,szoff+2,FLconst,CW_roundto0); // MOV szoff+2[ESP], CW_roundto0
            code_orflag(cdb.last(), CFopsize);
            cdb.genc1(0xD9,modregrm(2,5,4) + 256*modregrm(0,4,SP),FLconst,szoff+2); // FLDCW szoff+2[ESP]
        }
        else
            genrnd(cdb, CW_roundto0);   // FLDCW roundto0

        pop87();

        genfwait(cdb);
        cdb.gen2sib(mf,modregrm(0,rf,4),modregrm(0,4,SP));                   // FISTP [ESP]

        retregs = *pretregs & (ALLREGS | mBP);
        if (!retregs)
                retregs = ALLREGS;
        allocreg(cdb,&retregs,&reg,tym);

        genfwait(cdb);                                           // FWAIT
        cdb.genc1(0xD9,modregrm(2,5,4) + 256*modregrm(0,4,SP),FLconst,szoff); // FLDCW szoff[ESP]

        if (szoff > REGSIZE)
        {   szpush -= REGSIZE;
            genpop(cdb,findreglsw(retregs));       // POP lsw
        }
        szpush -= REGSIZE;
        genpop(cdb,reg);                           // POP reg

        if (szpush)
            cod3_stackadj(cdb, -szpush);
        fixresult(cdb,e,retregs,pretregs);
    }
    else
    {
        // This is incorrect. For -inf and nan, the 8087 returns the largest
        // negative int (0x80000....). For -inf, 0x7FFFF... should be returned,
        // and for nan, 0 should be returned.
        retregs = mST0;
        codelem(cdb,e.EV.E1,&retregs,false);

        genfwait(cdb);
        genrnd(cdb, CW_roundto0);                  // FLDCW roundto0

        pop87();
        cdb.genfltreg(mf,rf,0);                    // FISTP floatreg
        retregs = *pretregs & (ALLREGS | mBP);
        if (!retregs)
                retregs = ALLREGS;
        allocreg(cdb,&retregs,&reg,tym);

        genfwait(cdb);

        if (sz > REGSIZE)
        {
            cdb.genfltreg(LOD,reg,REGSIZE);          // MOV reg,floatreg + REGSIZE
                                                     // MOV lsreg,floatreg
            cdb.genfltreg(LOD,findreglsw(retregs),0);
        }
        else
            cdb.genfltreg(LOD,reg,0);                // MOV reg,floatreg
        genrnd(cdb, CW_roundtonearest);              // FLDCW roundtonearest
        fixresult(cdb,e,retregs,pretregs);
    }
}

/************************
 * Do OPrndtol.
 */

@trusted
void cdrndtol(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    if (*pretregs == 0)
    {
        codelem(cdb,e.EV.E1,pretregs,false);
        return;
    }
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1,&retregs,false);

    ubyte op1,op2;
    tym_t tym = e.Ety;
    uint sz = tysize(tym);
    switch (sz)
    {   case 2:
            op1 = 0xDF;
            op2 = 3;
            break;
        case 4:
            op1 = 0xDB;
            op2 = 3;
            break;
        case 8:
            op1 = 0xDF;
            op2 = 7;
            break;
        default:
            assert(0);
    }

    pop87();
    cdb.genfltreg(op1,op2,0);           // FISTP floatreg
    retregs = *pretregs & (ALLREGS | mBP);
    if (!retregs)
        retregs = ALLREGS;
    reg_t reg;
    allocreg(cdb,&retregs,&reg,tym);
    genfwait(cdb);                      // FWAIT
    if (tysize(tym) > REGSIZE)
    {
        cdb.genfltreg(LOD,reg,REGSIZE);             // MOV reg,floatreg + REGSIZE
                                                    // MOV lsreg,floatreg
        cdb.genfltreg(LOD,findreglsw(retregs),0);
    }
    else
    {
        cdb.genfltreg(LOD,reg,0);       // MOV reg,floatreg
        if (tysize(tym) == 8 && I64)
            code_orrex(cdb.last(), REX_W);
    }
    fixresult(cdb,e,retregs,pretregs);
}

/*************************
 * Do OPscale, OPyl2x, OPyl2xp1.
 */

@trusted
void cdscale(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    assert(*pretregs != 0);

    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1,&retregs,false);
    note87(e.EV.E1,0,0);
    codelem(cdb,e.EV.E2,&retregs,false);
    makesure87(cdb,e.EV.E1,0,1,0);       // now have x,y on stack; need y,x
    switch (e.Eoper)
    {
        case OPscale:
            cdb.genf2(0xD9,0xFD);                   // FSCALE
            cdb.genf2(0xDD,0xD8 + 1);                    // FSTP ST(1)
            break;

        case OPyl2x:
            cdb.genf2(0xD9,0xF1);                   // FYL2X
            break;

        case OPyl2xp1:
            cdb.genf2(0xD9,0xF9);                   // FYL2XP1
            break;

        default:
            assert(0);
    }
    pop87();
    fixresult87(cdb,e,mST0,pretregs);
}


/**********************************
 * Unary -, absolute value, square root, sine, cosine
 */

@trusted
void neg87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    //printf("neg87()\n");

    assert(*pretregs);
    opcode_t op;
    switch (e.Eoper)
    {   case OPneg:  op = 0xE0;     break;
        case OPabs:  op = 0xE1;     break;
        case OPsqrt: op = 0xFA;     break;
        case OPsin:  op = 0xFE;     break;
        case OPcos:  op = 0xFF;     break;
        case OPrint: op = 0xFC;     break;  // FRNDINT
        default:
            assert(0);
    }
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1,&retregs,false);
    cdb.genf2(0xD9,op);                 // FCHS/FABS/FSQRT/FSIN/FCOS/FRNDINT
    fixresult87(cdb,e,mST0,pretregs);
}

/**********************************
 * Unary - for complex operands
 */

@trusted
void neg_complex87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    assert(e.Eoper == OPneg);
    regm_t retregs = mST01;
    codelem(cdb,e.EV.E1,&retregs,false);
    cdb.genf2(0xD9,0xE0);           // FCHS
    cdb.genf2(0xD9,0xC8 + 1);            // FXCH ST(1)
    cdb.genf2(0xD9,0xE0);                // FCHS
    cdb.genf2(0xD9,0xC8 + 1);            // FXCH ST(1)
    fixresult_complex87(cdb,e,mST01,pretregs);
}

/*********************************
 */

@trusted
void cdind87(ref CodeBuilder cdb,elem *e,regm_t *pretregs)
{
    //printf("cdind87(e = %p, *pretregs = %s)\n",e,regm_str(*pretregs));
    code cs;

    getlvalue87(cdb,&cs,e,0);           // get addressing mode
    if (*pretregs)
    {
        switch (tybasic(e.Ety))
        {   case TYfloat:
            case TYifloat:
                cs.Iop = 0xD9;
                break;

            case TYidouble:
            case TYdouble:
            case TYdouble_alias:
                cs.Iop = 0xDD;
                break;

            case TYildouble:
            case TYldouble:
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0,5,0);
                break;

            default:
                assert(0);
        }
        push87(cdb);
        cdb.gen(&cs);                 // FLD EA
        fixresult87(cdb,e,mST0,pretregs);
    }
}

/************************************
 * Reset statics for another .obj file.
 */

@trusted
void cg87_reset()
{
    memset(&oldd,0,oldd.sizeof);
}


/*****************************************
 * Initialize control word constants.
 */

@trusted
private void genrnd(ref CodeBuilder cdb, short cw)
{
    if (config.flags3 & CFG3pic)
    {
        cdb.genfltreg(0xC7, 0, 0);       // MOV floatreg, cw
        code *c1 = cdb.last();
        c1.IFL2 = FLconst;
        c1.IEV2.Vuns = cw;

        cdb.genfltreg(0xD9, 5, 0);         // FLDCW floatreg
    }
    else
    {
        if (!oldd.round)                // if not initialized
        {
            short cwi;

            oldd.round = 1;

            cwi = CW_roundto0;          // round to 0
            oldd.roundto0 = out_readonly_sym(TYshort,&cwi,2);
            cwi = CW_roundtonearest;            // round to nearest
            oldd.roundtonearest = out_readonly_sym(TYshort,&cwi,2);
        }
        Symbol *rnddir = (cw == CW_roundto0) ? oldd.roundto0 : oldd.roundtonearest;
        code cs;
        cs.Iop = 0xD9;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IEV1.Vsym = rnddir;
        cs.IFL1 = rnddir.Sfl;
        cs.IEV1.Voffset = 0;
        cs.Irm = modregrm(0,5,BPRM);
        cdb.gen(&cs);
    }
}

/************************* Complex Numbers *********************/

/***************************
 * Set the PSW based on the state of ST01.
 * Input:
 *      pop     if stack should be popped after test
 */

@trusted
private void genctst(ref CodeBuilder cdb,elem *e,int pop)
{
    assert(pop == 0 || pop == 1);

    // Generate:
    //  if (NOSAHF && pop)
    //          FLDZ
    //          FUCOMIP
    //          JNE     L1
    //          JP      L1              // if NAN
    //          FLDZ
    //          FUCOMIP ST(2)
    //      L1:
    //        if (pop)
    //          FPOP
    //          FPOP
    //  if (pop)
    //          FLDZ
    //          FUCOMPP
    //          FSTSW   AX
    //          SAHF
    //          FLDZ
    //          FUCOMPP
    //          JNE     L1
    //          JP      L1              // if NAN
    //          FSTSW   AX
    //          SAHF
    //      L1:
    //  else
    //          FLDZ
    //          FUCOM
    //          FSTSW   AX
    //          SAHF
    //          FUCOMP  ST(2)
    //          JNE     L1
    //          JP      L1              // if NAN
    //          FSTSW   AX
    //          SAHF
    //      L1:
    // FUCOMP doesn't raise exceptions on QNANs, unlike FTST

    CodeBuilder cdbnop;
    cdbnop.ctor();
    cdbnop.gennop();
    code *cnop = cdbnop.peek();
    push87(cdb);
    cdb.gen2(0xD9,0xEE);                       // FLDZ
    if (NOSAHF)
    {
        cdb.gen2(0xDF,0xE9);                   // FUCOMIP
        pop87();
        genjmp(cdb,JNE,FLcode,cast(block *) cnop); // JNE     L1
        genjmp(cdb,JP, FLcode,cast(block *) cnop); // JP      L1
        cdb.gen2(0xD9,0xEE);                   // FLDZ
        cdb.gen2(0xDF,0xEA);                   // FUCOMIP ST(2)
        if (pop)
        {
            cdbnop.genf2(0xDD,modregrm(3,3,0));  // FPOP
            cdbnop.genf2(0xDD,modregrm(3,3,0));  // FPOP
            pop87();
            pop87();
        }
    }
    else if (pop)
    {
        cdb.gen2(0xDA,0xE9);                   // FUCOMPP
        pop87();
        pop87();
        cg87_87topsw(cdb);                     // put 8087 flags in CPU flags
        cdb.gen2(0xD9,0xEE);                   // FLDZ
        cdb.gen2(0xDA,0xE9);                   // FUCOMPP
        pop87();
        genjmp(cdb,JNE,FLcode,cast(block *) cnop); // JNE     L1
        genjmp(cdb,JP, FLcode,cast(block *) cnop); // JP      L1
        cg87_87topsw(cdb);                     // put 8087 flags in CPU flags
    }
    else
    {
        cdb.gen2(0xDD,0xE1);                   // FUCOM
        cg87_87topsw(cdb);                     // put 8087 flags in CPU flags
        cdb.gen2(0xDD,0xEA);                   // FUCOMP ST(2)
        pop87();
        genjmp(cdb,JNE,FLcode,cast(block *) cnop); // JNE     L1
        genjmp(cdb,JP, FLcode,cast(block *) cnop); // JP      L1
        cg87_87topsw(cdb);                     // put 8087 flags in CPU flags
    }
    cdb.append(cdbnop);
}

/******************************
 * Given the result of an expression is in retregs,
 * generate necessary code to return result in *pretregs.
 */

@trusted
void fixresult_complex87(ref CodeBuilder cdb,elem *e,regm_t retregs,regm_t *pretregs, bool isReturnValue = false)
{
    static if (0)
    {
        printf("fixresult_complex87(e = %p, retregs = %s, *pretregs = %s)\n",
            e,regm_str(retregs),regm_str(*pretregs));
    }

    assert(!*pretregs || retregs);
    tym_t tym = tybasic(e.Ety);
    uint sz = _tysize[tym];

    if (isReturnValue)
    {
        // In loadComplex and complex_eq87, complex numbers have the real part
        // pushed to the FPU stack first (ST1), then the imaginary part (ST0).
        // However, the Intel 64 bit ABI scheme requires that types classified
        // as complex x87 instead have the real part returned in ST0, and the
        // imaginary part in ST1.
        if (retregs == mST01 && I64 && (config.exe & EX_posix))
            cdb.genf2(0xD9, 0xC8 + 1);          // FXCH ST(1)
    }

    if (*pretregs == 0 && retregs == mST01)
    {
        cdb.genf2(0xDD,modregrm(3,3,0));        // FPOP
        pop87();
        cdb.genf2(0xDD,modregrm(3,3,0));        // FPOP
        pop87();
    }
    else if (tym == TYllong)
    {
        // passing cfloat through register for I64
        assert(retregs & mST01, "this float expression is not implemented");
        pop87();
        cdb.genfltreg(ESC(MFfloat,1),BX,4);     // FSTP floatreg
        pop87();
        cdb.genfltreg(ESC(MFfloat,1),BX,0);     // FSTP floatreg+4
        genfwait(cdb);
        const reg = findreg(*pretregs);
        getregs(cdb,reg);
        cdb.genfltreg(LOD, reg, 0);             // MOV ECX,floatreg
        code_orrex(cdb.last(), REX_W);          // extend to RCX
    }
    else if (tym == TYcfloat && *pretregs & (mAX|mDX) && retregs & mST01)
    {
        if (*pretregs & mPSW && !(retregs & mPSW))
            genctst(cdb,e,0);                   // FTST
        pop87();
        cdb.genfltreg(ESC(MFfloat,1),3,0);      // FSTP floatreg
        genfwait(cdb);
        getregs(cdb,mDX|mAX);
        cdb.genfltreg(LOD, DX, 0);              // MOV EDX,floatreg

        pop87();
        cdb.genfltreg(ESC(MFfloat,1),3,0);      // FSTP floatreg
        genfwait(cdb);
        cdb.genfltreg(LOD, AX, 0);              // MOV EAX,floatreg
    }
    else if (tym == TYcfloat && retregs & (mAX|mDX) && *pretregs & mST01)
    {
        push87(cdb);
        cdb.genfltreg(STO, AX, 0);              // MOV floatreg, EAX
        cdb.genfltreg(0xD9, 0, 0);              // FLD float ptr floatreg

        push87(cdb);
        cdb.genfltreg(STO, DX, 0);              // MOV floatreg, EDX
        cdb.genfltreg(0xD9, 0, 0);              // FLD float ptr floatreg

        if (*pretregs & mPSW)
            genctst(cdb,e,0);                   // FTST
    }
    else if ((tym == TYcfloat || tym == TYcdouble) &&
             *pretregs & (mXMM0|mXMM1) && retregs & mST01)
    {
        tym_t tyf = tym == TYcfloat ? TYfloat : TYdouble;
        uint xop = xmmload(tyf);
        uint mf = tyf == TYfloat ? MFfloat : MFdouble;
        if (*pretregs & mPSW && !(retregs & mPSW))
            genctst(cdb,e,0);                   // FTST
        pop87();
        cdb.genfltreg(ESC(mf,1),3,0);           // FSTP floatreg
        genfwait(cdb);
        getregs(cdb,mXMM0|mXMM1);
        cdb.genxmmreg(xop,XMM1,0,tyf);

        pop87();
        cdb.genfltreg(ESC(mf,1),3,0);           // FSTP floatreg
        genfwait(cdb);
        cdb.genxmmreg(xop, XMM0, 0, tyf);       // MOVD XMM0,floatreg
    }
    else if ((tym == TYcfloat || tym == TYcdouble) &&
             retregs & (mXMM0|mXMM1) && *pretregs & mST01)
    {
        tym_t tyf = tym == TYcfloat ? TYfloat : TYdouble;
        uint xop = xmmstore(tyf);
        uint fop = tym == TYcfloat ? 0xD9 : 0xDD;
        push87(cdb);
        cdb.genfltreg(xop, XMM0-XMM0, 0);       // STOS(SD) floatreg, XMM0
        checkSetVex(cdb.last(),tyf);
        cdb.genfltreg(fop, 0, 0);               // FLD double ptr floatreg

        push87(cdb);
        cdb.genxmmreg(xop, XMM1, 0, tyf);       // MOV floatreg, XMM1
        cdb.genfltreg(fop, 0, 0);               // FLD double ptr floatreg

        if (*pretregs & mPSW)
            genctst(cdb,e,0);                   // FTST
    }
    else
    {   if (*pretregs & mPSW)
        {   if (!(retregs & mPSW))
            {   assert(retregs & mST01);
                genctst(cdb,e,!(*pretregs & mST01));        // FTST
            }
        }
        assert(!(*pretregs & mST01) || (retregs & mST01));
    }
    if (*pretregs & mST01)
    {   note87(e,0,1);
        note87(e,sz/2,0);
    }
}

/*****************************************
 * Operators OPc_r and OPc_i
 */

@trusted
void cdconvt87(ref CodeBuilder cdb, elem *e, regm_t *pretregs)
{
    regm_t retregs = mST01;
    codelem(cdb,e.EV.E1, &retregs, false);
    switch (e.Eoper)
    {
        case OPc_r:
            cdb.genf2(0xDD,0xD8 + 0); // FPOP
            pop87();
            break;

        case OPc_i:
            cdb.genf2(0xDD,0xD8 + 1); // FSTP ST(1)
            pop87();
            break;

        default:
            assert(0);
    }
    retregs = mST0;
    fixresult87(cdb, e, retregs, pretregs);
}

/**************************************
 * Load complex operand into ST01 or flags or both.
 */

@trusted
void cload87(ref CodeBuilder cdb, elem *e, regm_t *pretregs)
{
    //printf("e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    //elem_print(e);
    assert(!I16);
    debug
    if (I32)
    {
        assert(config.inline8087);
        elem_debug(e);
        assert(*pretregs & (mST01 | mPSW));
        assert(!(*pretregs & ~(mST01 | mPSW)));
    }

    tym_t ty = tybasic(e.Ety);
    code cs = void;
    uint mf;
    uint sz;
    ubyte ldop;
    regm_t retregs;
    int i;

    //printf("cload87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    sz = _tysize[ty] / 2;
    memset(&cs, 0, cs.sizeof);
    if (ADDFWAIT())
        cs.Iflags = CFwait;
    switch (ty)
    {
        case TYcfloat:      mf = MFfloat;           break;
        case TYcdouble:     mf = MFdouble;          break;
        case TYcldouble:    break;
        default:            assert(0);
    }
    switch (e.Eoper)
    {
        case OPvar:
            notreg(e);                  // never enregister this variable
            goto case OPind;

        case OPind:
            push87(cdb);
            push87(cdb);
            switch (ty)
            {
                case TYcfloat:
                case TYcdouble:
                    loadea(cdb,e,&cs,ESC(mf,1),0,0,0,0);        // FLD var
                    cs.IEV1.Voffset += sz;
                    cdb.gen(&cs);
                    break;

                case TYcldouble:
                    loadea(cdb,e,&cs,0xDB,5,0,0,0);             // FLD var
                    cs.IEV1.Voffset += sz;
                    cdb.gen(&cs);
                    break;

                default:
                    assert(0);
            }
            retregs = mST01;
            break;

        case OPd_ld:
        case OPld_d:
        case OPf_d:
        case OPd_f:
            cload87(cdb,e.EV.E1, pretregs);
            freenode(e.EV.E1);
            return;

        case OPconst:
            push87(cdb);
            push87(cdb);
            for (i = 0; i < 2; i++)
            {
                ldop = loadconst(e, i);
                if (ldop)
                {
                    cdb.genf2(0xD9,ldop);             // FLDx
                }
                else
                {
                    assert(0);
                }
            }
            retregs = mST01;
            break;

        default:
            debug elem_print(e);
            assert(0);
    }
    fixresult_complex87(cdb, e, retregs, pretregs);
}

/**********************************************
 * Load OPpair or OPrpair into mST01
 */
@trusted
void loadPair87(ref CodeBuilder cdb, elem *e, regm_t *pretregs)
{
    assert(e.Eoper == OPpair || e.Eoper == OPrpair);
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1, &retregs, false);
    note87(e.EV.E1, 0, 0);
    codelem(cdb,e.EV.E2, &retregs, false);
    makesure87(cdb,e.EV.E1, 0, 1, 0);
    if (e.Eoper == OPrpair)
        cdb.genf2(0xD9, 0xC8 + 1);   // FXCH ST(1)
    retregs = mST01;
    fixresult_complex87(cdb, e, retregs, pretregs);
}

/**********************************************
 * Round 80 bit precision to 32 or 64 bits.
 * OPtoprec
 */
@trusted
void cdtoprec(ref CodeBuilder cdb, elem* e, regm_t* pretregs)
{
    //printf("cdtoprec: *pretregs = %s\n", regm_str(*pretregs));
    if (!*pretregs)
    {
        codelem(cdb,e.EV.E1,pretregs,false);
        return;
    }

    assert(config.inline8087);
    regm_t retregs = mST0;
    codelem(cdb,e.EV.E1, &retregs, false);
    if (*pretregs & mST0)
    {
        const tym = tybasic(e.Ety);
        const sz = _tysize[tym];
        uint mf = (sz == FLOATSIZE) ? MFfloat : MFdouble;
        cdb.genfltreg(ESC(mf,1),3,0);   // FSTP float/double ptr fltreg
        genfwait(cdb);
        cdb.genfltreg(ESC(mf,1),0,0);   // FLD float/double ptr fltreg
    }
    fixresult87(cdb, e, retregs, pretregs);
}

}
