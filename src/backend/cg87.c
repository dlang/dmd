// Copyright (C) 1987-1995 by Symantec
// Copyright (C) 2000-2013 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        <math.h>
#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "code.h"
#include        "global.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

// Constants that the 8087 supports directly
// BUG: rewrite for 80 bit long doubles
#define PI              3.14159265358979323846
#define LOG2            0.30102999566398119521
#define LN2             0.6931471805599453094172321
#define LOG2T           3.32192809488736234787
#define LOG2E           1.4426950408889634074   /* 1/LN2                */

#define FWAIT   0x9B            /* FWAIT opcode                         */

/* Mark variable referenced by e as not a register candidate            */
#define notreg(e)       ((e)->EV.sp.Vsym->Sflags &= ~GTregcand)

/* Generate the appropriate ESC instruction     */
#define ESC(MF,b)       (0xD8 + ((MF) << 1) + (b))
enum MF
{       // Values for MF
        MFfloat         = 0,
        MFlong          = 1,
        MFdouble        = 2,
        MFword          = 3
};

NDP _8087elems[8];              // 8087 stack
NDP ndp_zero;

int stackused = 0;              /* number of items on the 8087 stack    */

/*********************************
 */

struct Dconst
{
    int round;
    symbol *roundto0;
    symbol *roundtonearest;
};

static Dconst oldd;

#define NDPP    0       // print out debugging info
#define NOSAHF  (I64 || config.fpxmmregs)     // can't use SAHF instruction

code *loadComplex(elem *e);
code *opmod_complex87(elem *e,regm_t *pretregs);
code *opass_complex87(elem *e,regm_t *pretregs);
code * genf2(code *c,unsigned op,unsigned rm);

#define CW_roundto0             0xFBF
#define CW_roundtonearest       0x3BF

STATIC code *genrnd(code *c, short cw);

/**********************************
 * When we need to temporarilly save 8087 registers, we record information
 * about the save into an array of NDP structs:
 */

NDP *NDP::save = NULL;
int NDP::savemax = 0;           /* # of entries in NDP::save[]          */
int NDP::savetop = 0;           /* # of entries used in NDP::save[]     */

#ifdef DEBUG
#define NDPSAVEINC 2            /* flush reallocation bugs              */
#else
#define NDPSAVEINC 8            /* allocation chunk sizes               */
#endif

/****************************************
 * Store/load to ndp save location i
 */

code *ndp_fstp(code *c, int i, tym_t ty)
{   unsigned grex = I64 ? (REX_W << 16) : 0;
    switch (tybasic(ty))
    {
        case TYfloat:
        case TYifloat:
        case TYcfloat:
            c = genc1(c,0xD9,grex | modregrm(2,3,BPRM),FLndp,i); // FSTP m32real i[BP]
            break;

        case TYdouble:
        case TYdouble_alias:
        case TYidouble:
        case TYcdouble:
            c = genc1(c,0xDD,grex | modregrm(2,3,BPRM),FLndp,i); // FSTP m64real i[BP]
            break;

        case TYldouble:
        case TYildouble:
        case TYcldouble:
            c = genc1(c,0xDB,grex | modregrm(2,7,BPRM),FLndp,i); // FSTP m80real i[BP]
            break;

        default:
            assert(0);
    }
    return c;
}

code *ndp_fld(code *c, int i, tym_t ty)
{   unsigned grex = I64 ? (REX_W << 16) : 0;
    switch (tybasic(ty))
    {
        case TYfloat:
        case TYifloat:
        case TYcfloat:
            c = genc1(c,0xD9,grex | modregrm(2,0,BPRM),FLndp,i);
            break;

        case TYdouble:
        case TYdouble_alias:
        case TYidouble:
        case TYcdouble:
            c = genc1(c,0xDD,grex | modregrm(2,0,BPRM),FLndp,i);
            break;

        case TYldouble:
        case TYildouble:
        case TYcldouble:
            c = genc1(c,0xDB,grex | modregrm(2,5,BPRM),FLndp,i); // FLD m80real i[BP]
            break;

        default:
            assert(0);
    }
    return c;
}

/**************************
 * Return index of empty slot in NDP::save[].
 */

STATIC int getemptyslot()
{       int i;

        for (i = 0; i < NDP::savemax; i++)
                if (NDP::save[i].e == NULL)
                        goto L1;
        /* Out of room, reallocate NDP::save[]  */
        NDP::save = (NDP *)mem_realloc(NDP::save,
                (NDP::savemax + NDPSAVEINC) * sizeof(*NDP::save));
        /* clear out new portion of NDP::save[] */
        memset(NDP::save + NDP::savemax,0,NDPSAVEINC * sizeof(*NDP::save));
        i = NDP::savemax;
        NDP::savemax += NDPSAVEINC;

    L1: if (i >= NDP::savetop)
                NDP::savetop = i + 1;
        return i;
}

/*********************************
 * Pop 8087 stack.
 */

#undef pop87

void pop87(
#ifdef DEBUG
        int line, const char *file
#endif
        )
#ifdef DEBUG
#define pop87() pop87(__LINE__,__FILE__)
#endif
{
        int i;

#if NDPP
        dbg_printf("pop87(%s(%d): stackused=%d)\n", file, line, stackused);
#endif
        --stackused;
        assert(stackused >= 0);
        for (i = 0; i < arraysize(_8087elems) - 1; i++)
                _8087elems[i] = _8087elems[i + 1];
        /* end of stack is nothing      */
        _8087elems[arraysize(_8087elems) - 1] = ndp_zero;
}

/*******************************
 * Push 8087 stack. Generate and return any code
 * necessary to preserve anything that might run off the end of the stack.
 */

#undef push87

#ifdef DEBUG
code *push87(int line, const char *file);
code *push87() { return push87(__LINE__,__FILE__); }
#endif

code *push87(
#ifdef DEBUG
        int line, const char *file
#endif
        )
#ifdef DEBUG
#define push87() push87(__LINE__,__FILE__)
#endif
{
        code *c;
        int i;

        c = CNIL;
        // if we would lose the top register off of the stack
        if (_8087elems[7].e != NULL)
        {
                i = getemptyslot();
                NDP::save[i] = _8087elems[7];
                c = genf2(c,0xD9,0xF6);         // FDECSTP
                c = genfwait(c);
                c = ndp_fstp(c, i, _8087elems[7].e->Ety);       // FSTP i[BP]
                assert(stackused == 8);
                if (NDPP) dbg_printf("push87() : overflow\n");
        }
        else
        {
#ifdef DEBUG
                if (NDPP) dbg_printf("push87(%s(%d): %d)\n", file, line, stackused);
#endif
                stackused++;
                assert(stackused <= 8);
        }
        // Shift the stack up
        for (i = 7; i > 0; i--)
                _8087elems[i] = _8087elems[i - 1];
        _8087elems[0] = ndp_zero;
        return c;
}

/*****************************
 * Note elem e as being in ST(i) as being a value we want to keep.
 */

#ifdef DEBUG
void note87(elem *e, unsigned offset, int i, int linnum);
void note87(elem *e, unsigned offset, int i)
{
    return note87(e, offset, i, 0);
}
void note87(elem *e, unsigned offset, int i, int linnum)
#define note87(e,offset,i) note87(e,offset,i,__LINE__)
#else
void note87(elem *e, unsigned offset, int i)
#endif
{
#if NDPP
        printf("note87(e = %p.%d, i = %d, stackused = %d, line = %d)\n",e,offset,i,stackused,linnum);
#endif
#if 0 && DEBUG
        if (_8087elems[i].e)
                printf("_8087elems[%d].e = %p\n",i,_8087elems[i].e);
#endif
        //if (i >= stackused) *(char*)0=0;
        assert(i < stackused);
        while (e->Eoper == OPcomma)
            e = e->E2;
        _8087elems[i].e = e;
        _8087elems[i].offset = offset;
}

/****************************************************
 * Exchange two entries in 8087 stack.
 */

void xchg87(int i, int j)
{
    NDP save;

    save = _8087elems[i];
    _8087elems[i] = _8087elems[j];
    _8087elems[j] = save;
}

/****************************
 * Make sure that elem e is in register ST(i). Reload it if necessary.
 * Input:
 *      i       0..3    8087 register number
 *      flag    1       don't bother with FXCH
 */

#ifdef DEBUG
STATIC code * makesure87(elem *e,unsigned offset,int i,unsigned flag,int linnum)
#define makesure87(e,offset,i,flag)     makesure87(e,offset,i,flag,__LINE__)
#else
STATIC code * makesure87(elem *e,unsigned offset,int i,unsigned flag)
#endif
{
#ifdef DEBUG
        if (NDPP) printf("makesure87(e=%p, offset=%d, i=%d, flag=%d, line=%d)\n",e,offset,i,flag,linnum);
#endif
        while (e->Eoper == OPcomma)
            e = e->E2;
        assert(e && i < 4);
        code *c = CNIL;
    L1:
        if (_8087elems[i].e != e || _8087elems[i].offset != offset)
        {
#ifdef DEBUG
                if (_8087elems[i].e)
                    printf("_8087elems[%d].e = %p, .offset = %d\n",i,_8087elems[i].e,_8087elems[i].offset);
#endif
                assert(_8087elems[i].e == NULL);
                int j;
                for (j = 0; 1; j++)
                {
                    if (j >= NDP::savetop && e->Eoper == OPcomma)
                    {
                        e = e->E2;              // try right side
                        goto L1;
                    }
#ifdef DEBUG
                    if (j >= NDP::savetop)
                        printf("e = %p, NDP::savetop = %d\n",e,NDP::savetop);
#endif
                    assert(j < NDP::savetop);
                    //printf("\tNDP::save[%d] = %p, .offset = %d\n", j, NDP::save[j].e, NDP::save[j].offset);
                    if (e == NDP::save[j].e && offset == NDP::save[j].offset)
                        break;
                }
                c = push87();
                c = genfwait(c);
                c = ndp_fld(c, j, e->Ety);              // FLD j[BP]
                if (!(flag & 1))
                {
                    while (i != 0)
                    {
                        genf2(c,0xD9,0xC8 + i);         // FXCH ST(i)
                        i--;
                    }
                }
                NDP::save[j] = ndp_zero;                // back in 8087
        }
        //_8087elems[i].e = NULL;
        return c;
}

/****************************
 * Save in memory any values in the 8087 that we want to keep.
 */

code *save87()
{
        code *c;
        int i;

        c = CNIL;
        while (_8087elems[0].e && stackused)
        {
                /* Save it      */
                i = getemptyslot();
                if (NDPP) printf("saving %p in temporary NDP::save[%d]\n",_8087elems[0].e,i);
                NDP::save[i] = _8087elems[0];

                c = genfwait(c);
                c = ndp_fstp(c,i,_8087elems[0].e->Ety); // FSTP i[BP]
                pop87();
        }
        if (c)                          /* if any stores                */
                genfwait(c);            /* wait for last one to finish  */
        return c;
}

/******************************************
 * Save any noted values that would be destroyed by n pushes
 */

code *save87regs(unsigned n)
{
    unsigned j;
    unsigned k;
    code *c = NULL;

    assert(n <= 7);
    j = 8 - n;
    if (stackused > j)
    {
        for (k = 8; k > j; k--)
        {
            c = genf2(c,0xD9,0xF6);     // FDECSTP
            c = genfwait(c);
            if (k <= stackused)
            {   int i;

                i = getemptyslot();
                c = ndp_fstp(c, i, _8087elems[k - 1].e->Ety);   // FSTP i[BP]
                NDP::save[i] = _8087elems[k - 1];
                _8087elems[k - 1] = ndp_zero;
            }
        }

        for (k = 8; k > j; k--)
        {
            if (k > stackused)
            {   c = genf2(c,0xD9,0xF7); // FINCSTP
                c = genfwait(c);
            }
        }
        stackused = j;
    }
    return c;
}

/*****************************************************
 * Save/restore ST0 or ST01
 */

void gensaverestore87(regm_t regm, code **csave, code **crestore)
{
    //printf("gensaverestore87(%s)\n", regm_str(regm));
    code *cs1 = *csave;
    code *cs2 = *crestore;
    assert(regm == mST0 || regm == mST01);

    int i = getemptyslot();
    NDP::save[i].e = el_calloc();       // this blocks slot [i] for the life of this function
    cs1 = ndp_fstp(cs1, i, TYldouble);
    cs2 = cat(ndp_fld(CNIL, i, TYldouble), cs2);
    if (regm == mST01)
    {
        int j = getemptyslot();
        NDP::save[j].e = el_calloc();
        cs1 = ndp_fstp(cs1, j, TYldouble);
        cs2 = cat(ndp_fld(CNIL, j, TYldouble), cs2);
    }
    *csave = cs1;
    *crestore = cs2;
}

/*************************************
 * Find which, if any, slot on stack holds elem e.
 */

STATIC int cse_get(elem *e, unsigned offset)
{   int i;

    for (i = 0; 1; i++)
    {
        if (i == stackused)
        {
            i = -1;
            //printf("cse not found\n");
            //elem_print(e);
            break;
        }
        if (_8087elems[i].e == e &&
            _8087elems[i].offset == offset)
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

code *comsub87(elem *e,regm_t *pretregs)
{   code *c;

    //printf("comsub87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    // Look on 8087 stack
    int i = cse_get(e, 0);

    if (tycomplex(e->Ety))
    {
        unsigned sz = tysize(e->Ety);
        int j = cse_get(e, sz / 2);
        if (i >= 0 && j >= 0)
        {
            c = push87();
            c = cat(c, push87());
            c = genf2(c,0xD9,0xC0 + i);         // FLD ST(i)
            c = genf2(c,0xD9,0xC0 + j + 1);     // FLD ST(j + 1)
            c = cat(c,fixresult_complex87(e,mST01,pretregs));
        }
        else
            // Reload
            c = loaddata(e,pretregs);
    }
    else
    {
        if (i >= 0)
        {
            c = push87();
            c = genf2(c,0xD9,0xC0 + i); // FLD ST(i)
            if (*pretregs & XMMREGS)
                c = cat(c,fixresult87(e,mST0,pretregs));
            else
                c = cat(c,fixresult(e,mST0,pretregs));
        }
        else
            // Reload
            c = loaddata(e,pretregs);
    }

    freenode(e);
    return c;
}


/**************************
 * Generate code to deal with floatreg.
 */

code * genfltreg(code *c,unsigned opcode,unsigned reg,targ_size_t offset)
{
        floatreg = TRUE;
        reflocal = TRUE;
        if ((opcode & ~7) == 0xD8)
            c = genfwait(c);
        return genc1(c,opcode,modregxrm(2,reg,BPRM),FLfltreg,offset);
}

/*******************************
 * Decide if we need to gen an FWAIT.
 */

code *genfwait(code *c)
{
    if (ADDFWAIT())
        c = gen1(c,FWAIT);
    return c;
}

/***************************************
 * Generate floating point instruction.
 */

code * genf2(code *c,unsigned op,unsigned rm)
{
    return gen2(genfwait(c),op,rm);
}

/***************************
 * Put the 8087 flags into the CPU flags.
 */

STATIC code * cg87_87topsw(code *c)
{
        /* Note that SAHF is not available on some early I64 processors
         * and will cause a seg fault
         */
        assert(!NOSAHF);
        c = cat(c,getregs(mAX));
        if (config.target_cpu >= TARGET_80286)
            c = genf2(c,0xDF,0xE0);             // FSTSW AX
        else
        {   c = genfltreg(c,0xD8+5,7,0);        /* FSTSW floatreg[BP]   */
            genfwait(c);                        /* FWAIT                */
            genfltreg(c,0x8A,4,1);              /* MOV AH,floatreg+1[BP] */
        }
        gen1(c,0x9E);                           // SAHF
        code_orflag(c,CFpsw);
        return c;
}

/*****************************************
 * Jump to ctarget if condition code C2 is set.
 */

STATIC code *genjmpifC2(code *c, code *ctarget)
{
    if (NOSAHF)
    {
        c = cat(c,getregs(mAX));
        c = genf2(c,0xDF,0xE0);                       // FSTSW AX
        genc2(c,0xF6,modregrm(3,0,4),4);              // TEST AH,4
        c = genjmp(c, JNE, FLcode, (block *)ctarget); // JNE ctarget
    }
    else
    {
        c = cg87_87topsw(c);
        c = genjmp(c, JP, FLcode, (block *)ctarget);  // JP ctarget
    }
    return c;
}

/***************************
 * Set the PSW based on the state of ST0.
 * Input:
 *      pop     if stack should be popped after test
 * Returns:
 *      start of code appended to c.
 */

STATIC code * genftst(code *c,elem *e,int pop)
{
    if (NOSAHF)
    {
        c = cat(c,push87());
        c = gen2(c,0xD9,0xEE);          // FLDZ
        gen2(c,0xDF,0xE9);              // FUCOMIP ST1
        pop87();
        if (pop)
        {   c = genf2(c,0xDD,modregrm(3,3,0));  // FPOP
            pop87();
        }
    }
    else if (config.flags4 & CFG4fastfloat)  // if fast floating point
    {
        c = genf2(c,0xD9,0xE4);         // FTST
        c = cg87_87topsw(c);            // put 8087 flags in CPU flags
        if (pop)
        {   c = genf2(c,0xDD,modregrm(3,3,0));  // FPOP
            pop87();
        }
    }
    else if (config.target_cpu >= TARGET_80386)
    {
        // FUCOMP doesn't raise exceptions on QNANs, unlike FTST
        c = cat(c,push87());
        c = gen2(c,0xD9,0xEE);          // FLDZ
        gen2(c,pop ? 0xDA : 0xDD,0xE9); // FUCOMPP / FUCOMP
        pop87();
        if (pop)
            pop87();
        cg87_87topsw(c);                // put 8087 flags in CPU flags
    }
    else
    {
        // Call library function which does not raise exceptions
        regm_t regm = 0;

        c = cat(c,callclib(e,CLIBftest,&regm,0));
        if (pop)
        {   c = genf2(c,0xDD,modregrm(3,3,0));  // FPOP
            pop87();
        }
    }
    return c;
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

unsigned char loadconst(elem *e, int im)
#if __DMC__
__in
{
    elem_debug(e);
    assert(im == 0 || im == 1);
}
__body
#endif
{
    static float fval[7] =
        {0.0,1.0,PI,LOG2T,LOG2E,LOG2,LN2};
    static double dval[7] =
        {0.0,1.0,PI,LOG2T,LOG2E,LOG2,LN2};
    static longdouble ldval[7] =
#if __DMC__    // from math.h
    {0.0,1.0,M_PI_L,M_LOG2T_L,M_LOG2E_L,M_LOG2_L,M_LN2_L};
#elif _MSC_VER // struct longdouble constants
    {ld_zero, ld_one, ld_pi, ld_log2t, ld_log2e, ld_log2, ld_ln2};
#else          // C99 hexadecimal floats (GCC, CLANG, ...)
#define M_PI_L          0x1.921fb54442d1846ap+1L        // 3.14159 fldpi
#define M_LOG2T_L       0x1.a934f0979a3715fcp+1L        // 3.32193 fldl2t
#define M_LOG2E_L       0x1.71547652b82fe178p+0L        // 1.4427 fldl2e
#define M_LOG2_L        0x1.34413509f79fef32p-2L        // 0.30103 fldlg2
#define M_LN2_L         0x1.62e42fefa39ef358p-1L        // 0.693147 fldln2
    {0.0,1.0,M_PI_L,M_LOG2T_L,M_LOG2E_L,M_LOG2_L,M_LN2_L};
#endif
    static char opcode[7 + 1] =
        /* FLDZ,FLD1,FLDPI,FLDL2T,FLDL2E,FLDLG2,FLDLN2,0 */
        {0xEE,0xE8,0xEB,0xE9,0xEA,0xEC,0xED,0};
    int i;
    targ_float f;
    targ_double d;
    targ_ldouble ld;
    int sz;
    int zero;
    void *p;
    static char zeros[sizeof(longdouble)];

    if (im == 0)
    {
        switch (tybasic(e->Ety))
        {
            case TYfloat:
            case TYifloat:
            case TYcfloat:
                f = e->EV.Vfloat;
                sz = 4;
                p = &f;
                break;

            case TYdouble:
            case TYdouble_alias:
            case TYidouble:
            case TYcdouble:
                d = e->EV.Vdouble;
                sz = 8;
                p = &d;
                break;

            case TYldouble:
            case TYildouble:
            case TYcldouble:
                ld = e->EV.Vldouble;
                sz = 10;
                p = &ld;
                break;

            default:
                assert(0);
        }
    }
    else
    {
        switch (tybasic(e->Ety))
        {
            case TYcfloat:
                f = e->EV.Vcfloat.im;
                sz = 4;
                p = &f;
                break;

            case TYcdouble:
                d = e->EV.Vcdouble.im;
                sz = 8;
                p = &d;
                break;

            case TYcldouble:
                ld = e->EV.Vcldouble.im;
                sz = 10;
                p = &ld;
                break;

            default:
                assert(0);
        }
    }

    // Note that for this purpose, -0 is not regarded as +0,
    // since FLDZ loads a +0
    zero = (memcmp(p, zeros, sz) == 0);
    if (zero && config.target_cpu >= TARGET_PentiumPro)
        return 0xEE;            // FLDZ is the only one with 1 micro-op

    // For some reason, these instructions take more clocks
    if (config.flags4 & CFG4speed && config.target_cpu >= TARGET_Pentium)
        return 0;

    if (zero)
        return 0xEE;

    for (i = 1; i < arraysize(fval); i++)
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


code *fixresult87(elem *e,regm_t retregs,regm_t *pretregs)
{
    regm_t regm;
    tym_t tym;
    code *c1,*c2;
    unsigned sz;

    //printf("fixresult87(e = %p, retregs = x%x, *pretregs = x%x)\n", e,retregs,*pretregs);
    //printf("fixresult87(e = %p, retregs = %s, *pretregs = %s)\n", e,regm_str(retregs),regm_str(*pretregs));
    assert(!*pretregs || retregs);
    c1 = CNIL;
    c2 = CNIL;
    tym = tybasic(e->Ety);
    sz = tysize[tym];
    //printf("tym = x%x, sz = %d\n", tym, sz);

    if (*pretregs & mST01)
        return fixresult_complex87(e, retregs, pretregs);

    /* if retregs needs to be transferred into the 8087 */
    if (*pretregs & mST0 && retregs & (mBP | ALLREGS))
    {
        assert(sz <= DOUBLESIZE);
        if (!I16)
        {

            if (*pretregs & mPSW)
            {   // Set flags
                regm_t r = retregs | mPSW;
                c1 = fixresult(e,retregs,&r);
            }
            c2 = push87();
            if (sz == REGSIZE || (I64 && sz == 4))
            {
                unsigned reg = findreg(retregs);
                c2 = genfltreg(c2,0x89,reg,0);          // MOV fltreg,reg
                genfltreg(c2,0xD9,0,0);                 // FLD float ptr fltreg
            }
            else
            {   unsigned msreg,lsreg;

                msreg = findregmsw(retregs);
                lsreg = findreglsw(retregs);
                c2 = genfltreg(c2,0x89,lsreg,0);        // MOV fltreg,lsreg
                genfltreg(c2,0x89,msreg,4);             // MOV fltreg+4,msreg
                genfltreg(c2,0xDD,0,0);                 // FLD double ptr fltreg
            }
        }
        else
        {
            regm = (sz == FLOATSIZE) ? FLOATREGS : DOUBLEREGS;
            regm |= *pretregs & mPSW;
            c1 = fixresult(e,retregs,&regm);
            regm = 0;           // don't worry about result from CLIBxxx
            c2 = callclib(e,
                    ((sz == FLOATSIZE) ? CLIBfltto87 : CLIBdblto87),
                    &regm,0);
        }
    }
    else if (*pretregs & (mBP | ALLREGS) && retregs & mST0)
    {   unsigned mf;
        unsigned reg;

        assert(sz <= DOUBLESIZE);
        mf = (sz == FLOATSIZE) ? MFfloat : MFdouble;
        if (*pretregs & mPSW && !(retregs & mPSW))
                c1 = genftst(c1,e,0);
        /* FSTP floatreg        */
        pop87();
        c1 = genfltreg(c1,ESC(mf,1),3,0);
        genfwait(c1);
        c2 = allocreg(pretregs,&reg,(sz == FLOATSIZE) ? TYfloat : TYdouble);
        if (sz == FLOATSIZE)
        {
            if (!I16)
                c2 = genfltreg(c2,0x8B,reg,0);
            else
            {   c2 = genfltreg(c2,0x8B,reg,REGSIZE);
                genfltreg(c2,0x8B,findreglsw(*pretregs),0);
            }
        }
        else
        {   assert(sz == DOUBLESIZE);
            if (I16)
            {   c2 = genfltreg(c2,0x8B,AX,6);
                genfltreg(c2,0x8B,BX,4);
                genfltreg(c2,0x8B,CX,2);
                genfltreg(c2,0x8B,DX,0);
            }
            else if (I32)
            {   c2 = genfltreg(c2,0x8B,reg,REGSIZE);
                genfltreg(c2,0x8B,findreglsw(*pretregs),0);
            }
            else // I64
            {
                c2 = genfltreg(c2,0x8B,reg,0);
                code_orrex(c2, REX_W);
            }
        }
    }
    else if (*pretregs == 0 && retregs == mST0)
    {
        c1 = genf2(c1,0xDD,modregrm(3,3,0));    // FPOP
        pop87();
    }
    else
    {   if (*pretregs & mPSW)
        {   if (!(retregs & mPSW))
            {
                c1 = genftst(c1,e,!(*pretregs & (mST0 | XMMREGS))); // FTST
            }
        }
        if (*pretregs & mST0 && retregs & XMMREGS)
        {
            assert(sz <= DOUBLESIZE);
            unsigned mf = (sz == FLOATSIZE) ? MFfloat : MFdouble;
            // MOVD floatreg,XMM?
            unsigned reg = findreg(retregs);
            c1 = genfltreg(c1,xmmstore(tym),reg - XMM0,0);
            c2 = push87();
            c2 = genfltreg(c2,ESC(mf,1),0,0);                 // FLD float/double ptr fltreg
        }
        else if (retregs & mST0 && *pretregs & XMMREGS)
        {
            assert(sz <= DOUBLESIZE);
            unsigned mf = (sz == FLOATSIZE) ? MFfloat : MFdouble;
            // FSTP floatreg
            pop87();
            c1 = genfltreg(c1,ESC(mf,1),3,0);
            genfwait(c1);
            // MOVD XMM?,floatreg
            unsigned reg;
            c2 = allocreg(pretregs,&reg,(sz == FLOATSIZE) ? TYfloat : TYdouble);
            c2 = genfltreg(c2,xmmload(tym),reg -XMM0,0);
        }
        else
            assert(!(*pretregs & mST0) || (retregs & mST0));
    }
    if (*pretregs & mST0)
        note87(e,0,0);
    return cat(c1,c2);
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
static const char oprev[9] = { -1,0,1,2,3,5,4,7,6 };

code *orth87(elem *e,regm_t *pretregs)
{
    unsigned op;
    code *c1,*c2,*c3,*c4;
    code *cx;
    regm_t retregs;
    regm_t resregm;
    elem *e1;
    elem *e2;
    int e2oper;
    int eoper;
    unsigned sz2;
    int clib = CLIBMAX;         // initialize to invalid value
    int reverse = 0;

    //printf("orth87(+e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
#if 1   // we could be evaluating / for side effects only
    assert(*pretregs != 0);
#endif
    retregs = mST0;
    resregm = mST0;

    e1 = e->E1;
    e2 = e->E2;
    c3 = CNIL;
    c4 = CNIL;
    sz2 = tysize(e1->Ety);
    if (tycomplex(e1->Ety))
        sz2 /= 2;

    eoper = e->Eoper;
    if (eoper == OPmul && e2->Eoper == OPconst && el_toldouble(e->E2) == 2.0L)
    {
        // Perform "mul 2.0" as fadd ST(0), ST
        c1 = codelem(e1,&retregs,FALSE);
        c1 = genf2(c1, 0xDC, 0xC0);             // fadd ST(0), ST;
        c2 = fixresult87(e,mST0,pretregs);      // result is in ST(0).
        freenode(e2);
        return cat(c1,c2);
    }

    if (OTrel(eoper))
        eoper = OPeqeq;
    #define X(op, ty1, ty2)     (((op) << 16) + (ty1) * 256 + (ty2))
    switch (X(eoper, tybasic(e1->Ety), tybasic(e2->Ety)))
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
            op = (unsigned) -1;
            break;

        case X(OPeqeq, TYfloat, TYfloat):
        case X(OPeqeq, TYdouble, TYdouble):
        case X(OPeqeq, TYdouble_alias, TYdouble_alias):
        case X(OPeqeq, TYldouble, TYldouble):
        case X(OPeqeq, TYifloat, TYifloat):
        case X(OPeqeq, TYidouble, TYidouble):
        case X(OPeqeq, TYildouble, TYildouble):
            assert(OTrel(e->Eoper));
            assert((*pretregs & mST0) == 0);
            c1 = codelem(e1,&retregs,FALSE);
            note87(e1,0,0);
            resregm = mPSW;

            if (rel_exception(e->Eoper) || config.flags4 & CFG4fastfloat)
            {
                if (cnst(e2) && !boolres(e2))
                {
                    if (NOSAHF)
                    {
                        c1 = cat(c1,push87());
                        c1 = gen2(c1,0xD9,0xEE);            // FLDZ
                        gen2(c1,0xDF,0xF1);                 // FCOMIP ST1
                        pop87();
                    }
                    else
                    {   c1 = genf2(c1,0xD9,0xE4);           // FTST
                        c1 = cg87_87topsw(c1);
                    }
                    c2 = genf2(NULL,0xDD,modregrm(3,3,0));      // FPOP
                    pop87();
                }
                else if (NOSAHF)
                {
                    note87(e1,0,0);
                    c2 = load87(e2,0,&retregs,e1,-1);
                    c2 = cat(c2,makesure87(e1,0,1,0));
                    resregm = 0;
                    //c2 = genf2(c2,0xD9,0xC8 + 1);       // FXCH ST1
                    c2 = gen2(c2,0xDF,0xF1);            // FCOMIP ST1
                    pop87();
                    genf2(c2,0xDD,modregrm(3,3,0));     // FPOP
                    pop87();
                }
                else
                {
                    c2 = load87(e2, 0, pretregs, e1, 3);        // FCOMPP
                }
            }
            else
            {
                if (cnst(e2) && !boolres(e2) &&
                    config.target_cpu < TARGET_80386)
                {
                    regm_t regm = 0;

                    c2 = callclib(e,CLIBftest0,&regm,0);
                    pop87();
                }
                else
                {
                    note87(e1,0,0);
                    c2 = load87(e2,0,&retregs,e1,-1);
                    c2 = cat(c2,makesure87(e1,0,1,0));
                    resregm = 0;
                    if (NOSAHF)
                    {
                        c3 = gen2(CNIL,0xDF,0xE9);              // FUCOMIP ST1
                        pop87();
                        genf2(c3,0xDD,modregrm(3,3,0));         // FPOP
                        pop87();
                    }
                    else if (config.target_cpu >= TARGET_80386)
                    {
                        c3 = gen2(CNIL,0xDA,0xE9);      // FUCOMPP
                        c3 = cg87_87topsw(c3);
                        pop87();
                        pop87();
                    }
                    else
                        // Call a function instead so that exceptions
                        // are not generated.
                        c3 = callclib(e,CLIBfcompp,&resregm,0);
                }
            }

            freenode(e2);
            return cat4(c1,c2,c3,c4);

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
            clib = CLIBcmul;
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
            clib = CLIBcdiv;
            goto Lcomplex;

        case X(OPdiv, TYifloat,   TYfloat):
        case X(OPdiv, TYidouble,  TYdouble):
        case X(OPdiv, TYildouble, TYldouble):
            op = 6;                             // FDIVP
            break;

        Lcomplex:
            c1 = loadComplex(e1);
            c2 = loadComplex(e2);
            c3 = makesure87(e1, sz2, 2, 0);
            c3 = cat(c3,makesure87(e1, 0, 3, 0));
            retregs = mST01;
            if (eoper == OPadd)
            {
                c4 = genf2(NULL, 0xDE, 0xC0+2); // FADDP ST(2),ST
                genf2(c4, 0xDE, 0xC0+2);        // FADDP ST(2),ST
                pop87();
                pop87();
            }
            else if (eoper == OPmin)
            {
                c4 = genf2(NULL, 0xDE, 0xE8+2); // FSUBP ST(2),ST
                genf2(c4, 0xDE, 0xE8+2);        // FSUBP ST(2),ST
                pop87();
                pop87();
            }
            else
                c4 = callclib(e, clib, &retregs, 0);
            c4 = cat(c4, fixresult_complex87(e, retregs, pretregs));
            return cat4(c1,c2,c3,c4);

        Lcomplex2:
            retregs = mST0;
            c1 = codelem(e1, &retregs, FALSE);
            note87(e1, 0, 0);
            c2 = loadComplex(e2);
            c3 = makesure87(e1, 0, 2, 0);
            retregs = mST01;
            if (eoper == OPadd)
            {
                c4 = genf2(NULL, 0xDE, 0xC0+2); // FADDP ST(2),ST
            }
            else if (eoper == OPmin)
            {
                c4 = genf2(NULL, 0xDE, 0xE8+2); // FSUBP ST(2),ST
                c4 = genf2(c4, 0xD9, 0xE0);     // FCHS
            }
            else
                assert(0);
            pop87();
            c4 = genf2(c4, 0xD9, 0xC8 + 1);     // FXCH ST(1)
            c4 = cat(c4, fixresult_complex87(e, retregs, pretregs));
            return cat4(c1,c2,c3,c4);

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
            c1 = loadComplex(e1);
            c2 = loadComplex(e2);
            c3 = makesure87(e1, sz2, 2, 0);
            c3 = cat(c3,makesure87(e1, 0, 3, 0));
            retregs = 0;
            c4 = callclib(e, CLIBccmp, &retregs, 0);
            return cat4(c1,c2,c3,c4);


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
            retregs = mST0;
            c1 = codelem(e1, &retregs, FALSE);
            note87(e1, 0, 0);
            c2 = codelem(e2, &retregs, FALSE);
            c3 = makesure87(e1, 0, 1, 0);
            if (eoper == OPmin)
                c3 = genf2(c3, 0xD9, 0xE0);     // FCHS
            if (tyimaginary(e1->Ety))
                c3 = genf2(c3, 0xD9, 0xC8 + 1); // FXCH ST(1)
            retregs = mST01;
            c4 = fixresult_complex87(e, retregs, pretregs);
            return cat4(c1,c2,c3,c4);

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
            c1 = loadComplex(e1);
            retregs = mST0;
            c2 = load87(e2,sz2,&retregs,e1,op);
            freenode(e2);
            retregs = mST01;
            c3 = makesure87(e1,0,1,0);
            c4 = fixresult_complex87(e, retregs, pretregs);
            return cat4(c1,c2,c3,c4);

        case X(OPmul, TYcfloat, TYfloat):
        case X(OPmul, TYcdouble, TYdouble):
        case X(OPmul, TYcldouble, TYldouble):
            c1 = loadComplex(e1);
            goto Lcm1;

        case X(OPmul, TYcfloat, TYifloat):
        case X(OPmul, TYcdouble, TYidouble):
        case X(OPmul, TYcldouble, TYildouble):
            c1 = loadComplex(e1);
            c1 = genf2(c1, 0xD9, 0xE0);         // FCHS
            genf2(c1,0xD9,0xC8 + 1);            // FXCH ST(1)
            if (elemisone(e2))
            {
                freenode(e2);
                c2 = NULL;
                c3 = NULL;
                goto Lcd4;
            }
            goto Lcm1;

        Lcm1:
            retregs = mST0;
            c2 = codelem(e2, &retregs, FALSE);
            c3 = makesure87(e1, sz2, 1, 0);
            c3 = cat(c3,makesure87(e1, 0, 2, 0));
            goto Lcm2;

        case X(OPmul, TYfloat, TYcfloat):
        case X(OPmul, TYdouble, TYcdouble):
        case X(OPmul, TYldouble, TYcldouble):
            retregs = mST0;
            c1 = codelem(e1, &retregs, FALSE);
            note87(e1, 0, 0);
            c2 = loadComplex(e2);
            c3 = makesure87(e1, 0, 2, 0);
            c3 = genf2(c3,0xD9,0xC8 + 1);       // FXCH ST(1)
            genf2(c3,0xD9,0xC8 + 2);            // FXCH ST(2)
            goto Lcm2;

        case X(OPmul, TYifloat, TYcfloat):
        case X(OPmul, TYidouble, TYcdouble):
        case X(OPmul, TYildouble, TYcldouble):
            retregs = mST0;
            c1 = codelem(e1, &retregs, FALSE);
            note87(e1, 0, 0);
            c2 = loadComplex(e2);
            c3 = makesure87(e1, 0, 2, 0);
            c3 = genf2(c3, 0xD9, 0xE0);         // FCHS
            genf2(c3,0xD9,0xC8 + 2);            // FXCH ST(2)
            goto Lcm2;

        Lcm2:
            c3 = genf2(c3,0xDC,0xC8 + 2);       // FMUL ST(2), ST
            genf2(c3,0xDE,0xC8 + 1);            // FMULP ST(1), ST
            goto Lcd3;

        case X(OPdiv, TYcfloat, TYfloat):
        case X(OPdiv, TYcdouble, TYdouble):
        case X(OPdiv, TYcldouble, TYldouble):
            c1 = loadComplex(e1);
            retregs = mST0;
            c2 = codelem(e2, &retregs, FALSE);
            c3 = makesure87(e1, sz2, 1, 0);
            c3 = cat(c3,makesure87(e1, 0, 2, 0));
            goto Lcd1;

        case X(OPdiv, TYcfloat, TYifloat):
        case X(OPdiv, TYcdouble, TYidouble):
        case X(OPdiv, TYcldouble, TYildouble):
            c1 = loadComplex(e1);
            c1 = genf2(c1,0xD9,0xC8 + 1);       // FXCH ST(1)
            xchg87(0, 1);
            genf2(c1, 0xD9, 0xE0);              // FCHS
            retregs = mST0;
            c2 = codelem(e2, &retregs, FALSE);
            c3 = makesure87(e1, 0, 1, 0);
            c3 = cat(c3,makesure87(e1, sz2, 2, 0));
        Lcd1:
            c3 = genf2(c3,0xDC,0xF8 + 2);       // FDIV ST(2), ST
            genf2(c3,0xDE,0xF8 + 1);            // FDIVP ST(1), ST
        Lcd3:
            pop87();
        Lcd4:
            retregs = mST01;
            c4 = fixresult_complex87(e, retregs, pretregs);
            return cat4(c1, c2, c3, c4);

        case X(OPmod, TYcfloat, TYfloat):
        case X(OPmod, TYcdouble, TYdouble):
        case X(OPmod, TYcldouble, TYldouble):
        case X(OPmod, TYcfloat, TYifloat):
        case X(OPmod, TYcdouble, TYidouble):
        case X(OPmod, TYcldouble, TYildouble):
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
            c1 = loadComplex(e1);
            retregs = mST0;
            c2 = codelem(e2, &retregs, FALSE);
            c3 = makesure87(e1, sz2, 1, 0);
            c3 = cat(c3,makesure87(e1, 0, 2, 0));
            c3 = genf2(c3, 0xD9, 0xC8 + 1);             // FXCH ST(1)

            cx = gen2(NULL, 0xD9, 0xF8);                // FPREM
            cx = genjmpifC2(cx, cx);                    // JC2 FM1
            cx = genf2(cx, 0xD9, 0xC8 + 2);             // FXCH ST(2)
            c3 = cat(c3,cx);

            cx = gen2(NULL, 0xD9, 0xF8);                // FPREM
            cx = genjmpifC2(cx, cx);                    // JC2 FM2
            cx = genf2(cx,0xDD,0xD8 + 1);               // FSTP ST(1)
            cx = genf2(cx, 0xD9, 0xC8 + 1);             // FXCH ST(1)
            c3 = cat(c3,cx);

            goto Lcd3;

        default:
#ifdef DEBUG
            elem_print(e);
#endif
            assert(0);
            break;
    }
    #undef X

    e2oper = e2->Eoper;

    /* Move double-sized operand into the second position if there's a chance
     * it will allow combining a load with an operation (DMD Bugzilla 2905)
     */
    if ( ((tybasic(e1->Ety) == TYdouble)
          && ((e1->Eoper == OPvar) || (e1->Eoper == OPconst))
          && (tybasic(e2->Ety) != TYdouble)) ||
        (e1->Eoper == OPconst) ||
        (e1->Eoper == OPvar &&
         ((e1->Ety & (mTYconst | mTYimmutable) && !OTleaf(e2oper)) ||
          (e2oper == OPd_f &&
            (e2->E1->Eoper == OPs32_d || e2->E1->Eoper == OPs64_d || e2->E1->Eoper == OPs16_d) &&
            e2->E1->E1->Eoper == OPvar
          ) ||
          ((e2oper == OPs32_d || e2oper == OPs64_d || e2oper == OPs16_d) &&
            e2->E1->Eoper == OPvar
          )
         )
        )
       )
    {   // Reverse order of evaluation
        e1 = e->E2;
        e2 = e->E1;
        op = oprev[op + 1];
        reverse ^= 1;
    }

    c1 = codelem(e1,&retregs,FALSE);
    note87(e1,0,0);

    if (config.flags4 & CFG4fdivcall && e->Eoper == OPdiv)
    {
        regm_t retregs = mST0;
        c2 = load87(e2,0,&retregs,e1,-1);
        c2 = cat(c2,makesure87(e1,0,1,0));
        if (op == 7)                    // if reverse divide
            c2 = genf2(c2,0xD9,0xC8 + 1);       // FXCH ST(1)
        c2 = cat(c2,callclib(e,CLIBfdiv87,&retregs,0));
        pop87();
        resregm = mST0;
        freenode(e2);
        c4 = fixresult87(e,resregm,pretregs);
    }
    else if (e->Eoper == OPmod)
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
        c2 = load87(e2,0,&retregs,e1,-1);
        c2 = cat(c2,makesure87(e1,0,1,0));      // now have x,y on stack; need y,x
        if (!reverse)                           // if not reverse modulo
            c2 = genf2(c2,0xD9,0xC8 + 1);       // FXCH ST(1)

        c3 = gen2(NULL, 0xD9, 0xF8);            // FM1: FPREM
        c3 = genjmpifC2(c3, c3);                // JC2 FM1
        c3 = genf2(c3,0xDD,0xD8 + 1);           // FSTP ST(1)

        pop87();
        resregm = mST0;
        freenode(e2);
        c4 = fixresult87(e,resregm,pretregs);
    }
    else
    {   c2 = load87(e2,0,pretregs,e1,op);
        freenode(e2);
    }
    if (*pretregs & mST0)
        note87(e,0,0);
    //printf("orth87(-e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    return cat4(c1,c2,c3,c4);
}

/*****************************
 * Load e into ST01.
 */

code *loadComplex(elem *e)
{   int sz;
    regm_t retregs;
    code *c;

    sz = tysize(e->Ety);
    switch (tybasic(e->Ety))
    {
        case TYfloat:
        case TYdouble:
        case TYldouble:
            retregs = mST0;
            c = codelem(e,&retregs,FALSE);
            // Convert to complex with a 0 for the imaginary part
            c = cat(c, push87());
            c = gen2(c,0xD9,0xEE);              // FLDZ
            break;

        case TYifloat:
        case TYidouble:
        case TYildouble:
            // Convert to complex with a 0 for the real part
            c = push87();
            c = gen2(c,0xD9,0xEE);              // FLDZ
            retregs = mST0;
            c = cat(c, codelem(e,&retregs,FALSE));
            break;

        case TYcfloat:
        case TYcdouble:
        case TYcldouble:
            sz /= 2;
            retregs = mST01;
            c = codelem(e,&retregs,FALSE);
            break;

        default:
            assert(0);
    }
    note87(e, 0, 1);
    note87(e, sz, 0);
    return c;
}

/*************************
 * If op == -1, load expression e into ST0.
 * else compute (eleft op e), eleft is in ST0.
 * Must follow same logic as cmporder87();
 */

code *load87(elem *e,unsigned eoffset,regm_t *pretregs,elem *eleft,int op)
{
        code *ccomma,*c,*c2,*cpush;
        code cs;
        regm_t retregs;
        unsigned reg,mf,mf1;
        int opr;
        unsigned char ldop;
        tym_t ty;
        int i;

#if NDPP
        printf("+load87(e=%p, eoffset=%d, *pretregs=%s, eleft=%p, op=%d, stackused = %d)\n",e,eoffset,regm_str(*pretregs),eleft,op,stackused);
#endif
        assert(!(NOSAHF && op == 3));
        elem_debug(e);
        ccomma = NULL;
        cpush = NULL;
        if (ADDFWAIT())
            cs.Iflags = CFwait;
        else
            cs.Iflags = 0;
        cs.Irex = 0;
        opr = oprev[op + 1];
        ty = tybasic(e->Ety);
        if ((ty == TYldouble || ty == TYildouble) &&
            op != -1 && e->Eoper != OPd_ld)
            goto Ldefault;
        mf = (ty == TYfloat || ty == TYifloat || ty == TYcfloat) ? MFfloat : MFdouble;
    L5:
        switch (e->Eoper)
        {
            case OPcomma:
                ccomma = docommas(&e);
//              if (op != -1)
//                  ccomma = cat(ccomma,makesure87(eleft,eoffset,0,0));
                goto L5;

            case OPvar:
                notreg(e);
            case OPind:
            L2:
                if (op != -1)
                {
                    if (e->Ecount && e->Ecount != e->Ecomsub &&
                        (i = cse_get(e, 0)) >= 0)
                    {   static unsigned char b2[8] = {0xC0,0xC8,0xD0,0xD8,0xE0,0xE8,0xF0,0xF8};

                        c = genf2(NULL,0xD8,b2[op] + i);        // Fop ST(i)
                    }
                    else
                    {
                        c = getlvalue(&cs,e,0);
                        if (I64)
                            cs.Irex &= ~REX_W;                  // don't use for x87 ops
                        c = cat(c,makesure87(eleft,eoffset,0,0));
                        cs.Iop = ESC(mf,0);
                        cs.Irm |= modregrm(0,op,0);
                        c = gen(c,&cs);
                    }
                }
                else
                {
                    cpush = push87();
                    switch (ty)
                    {
                        case TYfloat:
                        case TYdouble:
                        case TYifloat:
                        case TYidouble:
                        case TYcfloat:
                        case TYcdouble:
                        case TYdouble_alias:
                            c = loadea(e,&cs,ESC(mf,1),0,0,0,0);        // FLD var
                            break;
                        case TYldouble:
                        case TYildouble:
                        case TYcldouble:
                            c = loadea(e,&cs,0xDB,5,0,0,0);             // FLD var
                            break;
                        default:
                            printf("ty = x%x\n", ty);
                            assert(0);
                            break;
                    }
                    note87(e,0,0);
                }
                break;
            case OPd_f:
            case OPf_d:
            case OPd_ld:
                mf1 = (tybasic(e->E1->Ety) == TYfloat || tybasic(e->E1->Ety) == TYifloat)
                        ? MFfloat : MFdouble;
                if (op != -1 && stackused)
                    note87(eleft,eoffset,0);    // don't trash this value
                if (e->E1->Eoper == OPvar || e->E1->Eoper == OPind)
                {
#if 1
                L4:
                    c = getlvalue(&cs,e->E1,0);
                    cs.Iop = ESC(mf1,0);
                    if (ADDFWAIT())
                        cs.Iflags |= CFwait;
                    if (!I16)
                        cs.Iflags &= ~CFopsize;
                    if (op != -1)
                    {   cs.Irm |= modregrm(0,op,0);
                        c = cat(c,makesure87(eleft,eoffset,0,0));
                    }
                    else
                    {   cs.Iop |= 1;
                        c = cat(c,push87());
                    }
                    c = gen(c,&cs);                     /* FLD / Fop    */
#else
                    c = loadea(e->E1,&cs,ESC(mf1,1),0,0,0,0); /* FLD e->E1 */
#endif
                    /* Variable cannot be put into a register anymore   */
                    if (e->E1->Eoper == OPvar)
                        notreg(e->E1);
                    freenode(e->E1);
                }
                else
                {
                    retregs = mST0;
                    c = codelem(e->E1,&retregs,FALSE);
                    if (op != -1)
                    {   c = cat(c,makesure87(eleft,eoffset,1,0));
                        c = genf2(c,0xDE,modregrm(3,opr,1)); // FopRP
                        pop87();
                    }
                }
                break;

            case OPs64_d:
                if (e->E1->Eoper == OPvar ||
                    (e->E1->Eoper == OPind && e->E1->Ecount == 0))
                {
                    c = getlvalue(&cs,e->E1,0);
                    cs.Iop = 0xDF;
                    if (ADDFWAIT())
                        cs.Iflags |= CFwait;
                    if (!I16)
                        cs.Iflags &= ~CFopsize;
                    c = cat(c,push87());
                    cs.Irm |= modregrm(0,5,0);
                    c = gen(c,&cs);                     // FILD m64
                    // Variable cannot be put into a register anymore
                    if (e->E1->Eoper == OPvar)
                        notreg(e->E1);
                    freenode(e->E1);
                }
                else if (I64)
                {
                    retregs = ALLREGS;
                    c = codelem(e->E1,&retregs,FALSE);
                    reg = findreg(retregs);
                    c = genfltreg(c,0x89,reg,0);        // MOV floatreg,reg
                    code_orrex(c, REX_W);
                    c = cat(c,push87());
                    c = genfltreg(c,0xDF,5,0);          // FILD long long ptr floatreg
                }
                else
                {
                    retregs = ALLREGS;
                    c = codelem(e->E1,&retregs,FALSE);
                    reg = findreglsw(retregs);
                    c = genfltreg(c,0x89,reg,0);        // MOV floatreg,reglsw
                    reg = findregmsw(retregs);
                    c = genfltreg(c,0x89,reg,4);        // MOV floatreg+4,regmsw
                    c = cat(c,push87());
                    c = genfltreg(c,0xDF,5,0);          // FILD long long ptr floatreg
                }
                if (op != -1)
                {   c = cat(c,makesure87(eleft,eoffset,1,0));
                    c = genf2(c,0xDE,modregrm(3,opr,1)); // FopRP
                    pop87();
                }
                break;

            case OPconst:
                ldop = loadconst(e, 0);
                if (ldop)
                {
                    cpush = push87();
                    c = genf2(NULL,0xD9,ldop);          // FLDx
                    if (op != -1)
                    {   genf2(c,0xDE,modregrm(3,opr,1));        // FopRP
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

                if (op != -1)
                    note87(eleft,eoffset,0);    // don't trash this value
                retregs = ALLREGS & mLSW;
                c = codelem(e->E1,&retregs,FALSE);
                c = regwithvalue(c,ALLREGS & mMSW,0,&reg,0);  // 0-extend
                retregs |= mask[reg];
                mf1 = MFlong;
                goto L3;
            }
            case OPs16_d:       mf1 = MFword;   goto L6;
            case OPs32_d:       mf1 = MFlong;   goto L6;
            L6:
                if (op != -1)
                    note87(eleft,eoffset,0);    // don't trash this value
                if (e->E1->Eoper == OPvar ||
                    (e->E1->Eoper == OPind && e->E1->Ecount == 0))
                {
                    goto L4;
                }
                else
                {
                    retregs = ALLREGS;
                    c = codelem(e->E1,&retregs,FALSE);
                L3:
                    if (I16 && e->Eoper != OPs16_d)
                    {
                        /* MOV floatreg+2,reg   */
                        reg = findregmsw(retregs);
                        c = genfltreg(c,0x89,reg,REGSIZE);
                        retregs &= mLSW;
                    }
                    reg = findreg(retregs);
                    c = genfltreg(c,0x89,reg,0);        /* MOV floatreg,reg */
                    if (op != -1)
                    {   c = cat(c,makesure87(eleft,eoffset,0,0));
                        genfltreg(c,ESC(mf1,0),op,0);   /* Fop floatreg */
                    }
                    else
                    {
                        /* FLD long ptr floatreg        */
                        c = cat(c,push87());
                        c = genfltreg(c,ESC(mf1,1),0,0);
                    }
                }
                break;
            default:
            Ldefault:
                retregs = mST0;
#if 1           /* Do this instead of codelem() to avoid the freenode(e).
                   We also lose CSE capability  */
                if (e->Eoper == OPconst)
                {
                    c = load87(e, 0, &retregs, NULL, -1);
                }
                else
                    c = (*cdxxx[e->Eoper])(e,&retregs);
#else
                c = codelem(e,&retregs,FALSE);
#endif
                if (op != -1)
                {
                    c = cat(c,makesure87(eleft,eoffset,1,(op == 0 || op == 1)));
                    pop87();
                    if (op == 4 || op == 6)     // sub or div
                    {   code *cl;

                        cl = code_last(c);
                        if (cl && cl->Iop == 0xD9 && cl->Irm == 0xC9)   // FXCH ST(1)
                        {   cl->Iop = NOP;
                            opr = op;           // reverse operands
                        }
                    }
                    c = genf2(c,0xDE,modregrm(3,opr,1));        // FopRP
                }
                break;
        }
        if (op == 3)                    // FCOMP
        {   pop87();                    // extra pop was done
            cg87_87topsw(c);
        }
        c2 = fixresult87(e,((op == 3) ? mPSW : mST0),pretregs);
#if NDPP
        printf("-load87(e=%p, eoffset=%d, *pretregs=%s, eleft=%p, op=%d, stackused = %d)\n",e,eoffset,regm_str(*pretregs),eleft,op,stackused);
#endif
        return cat4(ccomma,cpush,c,c2);
}

/********************************
 * Determine if a compare is to be done forwards (return 0)
 * or backwards (return 1).
 * Must follow same logic as load87().
 */

int cmporder87(elem *e)
{
    //printf("cmporder87(%p)\n",e);
L1:
        switch (e->Eoper)
        {
            case OPcomma:
                e = e->E2;
                goto L1;

            case OPd_f:
            case OPf_d:
            case OPd_ld:
                if (e->E1->Eoper == OPvar || e->E1->Eoper == OPind)
                    goto ret0;
                else
                    goto ret1;

            case OPconst:
                if (loadconst(e, 0) || tybasic(e->Ety) == TYldouble
                                    || tybasic(e->Ety) == TYildouble)
{
//printf("ret 1, loadconst(e) = %d\n", loadconst(e));
                    goto ret1;
}
                goto ret0;

            case OPvar:
            case OPind:
                if (tybasic(e->Ety) == TYldouble ||
                    tybasic(e->Ety) == TYildouble)
                    goto ret1;
            case OPu16_d:
            case OPs16_d:
            case OPs32_d:
                goto ret0;

            case OPs64_d:
                goto ret1;

            default:
                goto ret1;
        }

ret1:   return 1;
ret0:   return 0;
}

/*******************************
 * Perform an assignment to a long double/double/float.
 */

code *eq87(elem *e,regm_t *pretregs)
{
        regm_t retregs;
        code *c1,*c2;
        code cs;
        unsigned op1;
        unsigned op2;
        tym_t ty1;

        //printf("+eq87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
        assert(e->Eoper == OPeq);
        retregs = mST0 | (*pretregs & mPSW);
        c1 = codelem(e->E2,&retregs,FALSE);
        ty1 = tybasic(e->E1->Ety);
        switch (ty1)
        {   case TYdouble_alias:
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
                c1 = cat(c1,push87());
                c1 = genf2(c1,0xD9,0xC0);       // FLD ST(0)
                pop87();
            }
            else
                op2 = 2;                        // FST e->E1
        }
        else
        {                                       // FSTP e->E1
            pop87();
        }
#if 0
        // Doesn't work if ST(0) gets saved to the stack by getlvalue()
        c2 = loadea(e->E1,&cs,op1,op2,0,0,0);
#else
        cs.Irex = 0;
        cs.Iflags = 0;
        cs.Iop = op1;
        if (*pretregs & (mST0 | ALLREGS | mBP | XMMREGS)) // if want result on stack too
        {   // Make sure it's still there
            elem *e2 = e->E2;
            while (e2->Eoper == OPcomma)
                e2 = e2->E2;
            note87(e2,0,0);
            c2 = getlvalue(&cs, e->E1, 0);
            c2 = cat(c2,makesure87(e2,0,0,1));
        }
        else
        {
            c2 = getlvalue(&cs, e->E1, 0);
        }
        cs.Irm |= modregrm(0,op2,0);            // OR in reg field
        if (I32)
            cs.Iflags &= ~CFopsize;
        else if (ADDFWAIT())
            cs.Iflags |= CFwait;
        else if (I64)
            cs.Irex &= ~REX_W;
        c2 = gen(c2, &cs);
#if LNGDBLSIZE == 12
        if (tysize[TYldouble] == 12)
        {
        /* This deals with the fact that 10 byte reals really
         * occupy 12 bytes by zeroing the extra 2 bytes.
         */
        if (op1 == 0xDB)
        {
            cs.Iop = 0xC7;                      // MOV EA+10,0
            NEWREG(cs.Irm, 0);
            cs.IEV1.sp.Voffset += 10;
            cs.IFL2 = FLconst;
            cs.IEV2.Vint = 0;
            cs.Iflags |= CFopsize;
            c2 = gen(c2, &cs);
        }
        }
#endif
        if (tysize[TYldouble] == 16)
        {
        /* This deals with the fact that 10 byte reals really
         * occupy 16 bytes by zeroing the extra 6 bytes.
         */
        if (op1 == 0xDB)
        {
            cs.Irex &= ~REX_W;
            cs.Iop = 0xC7;                      // MOV EA+10,0
            NEWREG(cs.Irm, 0);
            cs.IEV1.sp.Voffset += 10;
            cs.IFL2 = FLconst;
            cs.IEV2.Vint = 0;
            cs.Iflags |= CFopsize;
            c2 = gen(c2, &cs);

            cs.IEV1.sp.Voffset += 2;
            cs.Iflags &= ~CFopsize;
            c2 = gen(c2, &cs);
        }
        }
#endif
        c2 = genfwait(c2);
        freenode(e->E1);
        c1 = cat3(c1,c2,fixresult87(e,mST0 | mPSW,pretregs));
        return c1;
}

/*******************************
 * Perform an assignment to a long double/double/float.
 */

code *complex_eq87(elem *e,regm_t *pretregs)
{
        regm_t retregs;
        code *c1,*c2;
        code cs;
        unsigned op1;
        unsigned op2;
        unsigned sz;
        tym_t ty1;
        int fxch = 0;

        //printf("complex_eq87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
        assert(e->Eoper == OPeq);
        cs.Iflags = ADDFWAIT() ? CFwait : 0;
        cs.Irex = 0;
        retregs = mST01 | (*pretregs & mPSW);
        c1 = codelem(e->E2,&retregs,FALSE);
        ty1 = tybasic(e->E1->Ety);
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
                c1 = cat(c1,push87());
                c1 = cat(c1,push87());
                c1 = genf2(c1,0xD9,0xC0 + 1);   // FLD ST(1)
                genf2(c1,0xD9,0xC0 + 1);        // FLD ST(1)
                pop87();
                pop87();
            }
            else
            {   op2 = 2;                        // FST e->E1
                fxch = 1;
            }
        }
        else
        {                                       // FSTP e->E1
            pop87();
            pop87();
        }
        sz = tysize(ty1) / 2;
        if (*pretregs & (mST01 | mXMM0 | mXMM1))
        {
            cs.Iflags = 0;
            cs.Irex = 0;
            cs.Iop = op1;
            c2 = getlvalue(&cs, e->E1, 0);
            cs.IEVoffset1 += sz;
            cs.Irm |= modregrm(0, op2, 0);
            c2 = cat(c2, makesure87(e->E2, sz, 0, 0));
            c2 = gen(c2, &cs);
            c2 = genfwait(c2);
            c2 = cat(c2, makesure87(e->E2,  0, 1, 0));
        }
        else
        {
            c2 = loadea(e->E1,&cs,op1,op2,sz,0,0);
            c2 = genfwait(c2);
        }
        if (fxch)
            c2 = genf2(c2,0xD9,0xC8 + 1);       // FXCH ST(1)
        cs.IEVoffset1 -= sz;
        gen(c2, &cs);
        if (fxch)
            genf2(c2,0xD9,0xC8 + 1);            // FXCH ST(1)
        if (tysize[TYldouble] == 12)
        {
            if (op1 == 0xDB)
            {
                cs.Iop = 0xC7;                      // MOV EA+10,0
                NEWREG(cs.Irm, 0);
                cs.IEV1.sp.Voffset += 10;
                cs.IFL2 = FLconst;
                cs.IEV2.Vint = 0;
                cs.Iflags |= CFopsize;
                c2 = gen(c2, &cs);
                cs.IEVoffset1 += 12;
                c2 = gen(c2, &cs);                  // MOV EA+22,0
            }
        }
        if (tysize[TYldouble] == 16)
        {
            if (op1 == 0xDB)
            {
                cs.Iop = 0xC7;                      // MOV EA+10,0
                NEWREG(cs.Irm, 0);
                cs.IEV1.sp.Voffset += 10;
                cs.IFL2 = FLconst;
                cs.IEV2.Vint = 0;
                cs.Iflags |= CFopsize;
                c2 = gen(c2, &cs);

                cs.IEV1.sp.Voffset += 2;
                cs.Iflags &= ~CFopsize;
                c2 = gen(c2, &cs);

                cs.IEV1.sp.Voffset += 14;
                cs.Iflags |= CFopsize;
                c2 = gen(c2, &cs);

                cs.IEV1.sp.Voffset += 2;
                cs.Iflags &= ~CFopsize;
                c2 = gen(c2, &cs);
            }
        }
        c2 = genfwait(c2);
        freenode(e->E1);
        return cat3(c1,c2,fixresult_complex87(e,mST01 | mPSW,pretregs));
}

/*******************************
 * Perform an assignment while converting to integral type,
 * i.e. handle (e1 = (int) e2)
 */

code *cnvteq87(elem *e,regm_t *pretregs)
{
        regm_t retregs;
        code *c1,*c2;
        code cs;
        unsigned op1;
        unsigned op2;

        assert(e->Eoper == OPeq);
        assert(!*pretregs);
        retregs = mST0;
        elem_debug(e->E2);
        c1 = codelem(e->E2->E1,&retregs,FALSE);

        switch (e->E2->Eoper)
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
        freenode(e->E2);

        c1 = genfwait(c1);
        c1 = genrnd(c1, CW_roundto0);   // FLDCW roundto0

        pop87();
        cs.Iflags = ADDFWAIT() ? CFwait : 0;
        if (e->E1->Eoper == OPvar)
            notreg(e->E1);                      // cannot be put in register anymore
        c2 = loadea(e->E1,&cs,op1,op2,0,0,0);

        c2 = genfwait(c2);
        c2 = genrnd(c2, CW_roundtonearest);     // FLDCW roundtonearest

        freenode(e->E1);
        return cat(c1,c2);
}

/**********************************
 * Perform +=, -=, *= and /= for doubles.
 */

code *opass87(elem *e,regm_t *pretregs)
{
        regm_t retregs;
        code *cl,*cr,*c;
        code cs;
        unsigned op;
        unsigned opld;
        unsigned op1;
        unsigned op2;
        tym_t ty1;

        ty1 = tybasic(e->E1->Ety);
        switch (ty1)
        {   case TYdouble_alias:
            case TYidouble:
            case TYdouble:      op1 = ESC(MFdouble,1);  op2 = 3; break;
            case TYifloat:
            case TYfloat:       op1 = ESC(MFfloat,1);   op2 = 3; break;
            case TYildouble:
            case TYldouble:     op1 = 0xDB;             op2 = 7; break;

            case TYcfloat:
            case TYcdouble:
            case TYcldouble:
                return (e->Eoper == OPmodass)
                        ? opmod_complex87(e, pretregs)
                        : opass_complex87(e, pretregs);

            default:
                assert(0);
        }
        switch (e->Eoper)
        {   case OPpostinc:
            case OPaddass:      op = 0 << 3;    opld = 0xC1;    break;  // FADD
            case OPpostdec:
            case OPminass:      op = 5 << 3;    opld = 0xE1; /*0xE9;*/  break;  // FSUBR
            case OPmulass:      op = 1 << 3;    opld = 0xC9;    break;  // FMUL
            case OPdivass:      op = 7 << 3;    opld = 0xF1;    break;  // FDIVR
            case OPmodass:      break;
            default:            assert(0);
        }
        retregs = mST0;
        cr = codelem(e->E2,&retregs,FALSE);     // evaluate rvalue
        note87(e->E2,0,0);
        cl = getlvalue(&cs,e->E1,e->Eoper==OPmodass?mAX:0);
        cl = cat(cl,makesure87(e->E2,0,0,0));
        cs.Iflags |= ADDFWAIT() ? CFwait : 0;
        if (I32)
            cs.Iflags &= ~CFopsize;
        if (config.flags4 & CFG4fdivcall && e->Eoper == OPdivass)
        {
            c = push87();
            cs.Iop = op1;
            if (ty1 == TYldouble || ty1 == TYildouble)
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
            c = gen(c,&cs);
            c = genf2(c,0xD9,0xC8 + 1);         // FXCH ST(1)
            c = cat(c,callclib(e,CLIBfdiv87,&retregs,0));
            pop87();
        }
        else if (e->Eoper == OPmodass)
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

            c = push87();
            cs.Iop = op1;
            if (ty1 == TYldouble || ty1 == TYildouble)
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
            c = gen(c,&cs);                     // FLD   e->E1

            c1 = gen2(NULL, 0xD9, 0xF8);        // FPREM
            c1 = genjmpifC2(c1, c1);            // JC2 FM1
            c1 = genf2(c1,0xDD,0xD8 + 1);       // FSTP ST(1)
            c = cat(c,c1);

            pop87();
        }
        else if (ty1 == TYldouble || ty1 == TYildouble)
        {
            c = push87();
            cs.Iop = op1;
            cs.Irm |= modregrm(0, 5, 0);        // FLD tbyte ptr ...
            c = gen(c,&cs);                     // FLD   e->E1
            genf2(c,0xDE,opld);                 // FopP  ST(1)
            pop87();
        }
        else
        {   cs.Iop = op1 & ~1;
            cs.Irm |= op;
            c = gen(CNIL,&cs);                  // Fop e->E1
        }
        if (*pretregs & mPSW)
            genftst(c,e,0);                     // FTST ST0
        /* if want result in registers  */
        if (*pretregs & (mST0 | ALLREGS | mBP))
        {
            if (ty1 == TYldouble || ty1 == TYildouble)
            {
                c = cat(c,push87());
                c = genf2(c,0xD9,0xC0);         // FLD ST(0)
                pop87();
            }
            else
                op2 = 2;                        // FST e->E1
        }
        else
        {                                       // FSTP
            pop87();
        }
        cs.Iop = op1;
        NEWREG(cs.Irm,op2);                     // FSTx e->E1
        freenode(e->E1);
        gen(c,&cs);
        genfwait(c);
        return cat4(cr,cl,c,fixresult87(e,mST0 | mPSW,pretregs));
}

/***********************************
 * Perform %= where E1 is complex and E2 is real or imaginary.
 */

code *opmod_complex87(elem *e,regm_t *pretregs)
{
    regm_t retregs;
    code *cl,*cr,*c;
    code cs;
    tym_t ty1;
    unsigned sz2;

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

    ty1 = tybasic(e->E1->Ety);
    sz2 = tysize[ty1] / 2;

    retregs = mST0;
    cr = codelem(e->E2,&retregs,FALSE);         // FLD E2
    note87(e->E2,0,0);
    cl = getlvalue(&cs,e->E1,0);
    cl = cat(cl,makesure87(e->E2,0,0,0));
    cs.Iflags |= ADDFWAIT() ? CFwait : 0;
    if (!I16)
        cs.Iflags &= ~CFopsize;

    c = push87();
    switch (ty1)
    {
        case TYcdouble:  cs.Iop = ESC(MFdouble,1);      break;
        case TYcfloat:   cs.Iop = ESC(MFfloat,1);       break;
        case TYcldouble: cs.Iop = 0xDB; cs.Irm |= modregrm(0, 5, 0); break;
        default:
            assert(0);
    }
    c = gen(c,&cs);                             // FLD E1.re

    code *c1;

    c1 = gen2(NULL, 0xD9, 0xF8);                // FPREM
    c1 = genjmpifC2(c1, c1);                    // JC2 FM1
    c1 = genf2(c1, 0xD9, 0xC8 + 1);             // FXCH ST(1)
    c = cat(c,c1);

    c = cat(c, push87());
    cs.IEVoffset1 += sz2;
    gen(c, &cs);                                // FLD E1.im

    c1 = gen2(NULL, 0xD9, 0xF8);                // FPREM
    c1 = genjmpifC2(c1, c1);                    // JC2 FM2
    c1 = genf2(c1,0xDD,0xD8 + 1);               // FSTP ST(1)
    c = cat(c,c1);

    pop87();

    if (*pretregs & (mST01 | mPSW))
    {
        cs.Irm |= modregrm(0, 2, 0);
        gen(c, &cs);            // FST mreal.im
        cs.IEVoffset1 -= sz2;
        gen(c, &cs);            // FST mreal.re
        retregs = mST01;
    }
    else
    {
        cs.Irm |= modregrm(0, 3, 0);
        gen(c, &cs);            // FSTP mreal.im
        cs.IEVoffset1 -= sz2;
        gen(c, &cs);            // FSTP mreal.re
        pop87();
        pop87();
        retregs = 0;
    }
    freenode(e->E1);
    genfwait(c);
    return cat4(cr,cl,c,fixresult_complex87(e,retregs,pretregs));
}

/**********************************
 * Perform +=, -=, *= and /= for the lvalue being complex.
 */

code *opass_complex87(elem *e,regm_t *pretregs)
{
    regm_t retregs;
    regm_t idxregs;
    code *cl,*cr,*c;
    code cs;
    unsigned op;
    unsigned op2;
    tym_t ty1;
    unsigned sz2;

    ty1 = tybasic(e->E1->Ety);
    sz2 = tysize[ty1] / 2;
    switch (e->Eoper)
    {   case OPpostinc:
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

    if (!tycomplex(e->E2->Ety) &&
        (e->Eoper == OPmulass || e->Eoper == OPdivass))
    {
        retregs = mST0;
        cr = codelem(e->E2, &retregs, FALSE);
        note87(e->E2, 0, 0);
        cl = getlvalue(&cs, e->E1, 0);
        cl = cat(cl,makesure87(e->E2,0,0,0));
        cl = cat(cl,push87());
        cl = genf2(cl,0xD9,0xC0);               // FLD ST(0)
        goto L1;
    }
    else
    {
        cr = loadComplex(e->E2);
        cl = getlvalue(&cs,e->E1,0);
        cl = cat(cl,makesure87(e->E2,sz2,0,0));
        cl = cat(cl,makesure87(e->E2,0,1,0));
    }
    cs.Iflags |= ADDFWAIT() ? CFwait : 0;
    if (!I16)
        cs.Iflags &= ~CFopsize;

    switch (e->Eoper)
    {
        case OPpostinc:
        case OPaddass:
        case OPpostdec:
        case OPminass:
        L1:
            if (ty1 == TYcldouble)
            {
                c = push87();
                c = cat(c, push87());
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
                c = gen(c,&cs);                 // FLD e->E1.re
                cs.IEVoffset1 += sz2;
                gen(c,&cs);                     // FLD e->E1.im
                genf2(c, 0xDE, op2 + 2);        // FADDP/FSUBRP ST(2),ST
                genf2(c, 0xDE, op2 + 2);        // FADDP/FSUBRP ST(2),ST
                pop87();
                pop87();
                if (tyimaginary(e->E2->Ety))
                {
                    if (e->Eoper == OPmulass)
                    {
                        genf2(c, 0xD9, 0xE0);   // FCHS
                        genf2(c, 0xD9, 0xC8+1); // FXCH ST(1)
                    }
                    else if (e->Eoper == OPdivass)
                    {
                        genf2(c, 0xD9, 0xC8+1); // FXCH ST(1)
                        genf2(c, 0xD9, 0xE0);   // FCHS
                    }
                }
            L2:
                if (*pretregs & (mST01 | mPSW))
                {
                    c = cat(c,push87());
                    c = cat(c,push87());
                    c = genf2(c,0xD9,0xC1);     // FLD ST(1)
                    c = genf2(c,0xD9,0xC1);     // FLD ST(1)
                    retregs = mST01;
                }
                else
                    retregs = 0;
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0,7,0);
                gen(c,&cs);                     // FSTP e->E1.im
                cs.IEVoffset1 -= sz2;
                gen(c,&cs);                     // FSTP e->E1.re
                pop87();
                pop87();

            }
            else
            {   unsigned char rmop = cs.Irm | op;
                unsigned char rmfst = cs.Irm | modregrm(0,2,0);
                unsigned char rmfstp = cs.Irm | modregrm(0,3,0);
                unsigned char iopfst = (ty1 == TYcfloat) ? 0xD9 : 0xDD;
                unsigned char iop = (ty1 == TYcfloat) ? 0xD8 : 0xDC;

                cs.Iop = iop;
                cs.Irm = rmop;
                cs.IEVoffset1 += sz2;
                c = gen(NULL, &cs);             // FSUBR mreal.im
                if (tyimaginary(e->E2->Ety) && (e->Eoper == OPmulass || e->Eoper == OPdivass))
                {
                    if (e->Eoper == OPmulass)
                        genf2(c, 0xD9, 0xE0);           // FCHS
                    genf2(c,0xD9,0xC8 + 1);             // FXCH ST(1)
                    cs.IEVoffset1 -= sz2;
                    gen(c, &cs);                        // FMUL mreal.re
                    if (e->Eoper == OPdivass)
                        genf2(c, 0xD9, 0xE0);           // FCHS
                    if (*pretregs & (mST01 | mPSW))
                    {
                        cs.Iop = iopfst;
                        cs.Irm = rmfst;
                        cs.IEVoffset1 += sz2;
                        gen(c, &cs);                    // FST mreal.im
                        genf2(c,0xD9,0xC8 + 1);         // FXCH ST(1)
                        cs.IEVoffset1 -= sz2;
                        gen(c, &cs);                    // FST mreal.re
                        genf2(c,0xD9,0xC8 + 1);         // FXCH ST(1)
                        retregs = mST01;
                    }
                    else
                    {
                        cs.Iop = iopfst;
                        cs.Irm = rmfstp;
                        cs.IEVoffset1 += sz2;
                        gen(c, &cs);                    // FSTP mreal.im
                        pop87();
                        cs.IEVoffset1 -= sz2;
                        gen(c, &cs);                    // FSTP mreal.re
                        pop87();
                        retregs = 0;
                    }
                    goto L3;
                }

                if (*pretregs & (mST01 | mPSW))
                {
                    cs.Iop = iopfst;
                    cs.Irm = rmfst;
                    gen(c, &cs);                // FST mreal.im
                    genf2(c,0xD9,0xC8 + 1);     // FXCH ST(1)
                    cs.Iop = iop;
                    cs.Irm = rmop;
                    cs.IEVoffset1 -= sz2;
                    gen(c, &cs);                // FSUBR mreal.re
                    cs.Iop = iopfst;
                    cs.Irm = rmfst;
                    gen(c, &cs);                // FST mreal.re
                    genf2(c,0xD9,0xC8 + 1);     // FXCH ST(1)
                    retregs = mST01;
                }
                else
                {
                    cs.Iop = iopfst;
                    cs.Irm = rmfstp;
                    gen(c, &cs);                // FSTP mreal.im
                    pop87();
                    cs.Iop = iop;
                    cs.Irm = rmop;
                    cs.IEVoffset1 -= sz2;
                    gen(c, &cs);                // FSUBR mreal.re
                    cs.Iop = iopfst;
                    cs.Irm = rmfstp;
                    gen(c, &cs);                // FSTP mreal.re
                    pop87();
                    retregs = 0;
                }
            }
        L3:
            freenode(e->E1);
            genfwait(c);
            return cat4(cr,cl,c,fixresult_complex87(e,retregs,pretregs));

        case OPmulass:
            c = push87();
            c = cat(c, push87());
            if (ty1 == TYcldouble)
            {
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
                c = gen(c,&cs);                 // FLD e->E1.re
                cs.IEVoffset1 += sz2;
                gen(c,&cs);                     // FLD e->E1.im
                retregs = mST01;
                c = cat(c,callclib(e, CLIBcmul, &retregs, 0));
                goto L2;
            }
            else
            {
                cs.Iop = (ty1 == TYcfloat) ? 0xD9 : 0xDD;
                cs.Irm |= modregrm(0, 0, 0);    // FLD tbyte ptr ...
                c = gen(c,&cs);                 // FLD e->E1.re
                cs.IEVoffset1 += sz2;
                gen(c,&cs);                     // FLD e->E1.im
                retregs = mST01;
                c = cat(c,callclib(e, CLIBcmul, &retregs, 0));
                if (*pretregs & (mST01 | mPSW))
                {
                    cs.Irm |= modregrm(0, 2, 0);
                    gen(c, &cs);                // FST mreal.im
                    cs.IEVoffset1 -= sz2;
                    gen(c, &cs);                // FST mreal.re
                    retregs = mST01;
                }
                else
                {
                    cs.Irm |= modregrm(0, 3, 0);
                    gen(c, &cs);                // FSTP mreal.im
                    cs.IEVoffset1 -= sz2;
                    gen(c, &cs);                // FSTP mreal.re
                    pop87();
                    pop87();
                    retregs = 0;
                }
                goto L3;
            }

        case OPdivass:
            c = push87();
            c = cat(c, push87());
            idxregs = idxregm(&cs);             // mask of index regs used
            if (ty1 == TYcldouble)
            {
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0, 5, 0);    // FLD tbyte ptr ...
                c = gen(c,&cs);                 // FLD e->E1.re
                genf2(c,0xD9,0xC8 + 2);         // FXCH ST(2)
                cs.IEVoffset1 += sz2;
                gen(c,&cs);                     // FLD e->E1.im
                genf2(c,0xD9,0xC8 + 2);         // FXCH ST(2)
                retregs = mST01;
                c = cat(c,callclib(e, CLIBcdiv, &retregs, idxregs));
                goto L2;
            }
            else
            {
                cs.Iop = (ty1 == TYcfloat) ? 0xD9 : 0xDD;
                cs.Irm |= modregrm(0, 0, 0);    // FLD tbyte ptr ...
                c = gen(c,&cs);                 // FLD e->E1.re
                genf2(c,0xD9,0xC8 + 2);         // FXCH ST(2)
                cs.IEVoffset1 += sz2;
                gen(c,&cs);                     // FLD e->E1.im
                genf2(c,0xD9,0xC8 + 2);         // FXCH ST(2)
                retregs = mST01;
                c = cat(c,callclib(e, CLIBcdiv, &retregs, idxregs));
                if (*pretregs & (mST01 | mPSW))
                {
                    cs.Irm |= modregrm(0, 2, 0);
                    gen(c, &cs);                // FST mreal.im
                    cs.IEVoffset1 -= sz2;
                    gen(c, &cs);                // FST mreal.re
                    retregs = mST01;
                }
                else
                {
                    cs.Irm |= modregrm(0, 3, 0);
                    gen(c, &cs);                // FSTP mreal.im
                    cs.IEVoffset1 -= sz2;
                    gen(c, &cs);                // FSTP mreal.re
                    pop87();
                    pop87();
                    retregs = 0;
                }
                goto L3;
            }

        default:
            assert(0);
    }
    return NULL;
}

/**************************
 * OPnegass
 */

code *cdnegass87(elem *e,regm_t *pretregs)
{   regm_t retregs;
    unsigned op;
    code *cl,*cr,*c,cs;

    //printf("cdnegass87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    elem *e1 = e->E1;
    tym_t tyml = tybasic(e1->Ety);            // type of lvalue
    int sz = tysize[tyml];

    cl = getlvalue(&cs,e1,0);

    /* If the EA is really an XMM register, modEA() will fail.
     * So disallow putting e1 into a register.
     * A better way would be to negate the XMM register in place.
     */
    if (e1->Eoper == OPvar)
        e1->EV.sp.Vsym->Sflags &= ~GTregcand;

    cr = modEA(&cs);
    cs.Irm |= modregrm(0,6,0);
    cs.Iop = 0x80;
#if LNGDBLSIZE > 10
    if (tyml == TYldouble || tyml == TYildouble)
        cs.IEVoffset1 += 10 - 1;
    else if (tyml == TYcldouble)
        cs.IEVoffset1 += tysize[TYldouble] + 10 - 1;
    else
#endif
        cs.IEVoffset1 += sz - 1;
    cs.IFL2 = FLconst;
    cs.IEV2.Vuns = 0x80;
    c = gen(NULL,&cs);                  // XOR 7[EA],0x80
    if (tycomplex(tyml))
    {
        cs.IEVoffset1 -= sz / 2;
        gen(c,&cs);                     // XOR 7[EA],0x80
    }
    c = cat3(cl,cr,c);

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
        cs.IEVoffset1 -= sz - 1;
        c = cat(c, push87());
        c = gen(c,&cs);                 // FLD EA
        retregs = mST0;
    }
    else
        retregs = 0;

    freenode(e1);
    return cat(c,fixresult87(e,retregs,pretregs));
}

/************************
 * Take care of OPpostinc and OPpostdec.
 */

code *post87(elem *e,regm_t *pretregs)
{
        regm_t retregs;
        code *cl,*cr,*c;
        code cs;
        unsigned op;
        unsigned op1;
        unsigned reg;
        tym_t ty1;

        //printf("post87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
        assert(*pretregs);
        cl = getlvalue(&cs,e->E1,0);
        cs.Iflags |= ADDFWAIT() ? CFwait : 0;
        if (!I16)
            cs.Iflags &= ~CFopsize;
        ty1 = tybasic(e->E1->Ety);
        switch (ty1)
        {   case TYdouble_alias:
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
        cl = cat(cl,push87());
        cl = gen(cl,&cs);               // FLD e->E1
        if (tycomplex(ty1))
        {   unsigned sz = tysize[ty1] / 2;

            cl = cat(cl,push87());
            cs.IEVoffset1 += sz;
            cl = gen(cl,&cs);           // FLD e->E1
            retregs = mST0;             // note kludge to only load real part
            cr = codelem(e->E2,&retregs,FALSE); // load rvalue
            c = genf2(NULL,0xD8,        // FADD/FSUBR ST,ST2
                (e->Eoper == OPpostinc) ? 0xC0 + 2 : 0xE8 + 2);
            NEWREG(cs.Irm,reg);
            pop87();
            cs.IEVoffset1 -= sz;
            gen(c,&cs);                 // FSTP e->E1
            genfwait(c);
            freenode(e->E1);
            return cat4(cl, cr, c, fixresult_complex87(e, mST01, pretregs));
        }

        if (*pretregs & (mST0 | ALLREGS | mBP | XMMREGS))
        {   // Want the result in a register
            cl = cat(cl,push87());
            genf2(cl,0xD9,0xC0);        // FLD ST0
        }
        if (*pretregs & mPSW)           /* if result in flags           */
            genftst(cl,e,0);            // FTST ST0
        retregs = mST0;
        cr = codelem(e->E2,&retregs,FALSE);     /* load rvalue          */
        pop87();
        op = (e->Eoper == OPpostinc) ? modregrm(3,0,1) : modregrm(3,5,1);
        c = genf2(NULL,0xDE,op);        // FADDP/FSUBRP ST1
        NEWREG(cs.Irm,reg);
        pop87();
        gen(c,&cs);                     /* FSTP e->E1                   */
        genfwait(c);
        freenode(e->E1);
        return cat4(cl,cr,c,fixresult87(e,mPSW | mST0,pretregs));
}

/************************
 * Do the following opcodes:
 *      OPd_u64
 *      OPld_u64
 */
code *cdd_u64(elem *e, regm_t *pretregs)
{
    assert(I32 || I64);
    assert(*pretregs);
    if (I32)
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
        code *c = codelem(e->E1, &retregs, FALSE);
        tym_t tym = e->Ety;
        retregs = *pretregs;
        if (!retregs)
            retregs = ALLREGS;
        unsigned reg, reg2;
        code *c2 = allocreg(&retregs,&reg,tym);
        reg  = findreglsw(retregs);
        reg2 = findregmsw(retregs);
        c2 = movregconst(c2,reg2,0x80000000,0);
        c2 = cat(c2,getregs(mask[reg2] | mAX));

        code *cf1 = genfltreg(CNIL,0xC7,0,0);
        cf1->IFL2 = FLconst;
        cf1->IEV2.Vint = 0;                             // MOV floatreg+0,0
        genfltreg(cf1,0x89,reg2,4);                     // MOV floatreg+4,EDX
        code *cf3 = genfltreg(CNIL,0xC7,0,8);
        cf3->IFL2 = FLconst;
        cf3->IEV2.Vint = 0xFBF403E;                     // MOV floatreg+8,(roundTo0<<16)|adjust

        cf3 = cat(cf3,push87());
        code *cf4 = genfltreg(CNIL,0xDB,5,0);           // FLD real ptr floatreg
        gen2(cf4,0xD8,0xD9);                            // FCOMP
        pop87();
        gen2(cf4,0xDF,0xE0);                            // FSTSW AX
        genfltreg(cf4,0xD9,7,12);                       // FSTCW floatreg+12
        genfltreg(cf4,0xD9,5,10);                       // FLDCW floatreg+10
        genc2(cf4,0xF6,modregrm(3,0,4),1);              // TEST AH,1
        code *cnop1 = gennop(CNIL);
        genjmp(cf4,JE,FLcode,(block *)cnop1);           // JZ L1

        genfltreg(cf4,0xDB,5,0);                        // FLD real ptr floatreg
        genf2(cf4,0xDE,0xE8+1);                         // FSUBP ST(1),ST
        genfltreg(cf4,0xDF,7,0);                        // FISTP dword ptr floatreg
        genfltreg(cf4,0x8B,reg,0);                      // MOV reg,floatreg
        genfltreg(cf4,0x03,reg2,4);                     // ADD reg,floatreg+4
        genfltreg(cf4,0xD9,5,12);                       // FLDCW floatreg+12
        code *cnop2 = gennop(CNIL);
        genjmp(cf4,JMP,FLcode,(block *)cnop2);          // JMP L2

        genfltreg(cnop1,0xDF,7,0);                      // FISTP dword ptr floatreg
        genfltreg(cnop1,0x8B,reg,0);                    // MOV reg,floatreg
        genfltreg(cnop1,0x8B,reg2,4);                   // MOV reg,floatreg+4
        genfltreg(cnop1,0xD9,5,12);                     // FLDCW floatreg+12

        pop87();
        c = cat(cat4(c,c2,cf1,cf3), cat4(cf4,cnop1,cnop2,fixresult(e,retregs,pretregs)));
        return c;
    }
    else if (I64)
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
        code *c = codelem(e->E1, &retregs, FALSE);
        tym_t tym = e->Ety;
        retregs = *pretregs;
        if (!retregs)
            retregs = ALLREGS;
        unsigned reg;
        code *c2 = allocreg(&retregs,&reg,tym);
        regm_t regm2 = ALLREGS & ~retregs & ~mAX;
        unsigned reg2;
        c2 = cat(c2, allocreg(&regm2,&reg2,tym));
        c2 = movregconst(c2,reg2,0x80000000,0);
        c2 = cat(c2,getregs(mask[reg2] | mAX));

        code *cf1 = genfltreg(CNIL,0xC7,0,0);
        cf1->IFL2 = FLconst;
        cf1->IEV2.Vint = 0;                             // MOV floatreg+0,0
        genfltreg(cf1,0x89,reg2,4);                     // MOV floatreg+4,EDX
        code *cf3 = genfltreg(CNIL,0xC7,0,8);
        cf3->IFL2 = FLconst;
        cf3->IEV2.Vint = 0xFBF403E;                     // MOV floatreg+8,(roundTo0<<16)|adjust

        cf3 = cat(cf3,push87());
        code *cf4 = genfltreg(CNIL,0xDB,5,0);           // FLD real ptr floatreg
        gen2(cf4,0xD8,0xD9);                            // FCOMP
        pop87();
        gen2(cf4,0xDF,0xE0);                            // FSTSW AX
        genfltreg(cf4,0xD9,7,12);                       // FSTCW floatreg+12
        genfltreg(cf4,0xD9,5,10);                       // FLDCW floatreg+10
        genc2(cf4,0xF6,modregrm(3,0,4),1);              // TEST AH,1
        code *cnop1 = gennop(CNIL);
        genjmp(cf4,JE,FLcode,(block *)cnop1);           // JZ L1

        genfltreg(cf4,0xDB,5,0);                        // FLD real ptr floatreg
        genf2(cf4,0xDE,0xE8+1);                         // FSUBP ST(1),ST
        genfltreg(cf4,0xDF,7,0);                        // FISTP dword ptr floatreg
        genfltreg(cf4,0x8B,reg,0);                      // MOV reg,floatreg
        code_orrex(cf4, REX_W);
        genc2(cf4,0xC1,(REX_W << 16) | modregrmx(3,4,reg2),32); // SHL reg2,32
        gen2(cf4,0x03,(REX_W << 16) | modregxrmx(3,reg,reg2));  // ADD reg,reg2
        genfltreg(cf4,0xD9,5,12);                       // FLDCW floatreg+12
        code *cnop2 = gennop(CNIL);
        genjmp(cf4,JMP,FLcode,(block *)cnop2);          // JMP L2

        genfltreg(cnop1,0xDF,7,0);                      // FISTP dword ptr floatreg
        genfltreg(cnop1,0x8B,reg,0);                    // MOV reg,floatreg
        code_orrex(cnop1, REX_W);
        genfltreg(cnop1,0xD9,5,12);                     // FLDCW floatreg+12

        pop87();
        c = cat(cat4(c,c2,cf1,cf3), cat4(cf4,cnop1,cnop2,fixresult(e,retregs,pretregs)));
        return c;
    }
    else
        assert(0);
    return NULL;
}

/************************
 * Do the following opcodes:
 *      OPd_u32
 */
code *cdd_u32(elem *e, regm_t *pretregs)
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
    code *c = codelem(e->E1, &retregs, FALSE);
    tym_t tym = e->Ety;
    retregs = *pretregs & ALLREGS;
    if (!retregs)
        retregs = ALLREGS;
    unsigned reg;
    code *c2 = allocreg(&retregs,&reg,tym);

    code *cf3 = genfltreg(CNIL,0xC7,0,8);
    cf3->IFL2 = FLconst;
    cf3->IEV2.Vint = 0x0FBF0000;                 // MOV floatreg+8,(roundTo0<<16)

    genfltreg(cf3,0xD9,7,12);                    // FSTCW floatreg+12
    genfltreg(cf3,0xD9,5,10);                    // FLDCW floatreg+10

    genfltreg(cf3,0xDF,7,0);                     // FISTP dword ptr floatreg
    genfltreg(cf3,0xD9,5,12);                    // FLDCW floatreg+12
    genfltreg(cf3,0x8B,reg,0);                   // MOV reg,floatreg

    pop87();
    c = cat4(c,c2,cf3,fixresult(e,retregs,pretregs));
    return c;
}

/************************
 * Do the following opcodes:
 *      OPd_s16
 *      OPd_s32
 *      OPd_u16
 *      OPd_s64
 */

code *cnvt87(elem *e,regm_t *pretregs)
{
        regm_t retregs;
        code *c1,*c2;
        unsigned mf,rf,reg;
        tym_t tym;
        int clib;
        int sz;
        int szoff;

        //printf("cnvt87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
        assert(*pretregs);
        tym = e->Ety;
        sz = tysize(tym);
        szoff = sz;

        switch (e->Eoper)
        {   case OPd_s16:
                clib = CLIBdblint87;
                mf = ESC(MFword,1);
                rf = 3;
                break;

            case OPd_u16:
                szoff = 4;
            case OPd_s32:
                clib = CLIBdbllng87;
                mf = ESC(MFlong,1);
                rf = 3;
                break;

            case OPd_s64:
                clib = CLIBdblllng;
                mf = 0xDF;
                rf = 7;
                break;

            default:
                assert(0);
        }

        if (I16)                       // C may change the default control word
        {
            if (clib == CLIBdblllng)
            {   retregs = I32 ? DOUBLEREGS_32 : DOUBLEREGS_16;
                c1 = codelem(e->E1,&retregs,FALSE);
                c2 = callclib(e,clib,pretregs,0);
            }
            else
            {   retregs = mST0; //I32 ? DOUBLEREGS_32 : DOUBLEREGS_16;
                c1 = codelem(e->E1,&retregs,FALSE);
                c2 = callclib(e,clib,pretregs,0);
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

            unsigned szpush = szoff + 2;
            if (config.flags3 & CFG3pic)
                szpush += 2;
            szpush = (szpush + REGSIZE - 1) & ~(REGSIZE - 1);

            retregs = mST0;
            c1 = codelem(e->E1,&retregs,FALSE);

            if (szpush == REGSIZE)
                c1 = gen1(c1,0x50 + AX);                // PUSH EAX
            else
                c1 = cod3_stackadj(c1, szpush);
            c1 = genfwait(c1);
            genc1(c1,0xD9,modregrm(2,7,4) + 256*modregrm(0,4,SP),FLconst,szoff); // FSTCW szoff[ESP]

            c1 = genfwait(c1);

            if (config.flags3 & CFG3pic)
            {
                genc(c1,0xC7,modregrm(2,0,4) + 256*modregrm(0,4,SP),FLconst,szoff+2,FLconst,CW_roundto0); // MOV szoff+2[ESP], CW_roundto0
                code_orflag(c1, CFopsize);
                genc1(c1,0xD9,modregrm(2,5,4) + 256*modregrm(0,4,SP),FLconst,szoff+2); // FLDCW szoff+2[ESP]
            }
            else
                c1 = genrnd(c1, CW_roundto0);   // FLDCW roundto0

            pop87();

            c1 = genfwait(c1);
            gen2sib(c1,mf,modregrm(0,rf,4),modregrm(0,4,SP));                   // FISTP [ESP]

            retregs = *pretregs & (ALLREGS | mBP);
            if (!retregs)
                    retregs = ALLREGS;
            c2 = allocreg(&retregs,&reg,tym);

            c2 = genfwait(c2);                                                          // FWAIT
            c2 = genc1(c2,0xD9,modregrm(2,5,4) + 256*modregrm(0,4,SP),FLconst,szoff);   // FLDCW szoff[ESP]

            if (szoff > REGSIZE)
            {   szpush -= REGSIZE;
                c2 = genpop(c2,findreglsw(retregs));       // POP lsw
            }
            szpush -= REGSIZE;
            c2 = genpop(c2,reg);                           // POP reg

            if (szpush)
                cod3_stackadj(c2, -szpush);
            c2 = cat(c2,fixresult(e,retregs,pretregs));
        }
        else
        {
            // This is incorrect. For -inf and nan, the 8087 returns the largest
            // negative int (0x80000....). For -inf, 0x7FFFF... should be returned,
            // and for nan, 0 should be returned.
            retregs = mST0;
            c1 = codelem(e->E1,&retregs,FALSE);

            c1 = genfwait(c1);
            c1 = genrnd(c1, CW_roundto0);       // FLDCW roundto0

            pop87();
            c1 = genfltreg(c1,mf,rf,0);         // FISTP floatreg
            retregs = *pretregs & (ALLREGS | mBP);
            if (!retregs)
                    retregs = ALLREGS;
            c2 = allocreg(&retregs,&reg,tym);

            c2 = genfwait(c2);

            if (sz > REGSIZE)
            {   c2 = genfltreg(c2,0x8B,reg,REGSIZE);    // MOV reg,floatreg + REGSIZE
                                                        // MOV lsreg,floatreg
                genfltreg(c2,0x8B,findreglsw(retregs),0);
            }
            else
                c2 = genfltreg(c2,0x8B,reg,0);  // MOV reg,floatreg
            c2 = genrnd(c2, CW_roundtonearest); // FLDCW roundtonearest
            c2 = cat(c2,fixresult(e,retregs,pretregs));
        }
        return cat(c1,c2);
}

/************************
 * Do OPrndtol.
 */

code *cdrndtol(elem *e,regm_t *pretregs)
{
        regm_t retregs;
        code *c1,*c2;
        unsigned reg;
        tym_t tym;
        unsigned sz;
        unsigned char op1,op2;

        if (*pretregs == 0)
            return codelem(e->E1,pretregs,FALSE);
        tym = e->Ety;
        retregs = mST0;
        c1 = codelem(e->E1,&retregs,FALSE);

        sz = tysize(tym);
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
        c1 = genfltreg(c1,op1,op2,0);           // FISTP floatreg
        retregs = *pretregs & (ALLREGS | mBP);
        if (!retregs)
                retregs = ALLREGS;
        c2 = allocreg(&retregs,&reg,tym);
        c2 = genfwait(c2);                      // FWAIT
        if (tysize(tym) > REGSIZE)
        {   c2 = genfltreg(c2,0x8B,reg,REGSIZE);        // MOV reg,floatreg + REGSIZE
                                                        // MOV lsreg,floatreg
            genfltreg(c2,0x8B,findreglsw(retregs),0);
        }
        else
        {
            c2 = genfltreg(c2,0x8B,reg,0);      // MOV reg,floatreg
            if (tysize(tym) == 8 && I64)
                code_orrex(c2, REX_W);
        }
        c2 = cat(c2,fixresult(e,retregs,pretregs));

        return cat(c1,c2);
}

/*************************
 * Do OPscale, OPyl2x, OPyl2xp1.
 */

code *cdscale(elem *e,regm_t *pretregs)
{
    regm_t retregs;
    code *c1,*c2,*c3;

    assert(*pretregs != 0);

    retregs = mST0;
    c1 = codelem(e->E1,&retregs,FALSE);
    note87(e->E1,0,0);
    c2 = codelem(e->E2,&retregs,FALSE);
    c2 = cat(c2,makesure87(e->E1,0,1,0));       // now have x,y on stack; need y,x
    switch (e->Eoper)
    {
        case OPscale:
            c2 = genf2(c2,0xD9,0xFD);                   // FSCALE
            genf2(c2,0xDD,0xD8 + 1);                    // FSTP ST(1)
            break;

        case OPyl2x:
            c2 = genf2(c2,0xD9,0xF1);                   // FYL2X
            break;

        case OPyl2xp1:
            c2 = genf2(c2,0xD9,0xF9);                   // FYL2XP1
            break;
    }
    pop87();
    c3 = fixresult87(e,mST0,pretregs);
    return cat3(c1,c2,c3);
}


/**********************************
 * Unary -, absolute value, square root, sine, cosine
 */

code *neg87(elem *e,regm_t *pretregs)
{
        //printf("neg87()\n");

        assert(*pretregs);
        int op;
        switch (e->Eoper)
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
        code *c1 = codelem(e->E1,&retregs,FALSE);
        c1 = genf2(c1,0xD9,op);                 // FCHS/FABS/FSQRT/FSIN/FCOS/FRNDINT
        code *c2 = fixresult87(e,mST0,pretregs);
        return cat(c1,c2);
}

/**********************************
 * Unary - for complex operands
 */

code *neg_complex87(elem *e,regm_t *pretregs)
{
    regm_t retregs;
    code *c1,*c2;

    assert(e->Eoper == OPneg);
    retregs = mST01;
    c1 = codelem(e->E1,&retregs,FALSE);
    c1 = genf2(c1,0xD9,0xE0);           // FCHS
    genf2(c1,0xD9,0xC8 + 1);            // FXCH ST(1)
    genf2(c1,0xD9,0xE0);                // FCHS
    genf2(c1,0xD9,0xC8 + 1);            // FXCH ST(1)
    c2 = fixresult_complex87(e,mST01,pretregs);
    return cat(c1,c2);
}

/*********************************
 */

code *cdind87(elem *e,regm_t *pretregs)
{   code *c,*ce,cs;

    //printf("cdind87(e = %p, *pretregs = %s)\n",e,regm_str(*pretregs));

    c = getlvalue(&cs,e,0);             // get addressing mode
    if (*pretregs)
    {
        switch (tybasic(e->Ety))
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
                if (I64)
                    cs.Irex &= ~REX_W;
                cs.Iop = 0xDB;
                cs.Irm |= modregrm(0,5,0);
                break;

            default:
                assert(0);
        }
        c = cat(c,push87());
        c = gen(c,&cs);                 // FLD EA
        ce = fixresult87(e,mST0,pretregs);
        c = cat(c,ce);
    }
    return c;
}

/************************************
 * Reset statics for another .obj file.
 */

void cg87_reset()
{
    memset(&oldd,0,sizeof(oldd));
}


/*****************************************
 * Initialize control word constants.
 */

STATIC code *genrnd(code *c, short cw)
{
    if (config.flags3 & CFG3pic)
    {   code *c1;

        c1 = genfltreg(NULL, 0xC7, 0, 0);       // MOV floatreg, cw
        c1->IFL2 = FLconst;
        c1->IEV2.Vuns = cw;

        c1 = genfltreg(c1, 0xD9, 5, 0);         // FLDCW floatreg
        c = cat(c, c1);
    }
    else
    {
        if (!oldd.round)                // if not initialized
        {   short cwi;

            oldd.round = 1;

            cwi = CW_roundto0;          // round to 0
            oldd.roundto0 = out_readonly_sym(TYshort,&cwi,2);
            cwi = CW_roundtonearest;            // round to nearest
            oldd.roundtonearest = out_readonly_sym(TYshort,&cwi,2);
        }
        symbol *rnddir = (cw == CW_roundto0) ? oldd.roundto0 : oldd.roundtonearest;
        code cs;
        cs.Iop = 0xD9;
        cs.Iflags = CFoff;
        cs.Irex = 0;
        cs.IEVsym1 = rnddir;
        cs.IFL1 = rnddir->Sfl;
        cs.IEVoffset1 = 0;
        cs.Irm = modregrm(0,5,BPRM);
        c = gen(c,&cs);
    }
    return c;
}

/************************* Complex Numbers *********************/

/***************************
 * Set the PSW based on the state of ST01.
 * Input:
 *      pop     if stack should be popped after test
 * Returns:
 *      start of code appended to c.
 */

STATIC code * genctst(code *c,elem *e,int pop)
#if __DMC__
__in
{
    assert(pop == 0 || pop == 1);
}
__body
#endif
{
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

    code *cnop = gennop(CNIL);
    c = cat(c,push87());
    c = gen2(c,0xD9,0xEE);              // FLDZ
    if (NOSAHF)
    {
        gen2(c,0xDF,0xE9);              // FUCOMIP
        pop87();
        genjmp(c,JNE,FLcode,(block *) cnop); // JNE     L1
        genjmp(c,JP, FLcode,(block *) cnop); // JP      L1
        gen2(c,0xD9,0xEE);                   // FLDZ
        gen2(c,0xDF,0xEA);                   // FUCOMIP ST(2)
        if (pop)
        {
            genf2(cnop,0xDD,modregrm(3,3,0));   // FPOP
            genf2(cnop,0xDD,modregrm(3,3,0));   // FPOP
            pop87();
            pop87();
        }
    }
    else if (pop)
    {
        gen2(c,0xDA,0xE9);              // FUCOMPP
        pop87();
        pop87();
        cg87_87topsw(c);                // put 8087 flags in CPU flags
        gen2(c,0xD9,0xEE);              // FLDZ
        gen2(c,0xDA,0xE9);              // FUCOMPP
        pop87();
        genjmp(c,JNE,FLcode,(block *) cnop); // JNE     L1
        genjmp(c,JP, FLcode,(block *) cnop); // JP      L1
        cg87_87topsw(c);                // put 8087 flags in CPU flags
    }
    else
    {
        gen2(c,0xDD,0xE1);              // FUCOM
        cg87_87topsw(c);                // put 8087 flags in CPU flags
        gen2(c,0xDD,0xEA);              // FUCOMP ST(2)
        pop87();
        genjmp(c,JNE,FLcode,(block *) cnop); // JNE     L1
        genjmp(c,JP, FLcode,(block *) cnop); // JP      L1
        cg87_87topsw(c);                // put 8087 flags in CPU flags
    }
    return cat(c, cnop);
}

/******************************
 * Given the result of an expression is in retregs,
 * generate necessary code to return result in *pretregs.
 */


code *fixresult_complex87(elem *e,regm_t retregs,regm_t *pretregs)
{
    tym_t tym;
    code *c1,*c2;
    unsigned sz;

#if 0
    printf("fixresult_complex87(e = %p, retregs = %s, *pretregs = %s)\n",
        e,regm_str(retregs),regm_str(*pretregs));
#endif
    assert(!*pretregs || retregs);
    c1 = CNIL;
    c2 = CNIL;
    tym = tybasic(e->Ety);
    sz = tysize[tym];

    if (*pretregs == 0 && retregs == mST01)
    {
        c1 = genf2(c1,0xDD,modregrm(3,3,0));    // FPOP
        pop87();
        c1 = genf2(c1,0xDD,modregrm(3,3,0));    // FPOP
        pop87();
    }
    else if (tym == TYcfloat && *pretregs & (mAX|mDX) && retregs & mST01)
    {
        if (*pretregs & mPSW && !(retregs & mPSW))
            c1 = genctst(c1,e,0);               // FTST
        pop87();
        c1 = genfltreg(c1, ESC(MFfloat,1),3,0); // FSTP floatreg
        genfwait(c1);
        c2 = getregs(mDX|mAX);
        c2 = genfltreg(c2, 0x8B, DX, 0);        // MOV EDX,floatreg

        pop87();
        c2 = genfltreg(c2, ESC(MFfloat,1),3,0); // FSTP floatreg
        genfwait(c2);
        c2 = genfltreg(c2, 0x8B, AX, 0);        // MOV EAX,floatreg
    }
    else if (tym == TYcfloat && retregs & (mAX|mDX) && *pretregs & mST01)
    {
        c1 = push87();
        c1 = genfltreg(c1, 0x89, AX, 0);        // MOV floatreg, EAX
        genfltreg(c1, 0xD9, 0, 0);              // FLD float ptr floatreg

        c2 = push87();
        c2 = genfltreg(c2, 0x89, DX, 0);        // MOV floatreg, EDX
        genfltreg(c2, 0xD9, 0, 0);              // FLD float ptr floatreg

        if (*pretregs & mPSW)
            c2 = genctst(c2,e,0);               // FTST
    }
    else if ((tym == TYcfloat || tym == TYcdouble) &&
             *pretregs & (mXMM0|mXMM1) && retregs & mST01)
    {
        unsigned xop = xmmload(tym == TYcfloat ? TYfloat : TYdouble);
        unsigned mf = tym == TYcfloat ? MFfloat : MFdouble;
        if (*pretregs & mPSW && !(retregs & mPSW))
            c1 = genctst(c1,e,0);               // FTST
        pop87();
        c1 = genfltreg(c1, ESC(mf,1),3,0);      // FSTP floatreg
        genfwait(c1);
        c2 = getregs(mXMM0|mXMM1);
        c2 = genfltreg(c2, xop, XMM1 - XMM0, 0); // LODS(SD) XMM1,floatreg

        pop87();
        c2 = genfltreg(c2, ESC(mf,1),3,0);       // FSTP floatreg
        genfwait(c2);
        c2 = genfltreg(c2, xop, XMM0 - XMM0, 0); // MOVD XMM0,floatreg
    }
    else if ((tym == TYcfloat || tym == TYcdouble) &&
             retregs & (mXMM0|mXMM1) && *pretregs & mST01)
    {
        unsigned xop = xmmstore(tym == TYcfloat ? TYfloat : TYdouble);
        unsigned fop = tym == TYcfloat ? 0xD9 : 0xDD;
        c1 = push87();
        c1 = genfltreg(c1, xop, XMM0-XMM0, 0);  // STOS(SD) floatreg, XMM0
        genfltreg(c1, fop, 0, 0);               // FLD double ptr floatreg

        c2 = push87();
        c2 = genfltreg(c2, xop, XMM1-XMM0, 0);  // MOV floatreg, XMM1
        genfltreg(c2, fop, 0, 0);               // FLD double ptr floatreg

        if (*pretregs & mPSW)
            c2 = genctst(c2,e,0);               // FTST
    }
    else
    {   if (*pretregs & mPSW)
        {   if (!(retregs & mPSW))
            {   assert(retregs & mST01);
                c1 = genctst(c1,e,!(*pretregs & mST01));        // FTST
            }
        }
        assert(!(*pretregs & mST01) || (retregs & mST01));
    }
    if (*pretregs & mST01)
    {   note87(e,0,1);
        note87(e,sz/2,0);
    }
    return cat(c1,c2);
}

/*****************************************
 * Operators OPc_r and OPc_i
 */

code *cdconvt87(elem *e, regm_t *pretregs)
{
    regm_t retregs;
    code *c;

    retregs = mST01;
    c = codelem(e->E1, &retregs, FALSE);
    switch (e->Eoper)
    {
        case OPc_r:
            c = genf2(c,0xDD,0xD8 + 0); // FPOP
            pop87();
            break;

        case OPc_i:
            c = genf2(c,0xDD,0xD8 + 1); // FSTP ST(1)
            pop87();
            break;

        default:
            assert(0);
    }
    retregs = mST0;
    c = cat(c, fixresult87(e, retregs, pretregs));
    return c;
}

/**************************************
 * Load complex operand into ST01 or flags or both.
 */

code *cload87(elem *e, regm_t *pretregs)
#if __DMC__
__in
{
    //printf("e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    //elem_print(e);
    assert(!I16);
    if (I32)
    {
        assert(config.inline8087);
        elem_debug(e);
        assert(*pretregs & (mST01 | mPSW));
        assert(!(*pretregs & ~(mST01 | mPSW)));
    }
}
__out (result)
{
}
__body
#endif
{
    tym_t ty = tybasic(e->Ety);
    code *c = NULL;
    code *cpush = NULL;
    code cs;
    unsigned mf;
    unsigned sz;
    unsigned char ldop;
    regm_t retregs;
    int i;

    //printf("cload87(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    sz = tysize[ty] / 2;
    memset(&cs, 0, sizeof(cs));
    if (ADDFWAIT())
        cs.Iflags = CFwait;
    switch (ty)
    {
        case TYcfloat:      mf = MFfloat;           break;
        case TYcdouble:     mf = MFdouble;          break;
        case TYcldouble:    break;
        default:            assert(0);
    }
    switch (e->Eoper)
    {
        case OPvar:
            notreg(e);                  // never enregister this variable
        case OPind:
            cpush = cat(push87(), push87());
            switch (ty)
            {
                case TYcfloat:
                case TYcdouble:
                    c = loadea(e,&cs,ESC(mf,1),0,0,0,0);        // FLD var
                    cs.IEVoffset1 += sz;
                    c = gen(c, &cs);
                    break;

                case TYcldouble:
                    c = loadea(e,&cs,0xDB,5,0,0,0);             // FLD var
                    cs.IEVoffset1 += sz;
                    c = gen(c, &cs);
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
            c = cload87(e->E1, pretregs);
            freenode(e->E1);
            return c;

        case OPconst:
            cpush = cat(push87(), push87());
            for (i = 0; i < 2; i++)
            {
                ldop = loadconst(e, i);
                if (ldop)
                {
                    c = genf2(c,0xD9,ldop);             // FLDx
                }
                else
                {
                    assert(0);
                }
            }
            retregs = mST01;
            break;

        default:
#ifdef DEBUG
            elem_print(e);
#endif
            assert(0);
    }
    return cat4(cpush,c,fixresult_complex87(e, retregs, pretregs), NULL);
}

#endif // !SPP
