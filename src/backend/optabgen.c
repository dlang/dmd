// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


/* Generate op-code tables
 * Creates optab.c,debtab.c,cdxxx.c,elxxx.c
 */

#include        <stdio.h>
#include        <stdlib.h>
#include        <time.h>
#include        <assert.h>
#include        "cc.h"
#include        "oper.h"

void doreltables(FILE *f);
void dotab();
void dotytab();
void dooptab();
void fltables();

unsigned char xptab1[OPMAX],xptab2[OPMAX],xptab3[OPMAX];

int _binary[] =
        {OPadd,OPmul,OPand,OPmin,OPcond,OPcomma,OPdiv,OPmod,OPxor,
         OPor,OPoror,OPandand,OPshl,OPshr,OPashr,OPstreq,OPstrcpy,OPstrcat,OPstrcmp,
         OPpostinc,OPpostdec,OPeq,OPaddass,OPminass,OPmulass,OPdivass,
         OPmodass,OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,
         OPle,OPgt,OPlt,OPge,OPeqeq,OPne,OPparam,OPcall,OPcallns,OPcolon,OPcolon2,
         OPbit,OPbrack,OParrowstar,OPmemcpy,OPmemcmp,OPmemset,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
         OPinfo,OParray,OPfield,OPnewarray,OPmultinewarray,OPinstanceof,OPfinalinstanceof,
         OPcheckcast,OPpair,OPrpair,
         OPbt,OPbtc,OPbtr,OPbts,OPror,OProl,OPbtst,
         OPremquo,
#if TX86
         OPoutp,OPscale,OPyl2x,OPyl2xp1,
         OPvecsto,
#endif
        };
int _unary[] =
        {OPnot,OPcom,OPind,OPaddr,OPneg,OPuadd,
         OPabs,OPrndtol,OPrint,
         OPpreinc,OPpredec,
         OPbool,OPstrlen,OPnullcheck,
         OPb_8,OPs16_32,OPu16_32,OPd_s32,OPd_u32,
         OPs32_d,OPu32_d,OPd_s16,OPs16_d,OP32_16,
         OPd_f,OPf_d,OPu8_16,OPs8_16,OP16_8,
         OPd_ld, OPld_d,OPc_r,OPc_i,
         OPu32_64,OPs32_64,OP64_32,OPmsw,
         OPd_s64,OPs64_d,OPd_u64,OPu64_d,OPld_u64,
         OP128_64,OPs64_128,OPu64_128,
         OPucall,OPucallns,OPstrpar,OPstrctor,OPu16_d,OPd_u16,
         OParrow,OPnegass,
         OPctor,OPdtor,OPsetjmp,OPvoid,OParraylength,
         OPbsf,OPbsr,OPbswap,OPpopcnt,
         OPddtor,
         OPvector,
#if TX86 && MARS
         OPva_start,
#endif
#if TX86
         OPsqrt,OPsin,OPcos,OPinp,
#endif
#if TARGET_SEGMENTED
         OPvp_fp,OPcvp_fp,OPnp_fp,OPnp_f16p,OPf16p_np,OPoffset,
#endif
        };
int _commut[] = {OPadd,OPand,OPor,OPxor,OPmul,OPeqeq,OPne,OPle,OPlt,OPge,OPgt,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
        };
int _assoc[] = {OPadd,OPand,OPor,OPxor,OPmul};
int _assign[] =
        {OPstreq,OPeq,OPaddass,OPminass,OPmulass,OPdivass,OPmodass,
         OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,OPpostinc,OPpostdec,
         OPnegass,OPvecsto,
        };
int _wid[] =
        {OPadd,OPmin,OPand,OPor,OPxor,OPcom,OPneg,OPmul,OPaddass,OPnegass,
         OPminass,OPandass,OPorass,OPxorass,OPmulass,OPshlass,OPshl,OPshrass,
         OPashrass,
        };
int _eop0e[] =
        {OPadd,OPmin,OPxor,OPor,OPshl,OPshr,OPashr,OPpostinc,OPpostdec,OPaddass,
         OPminass,OPshrass,OPashrass,OPshlass,OPxorass,OPorass,
         OPror,OProl,
        };
int _eop00[] = {OPmul,OPand,OPmulass,OPandass};
int _eop1e[] = {OPmul,OPdiv,OPmulass,OPdivass};
int _call[] = {OPcall,OPucall,OPcallns,OPucallns};
int _rel[] = {OPeqeq,OPne,OPle,OPlt,OPgt,OPge,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
        };
int _logical[] = {OPeqeq,OPne,OPle,OPlt,OPgt,OPge,OPandand,OPoror,OPnot,OPbool,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
         OPbt,OPbtst,
        };
int _def[] = {OPstreq,OPeq,OPaddass,OPminass,OPmulass,OPdivass,OPmodass,
                OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,
                OPpostinc,OPpostdec,
                OPcall,OPucall,OPasm,OPstrcpy,OPmemcpy,OPmemset,OPstrcat,
                OPnegass,OPnewarray,OPmultinewarray,
                OPbtc,OPbtr,OPbts,
                OPvecsto,
             };
int _sideff[] = {OPasm,OPucall,OPstrcpy,OPmemcpy,OPmemset,OPstrcat,
                OPcall,OPeq,OPstreq,OPpostinc,OPpostdec,
                OPaddass,OPminass,OPmulass,OPdivass,OPmodass,OPandass,
                OPorass,OPxorass,OPshlass,OPshrass,OPashrass,
                OPnegass,OPctor,OPdtor,OPmark,OPvoid,OPnewarray,
                OPmultinewarray,OPcheckcast,OPnullcheck,
                OPbtc,OPbtr,OPbts,
                OPhalt,OPdctor,OPddtor,
#if TX86 && MARS
                OPva_start,
#endif
#if TX86
                OPinp,OPoutp,OPvecsto,
#endif
                };
int _rtol[] = {OPeq,OPstreq,OPstrcpy,OPmemcpy,OPpostinc,OPpostdec,OPaddass,
                OPminass,OPmulass,OPdivass,OPmodass,OPandass,
                OPorass,OPxorass,OPshlass,OPshrass,OPashrass,
                OPcall,OPcallns,OPinfo,OPmemset,
                OPvecsto,
                };
int _ae[] = {OPvar,OPconst,OPrelconst,OPneg,
                OPabs,OPrndtol,OPrint,
                OPstrlen,OPstrcmp,OPind,OPaddr,
                OPnot,OPbool,OPcom,OPadd,OPmin,OPmul,OPand,OPor,OPmemcmp,
                OPxor,OPdiv,OPmod,OPshl,OPshr,OPashr,OPeqeq,OPne,OPle,OPlt,OPge,OPgt,
                OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
                OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
                OPs16_32,OPu16_32,OPd_s32,OPd_u32,OPu16_d,OPd_u16,
                OPs32_d,OPu32_d,OPd_s16,OPs16_d,OP32_16,
                OPd_f,OPf_d,OPu8_16,OPs8_16,OP16_8,
                OPd_ld,OPld_d,OPc_r,OPc_i,
                OPu32_64,OPs32_64,OP64_32,OPmsw,
                OPd_s64,OPs64_d,OPd_u64,OPu64_d,OPld_u64,
                OP128_64,OPs64_128,OPu64_128,
                OPsizeof,OParray,OPfield,OPinstanceof,OPfinalinstanceof,OPcheckcast,OParraylength,
                OPcallns,OPucallns,OPnullcheck,OPpair,OPrpair,
                OPbsf,OPbsr,OPbt,OPbswap,OPb_8,OPbtst,OPpopcnt,
                OPgot,OPremquo,
                OPnullptr,
                OProl,OPror,
#if TX86
                OPsqrt,OPsin,OPcos,OPscale,
#endif
#if TARGET_SEGMENTED
                OPvp_fp,OPcvp_fp,OPnp_fp,OPnp_f16p,OPf16p_np,OPoffset,
#endif
                };
int _exp[] = {OPvar,OPconst,OPrelconst,OPneg,OPabs,OPrndtol,OPrint,
                OPstrlen,OPstrcmp,OPind,OPaddr,
                OPnot,OPbool,OPcom,OPadd,OPmin,OPmul,OPand,OPor,OPstring,
                OPxor,OPdiv,OPmod,OPshl,OPshr,OPashr,OPeqeq,OPne,OPle,OPlt,OPge,OPgt,
                OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
                OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
                OPcomma,OPasm,OPsizeof,OPmemcmp,
                OPs16_32,OPu16_32,OPd_s32,OPd_u32,OPu16_d,OPd_u16,
                OPs32_d,OPu32_d,OPd_s16,OPs16_d,OP32_16,
                OPd_f,OPf_d,OPu8_16,OPs8_16,OP16_8,
                OPd_ld, OPld_d,OPc_r,OPc_i,
                OPu32_64,OPs32_64,OP64_32,OPmsw,
                OPd_s64,OPs64_d,OPd_u64,OPu64_d,OPld_u64,
                OP128_64,OPs64_128,OPu64_128,
                OPbit,OPind,OPucall,OPucallns,OPnullcheck,
                OParray,OPfield,OPinstanceof,OPfinalinstanceof,OPcheckcast,OParraylength,OPhstring,
                OPcall,OPcallns,OPeq,OPstreq,OPpostinc,OPpostdec,
                OPaddass,OPminass,OPmulass,OPdivass,OPmodass,OPandass,
                OPorass,OPxorass,OPshlass,OPshrass,OPashrass,OPoror,OPandand,OPcond,
                OPbsf,OPbsr,OPbt,OPbtc,OPbtr,OPbts,OPbswap,OPbtst,OPpopcnt,
                OProl,OPror,OPvector,
                OPpair,OPrpair,OPframeptr,OPgot,OPremquo,
                OPcolon,OPcolon2,OPasm,OPstrcpy,OPmemcpy,OPmemset,OPstrcat,OPnegass,
#if TX86
                OPsqrt,OPsin,OPcos,OPscale,OPyl2x,OPyl2xp1,
#endif
#if TARGET_SEGMENTED
                OPvp_fp,OPcvp_fp,OPoffset,OPnp_fp,OPnp_f16p,OPf16p_np,
#endif
};
int _boolnop[] = {OPuadd,OPbool,OPs16_32,OPu16_32,
                OPs16_d,
                OPf_d,OPu8_16,OPs8_16,
                OPd_ld, OPld_d,
                OPu32_64,OPs32_64,/*OP64_32,OPmsw,*/
                OPs64_128,OPu64_128,
                OPu16_d,OPb_8,
                OPnullptr,
#if TARGET_SEGMENTED
                OPnp_fp,OPvp_fp,OPcvp_fp,
#endif
                };
int _lvalue[] = {OPvar,OPind,OPcomma,OPbit,
                OPfield,OParray};

FILE *fdeb;

int main()
{
    printf("OPTABGEN... generating files\n");
    fdeb = fopen("debtab.c","w");
    dooptab();
    dotab();
    fltables();
    dotytab();
    fclose(fdeb);
    return 0;
}

int cost(unsigned op)
{       unsigned c;

        c = 0;                          /* default cost                 */
        if (xptab1[op] & _OTunary)
                c += 2;
        else if (xptab1[op] & _OTbinary)
                c += 7;
        if (xptab2[op] & _OTlogical)
                c += 3;
        switch (op)
        {   case OPvar: c += 1; break;
            case OPmul: c += 3; break;
            case OPdiv:
            case OPmod: c += 4; break;
            case OProl:
            case OPror:
            case OPshl:
            case OPashr:
            case OPshr: c += 2; break;
            case OPnewarray:
            case OPmultinewarray:
            case OPcall:
            case OPucall:
            case OPcallns:
            case OPucallns:
                                c += 10; break; // very high cost for function calls
            case OParray:       c = 5; break;
        }
        return c;
}

void dooptab()
{       int i;
        FILE *f;

        /* Load optab[] */
#define X1(arr,mask) for(i=0;i<sizeof(arr)/sizeof(int);i++)xptab1[arr[i]]|=mask;
#define X2(arr,mask) for(i=0;i<sizeof(arr)/sizeof(int);i++)xptab2[arr[i]]|=mask;
#define X3(arr,mask) for(i=0;i<sizeof(arr)/sizeof(int);i++)xptab3[arr[i]]|=mask;

        X1(_binary,_OTbinary);
        X1(_unary,_OTunary);
        X1(_commut,_OTcommut);
        X1(_assoc,_OTassoc);
        X1(_sideff,_OTsideff);
        X1(_eop0e,_OTeop0e);
        X1(_eop00,_OTeop00);
        X1(_eop1e,_OTeop1e);

        X2(_logical,_OTlogical);
        X2(_wid,_OTwid);
        X2(_call,_OTcall);
        X2(_rtol,_OTrtol);
        X2(_assign,_OTassign);
        X2(_def,_OTdef);
        X2(_ae,_OTae);
        X2(_exp,_OTexp);

        X3(_boolnop,_OTboolnop);

#undef X3
#undef X2
#undef X1

        f = fopen("optab.c","w");
        fprintf(f,"const unsigned char optab1[OPMAX] =\n\t{");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",xptab1[i]);
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t};\n");
        fprintf(f,"const unsigned char optab2[OPMAX] =\n\t{");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",xptab2[i]);
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t};\n");
        fprintf(f,"const unsigned char optab3[OPMAX] =\n\t{");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",xptab3[i]);
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t};\n");

        fprintf(f,"const unsigned char opcost[OPMAX] =\n\t{");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",cost(i));
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t};\n");

        doreltables(f);
        fclose(f);
}

/********************************************************
 */

void doreltables(FILE *f)
{
        static struct
        {   enum OPER op;       /* operator                             */
            enum OPER inot;     /* for logical negation                 */
            enum OPER swap;     /* if operands are swapped              */
            enum OPER integral; /* if operands are integral types       */
            int exception;      /* if invalid exception is generated    */
            int unord;          /* result of unordered operand(s)       */
        } reltables[] =
        { /*    op      not     swap    int     exc     unord   */
            { OPeqeq,   OPne,   OPeqeq, OPeqeq, 0,      0 },
            { OPne,     OPeqeq, OPne,   OPne,   0,      1 },
            { OPgt,     OPngt,  OPlt,   OPgt,   1,      0 },
            { OPge,     OPnge,  OPle,   OPge,   1,      0 },
            { OPlt,     OPnlt,  OPgt,   OPlt,   1,      0 },
            { OPle,     OPnle,  OPge,   OPle,   1,      0 },

            { OPunord, OPord,   OPunord, (enum OPER)0,0,1 },
            { OPlg,     OPnlg,  OPlg,   OPne,   1,      0 },
            { OPleg,    OPnleg, OPleg,  (enum OPER)1,1, 0 },
            { OPule,    OPnule, OPuge,  OPle,   0,      1 },
            { OPul,     OPnul,  OPug,   OPlt,   0,      1 },
            { OPuge,    OPnuge, OPule,  OPge,   0,      1 },
            { OPug,     OPnug,  OPul,   OPgt,   0,      1 },
            { OPue,     OPnue,  OPue,   OPeqeq, 0,      1 },

            { OPngt,    OPgt,   OPnlt,  OPle,   1,      1 },
            { OPnge,    OPge,   OPnle,  OPlt,   1,      1 },
            { OPnlt,    OPlt,   OPngt,  OPge,   1,      1 },
            { OPnle,    OPle,   OPnge,  OPgt,   1,      1 },
            { OPord,    OPunord, OPord, (enum OPER)1,0, 0 },
            { OPnlg,    OPlg,   OPnlg,  OPeqeq, 1,      1 },
            { OPnleg,   OPleg,  OPnleg, (enum OPER)0,1, 1 },
            { OPnule,   OPule,  OPnuge, OPgt,   0,      0 },
            { OPnul,    OPul,   OPnug,  OPge,   0,      0 },
            { OPnuge,   OPuge,  OPnule, OPlt,   0,      0 },
            { OPnug,    OPug,   OPnul,  OPle,   0,      0 },
            { OPnue,    OPue,   OPnue,  OPne,   0,      0 },
        };
#define RELMAX arraysize(reltables)
        enum OPER rel_not[RELMAX];
        enum OPER rel_swap[RELMAX];
        enum OPER rel_integral[RELMAX];
        int rel_exception[RELMAX];
        int rel_unord[RELMAX];
        int i;

        for (i = 0; i < RELMAX; i++)
        {   int j = (int)(reltables[i].op) - RELOPMIN;

            assert(j >= 0 && j < RELMAX);
            rel_not      [j] = reltables[i].inot;
            rel_swap     [j] = reltables[i].swap;
            rel_integral [j] = reltables[i].integral;
            rel_exception[j] = reltables[i].exception;
            rel_unord    [j] = reltables[i].unord;
        }

    fprintf(f,"unsigned char rel_not[] =\n{ ");
    for (i = 0; i < arraysize(rel_not); i++)
    {   fprintf(f,"0x%02x,",rel_not[i]);
        if ((i & 7) == 7 && i < arraysize(rel_not) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    fprintf(f,"unsigned char rel_swap[] =\n{ ");
    for (i = 0; i < arraysize(rel_swap); i++)
    {   fprintf(f,"0x%02x,",rel_swap[i]);
        if ((i & 7) == 7 && i < arraysize(rel_swap) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    fprintf(f,"unsigned char rel_integral[] =\n{ ");
    for (i = 0; i < arraysize(rel_integral); i++)
    {   fprintf(f,"0x%02x,",rel_integral[i]);
        if ((i & 7) == 7 && i < arraysize(rel_integral) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    fprintf(f,"unsigned char rel_exception[] =\n{ ");
    for (i = 0; i < arraysize(rel_exception); i++)
    {   fprintf(f,"0x%02x,",rel_exception[i]);
        if ((i & 7) == 7 && i < arraysize(rel_exception) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    fprintf(f,"unsigned char rel_unord[] =\n{ ");
    for (i = 0; i < arraysize(rel_unord); i++)
    {   fprintf(f,"0x%02x,",rel_unord[i]);
        if ((i & 7) == 7 && i < arraysize(rel_unord) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");
}


/********************************************************
 */

const char *debtab[OPMAX],*cdxxx[OPMAX],*elxxx[OPMAX];

void dotab()
{ int i;
  FILE *f;

#if BSDUNIX
#define X(d,e,c) debtab[i]=d;cdxxx[i]="c",elxxx[i]="e";break
#else
#define X(d,e,c) debtab[i]=d;cdxxx[i]=#c,elxxx[i]=#e;break
#endif
  for (i = 0; i < OPMAX; i++)
  {
    switch (i)
    {
        case OPunde:    X("unde",       elerr,  cderr);
        case OPadd:     X("+",          eladd,  cdorth);
        case OPmul:     X("*",          elmul,  cdmul);
        case OPand:     X("&",          elbitwise,cdorth);
        case OPmin:     X("-",          elmin,  cdorth);
        case OPnot:     X("!",          elnot,  cdnot);
        case OPcom:     X("~",          elcom,  cdcom);
        case OPcond:    X("?",          elcond, cdcond);
        case OPcomma:   X(",",          elcomma,cdcomma);
        case OPremquo:  X("/%",         elremquo, cdmul);
        case OPdiv:     X("/",          eldiv,  cdmul);
        case OPmod:     X("%",          elmod,  cdmul);
        case OPxor:     X("^",          elxor,  cdorth);
        case OPstring:  X("string",     elstring,cderr);
        case OPrelconst: X("relconst",  elzot, cdrelconst);
#if TX86
        case OPinp:     X("inp",        elzot, cdport);
        case OPoutp:    X("outp",       elzot, cdport);
#endif
        case OPasm:     X("asm",        elzot, cdasm);
        case OPinfo:    X("info",       elinfo,cdinfo);
        case OPdctor:   X("dctor",      elzot, cddctor);
        case OPddtor:   X("ddtor",      elddtor, cdddtor);
        case OPctor:    X("ctor",       elinfo,cdctor);
        case OPdtor:    X("dtor",       elinfo,cddtor);
        case OPmark:    X("mark",       elinfo,cdmark);
        case OPvoid:    X("void",       elzot, cdvoid);
        case OPhalt:    X("halt",       elzot, cdhalt);
        case OPnullptr: X("nullptr",    elerr, cderr);
        case OPpair:    X("pair",       elpair, cdpair);
        case OPrpair:   X("rpair",      elpair, cdpair);

        case OPnewarray: X("newarray",  elnewarray,cderr);
        case OPmultinewarray: X("mnewarray",    elmultinewarray,cderr);
        case OPinstanceof: X("instanceof",      elinstanceof,cderr);
        case OPfinalinstanceof: X("finalinstanceof",    elfinalinstanceof,cderr);
        case OPcheckcast: X("checkcast",        elcheckcast,cderr);
        case OParraylength: X("length", elarraylength,cderr);
        case OParray:   X("array",      elarray,cderr);
        case OPfield:   X("field",      elfield,cderr);
        case OPhstring: X("hstring",    elhstring,cderr);
        case OPnullcheck: X("nullcheck", elnullcheck,cdnullcheck);

        case OPor:      X("|",          elor,   cdorth);
        case OPoror:    X("||",         eloror, cdloglog);
        case OPandand:  X("&&",         elandand,cdloglog);
        case OProl:     X("<<|",        elshl,  cdshift);
        case OPror:     X(">>|",        elshl,  cdshift);
        case OPshl:     X("<<",         elshl,  cdshift);
        case OPshr:     X(">>>",        elshr,  cdshift);
        case OPashr:    X(">>",         elshr,  cdshift);
        case OPbit:     X("bit",        elbit,  cderr);
        case OPind:     X("*",          elind,  cdind);
        case OPaddr:    X("&",          eladdr, cderr);
        case OPneg:     X("-",          elneg,  cdneg);
        case OPuadd:    X("+",          elzot,  cderr);
        case OPabs:     X("abs",        evalu8, cdabs);
#if TX86
        case OPsqrt:    X("sqrt",       evalu8, cdneg);
        case OPsin:     X("sin",        evalu8, cdneg);
        case OPcos:     X("cos",        evalu8, cdneg);
        case OPscale:   X("scale",      elzot,  cdscale);
        case OPyl2x:    X("yl2x",       elzot,  cdscale);
        case OPyl2xp1:  X("yl2xp1",     elzot,  cdscale);
#endif
        case OPrint:    X("rint",       evalu8, cdneg);
        case OPrndtol:  X("rndtol",     evalu8, cdrndtol);
        case OPstrlen:  X("strlen",     elzot,  cdstrlen);
        case OPstrcpy:  X("strcpy",     elstrcpy,cdstrcpy);
        case OPmemcpy:  X("memcpy",     elmemxxx,cdmemcpy);
        case OPmemset:  X("memset",     elmemxxx,cdmemset);
        case OPstrcat:  X("strcat",     elzot,  cderr);
        case OPstrcmp:  X("strcmp",     elstrcmp,cdstrcmp);
        case OPmemcmp:  X("memcmp",     elmemxxx,cdmemcmp);
        case OPsetjmp:  X("setjmp",     elzot,  cdsetjmp);
        case OPnegass:  X("negass",     elnegass, cdaddass);
        case OPpreinc:  X("U++",        elzot,  cderr);
        case OPpredec:  X("U--",        elzot,  cderr);
        case OPstreq:   X("streq",      elstruct,cdstreq);
        case OPpostinc: X("++",         elpost, cdpost);
        case OPpostdec: X("--",         elpost, cdpost);
        case OPeq:      X("=",          eleq,   cdeq);
        case OPaddass:  X("+=",         elopass,cdaddass);
        case OPminass:  X("-=",         elopass,cdaddass);
        case OPmulass:  X("*=",         elopass,cdmulass);
        case OPdivass:  X("/=",         elopass,cdmulass);
        case OPmodass:  X("%=",         elopass,cdmulass);
        case OPshrass:  X(">>>=",       elopass,cdshass);
        case OPashrass: X(">>=",        elopass,cdshass);
        case OPshlass:  X("<<=",        elopass,cdshass);
        case OPandass:  X("&=",         elopass,cdaddass);
        case OPxorass:  X("^=",         elopass,cdaddass);
        case OPorass:   X("|=",         elopass,cdaddass);

        case OPle:      X("<=",         elcmp,  cdcmp);
        case OPgt:      X(">",          elcmp,  cdcmp);
        case OPlt:      X("<",          elcmp,  cdcmp);
        case OPge:      X(">=",         elcmp,  cdcmp);
        case OPeqeq:    X("==",         elcmp,  cdcmp);
        case OPne:      X("!=",         elcmp,  cdcmp);

        case OPunord:   X("!<>=",       elcmp,  cdcmp);
        case OPlg:      X("<>",         elcmp,  cdcmp);
        case OPleg:     X("<>=",        elcmp,  cdcmp);
        case OPule:     X("!>",         elcmp,  cdcmp);
        case OPul:      X("!>=",        elcmp,  cdcmp);
        case OPuge:     X("!<",         elcmp,  cdcmp);
        case OPug:      X("!<=",        elcmp,  cdcmp);
        case OPue:      X("!<>",        elcmp,  cdcmp);
        case OPngt:     X("~>",         elcmp,  cdcmp);
        case OPnge:     X("~>=",        elcmp,  cdcmp);
        case OPnlt:     X("~<",         elcmp,  cdcmp);
        case OPnle:     X("~<=",        elcmp,  cdcmp);
        case OPord:     X("~!<>=",      elcmp,  cdcmp);
        case OPnlg:     X("~<>",        elcmp,  cdcmp);
        case OPnleg:    X("~<>=",       elcmp,  cdcmp);
        case OPnule:    X("~!>",        elcmp,  cdcmp);
        case OPnul:     X("~!>=",       elcmp,  cdcmp);
        case OPnuge:    X("~!<",        elcmp,  cdcmp);
        case OPnug:     X("~!<=",       elcmp,  cdcmp);
        case OPnue:     X("~!<>",       elcmp,  cdcmp);

#if TARGET_SEGMENTED
        case OPvp_fp:   X("vptrfptr",   elvptrfptr,cdcnvt);
        case OPcvp_fp:  X("cvptrfptr",  elvptrfptr,cdcnvt);
        case OPoffset:  X("offset",     ellngsht,cdlngsht);
        case OPnp_fp:   X("ptrlptr",    elptrlptr,cdshtlng);
        case OPnp_f16p: X("tofar16",    elzot,  cdfar16);
        case OPf16p_np: X("fromfar16",  elzot,  cdfar16);
#endif
        case OPs16_32:  X("s16_32",     evalu8, cdshtlng);
        case OPu16_32:  X("u16_32",     evalu8, cdshtlng);
        case OPd_s32:   X("d_s32",      evalu8, cdcnvt);
        case OPb_8:     X("b_8",        evalu8, cdcnvt);
        case OPs32_d:   X("s32_d",      evalu8, cdcnvt);
        case OPd_s16:   X("d_s16",      evalu8, cdcnvt);
        case OPs16_d:   X("s16_d",      evalu8, cdcnvt);
        case OPd_u16:   X("d_u16",      evalu8, cdcnvt);
        case OPu16_d:   X("u16_d",      evalu8, cdcnvt);
        case OPd_u32:   X("d_u32",      evalu8, cdcnvt);
        case OPu32_d:   X("u32_d",      evalu8, cdcnvt);
        case OP32_16:   X("32_16",      ellngsht,cdlngsht);
        case OPd_f:     X("d_f",        evalu8, cdcnvt);
        case OPf_d:     X("f_d",        evalu8, cdcnvt);
        case OPd_ld:    X("d_ld",       evalu8, cdcnvt);
        case OPld_d:    X("ld_d",       evalu8, cdcnvt);
        case OPc_r:     X("c_r",        elc_r,  cdconvt87);
        case OPc_i:     X("c_i",        elc_i,  cdconvt87);
        case OPu8_16:   X("u8_16",      elbyteint, cdbyteint);
        case OPs8_16:   X("s8_16",      elbyteint, cdbyteint);
        case OP16_8:    X("16_8",       ellngsht,cdlngsht);
        case OPu32_64:  X("u32_64",     el32_64, cdshtlng);
        case OPs32_64:  X("s32_64",     el32_64, cdshtlng);
        case OP64_32:   X("64_32",      el64_32, cdlngsht);
        case OPu64_128: X("u64_128",    evalu8, cdshtlng);
        case OPs64_128: X("s64_128",    evalu8, cdshtlng);
        case OP128_64:  X("128_64",     el64_32, cdlngsht);
        case OPmsw:     X("msw",        elmsw, cdmsw);

        case OPd_s64:   X("d_s64",      evalu8, cdcnvt);
        case OPs64_d:   X("s64_d",      evalu8, cdcnvt);
        case OPd_u64:   X("d_u64",      evalu8, cdcnvt);
        case OPu64_d:   X("u64_d",      elu64_d, cdcnvt);
        case OPld_u64:  X("ld_u64",     evalu8, cdcnvt);
        case OPparam:   X("param",      elparam, cderr);
        case OPsizeof:  X("sizeof",     elzot,  cderr);
        case OParrow:   X("->",         elzot,  cderr);
        case OParrowstar: X("->*",      elzot,  cderr);
        case OPcolon:   X("colon",      elzot,  cderr);
        case OPcolon2:  X("colon2",     elzot,  cderr);
        case OPbool:    X("bool",       elbool, cdnot);
        case OPcall:    X("call",       elcall, cdfunc);
        case OPucall:   X("ucall",      elcall, cdfunc);
        case OPcallns:  X("callns",     elcall, cdfunc);
        case OPucallns: X("ucallns",    elcall, cdfunc);
        case OPstrpar:  X("strpar",     elstruct, cderr);
        case OPstrctor: X("strctor",    elzot,  cderr);
        case OPstrthis: X("strthis",    elzot,  cdstrthis);
        case OPconst:   X("const",      elerr,  cderr);
        case OPvar:     X("var",        elerr,  loaddata);
        case OPreg:     X("reg",        elerr,  cderr);
        case OPnew:     X("new",        elerr,  cderr);
        case OPanew:    X("new[]",      elerr,  cderr);
        case OPdelete:  X("delete",     elerr,  cderr);
        case OPadelete: X("delete[]",   elerr,  cderr);
        case OPbrack:   X("brack",      elerr,  cderr);
        case OPframeptr: X("frameptr",  elzot,  cdframeptr);
        case OPgot:     X("got",        elzot,  cdgot);

        case OPbsf:     X("bsf",        elzot,  cdbscan);
        case OPbsr:     X("bsr",        elzot,  cdbscan);
        case OPbtst:    X("btst",       elzot,  cdbtst);
        case OPbt:      X("bt",         elzot,  cdbt);
        case OPbtc:     X("btc",        elzot,  cdbt);
        case OPbtr:     X("btr",        elzot,  cdbt);
        case OPbts:     X("bts",        elzot,  cdbt);

        case OPbswap:   X("bswap",      evalu8, cdbswap);
        case OPpopcnt:  X("popcnt",     evalu8, cdpopcnt);
        case OPvector:  X("vector",     elzot,  cdvector);
        case OPvecsto:  X("vecsto",     elzot,  cdvecsto);

#if TX86 && MARS
        case OPva_start: X("va_start",  elvalist, cderr);
#endif

        default:
                printf("opcode hole x%x\n",i);
                exit(EXIT_FAILURE);
#undef X
    }
  }

  fprintf(fdeb,"static const char *debtab[OPMAX] = \n\t{\n");
  for (i = 0; i < OPMAX - 1; i++)
        fprintf(fdeb,"\t\"%s\",\n",debtab[i]);
  fprintf(fdeb,"\t\"%s\"\n\t};\n",debtab[i]);

  f = fopen("cdxxx.c","w");
  fprintf(f,"code *(*cdxxx[OPMAX]) (elem *,regm_t *) = \n\t{\n");
  for (i = 0; i < OPMAX - 1; i++)
        fprintf(f,"\t%s,\n",cdxxx[i]);
  fprintf(f,"\t%s\n\t};\n",cdxxx[i]);
  fclose(f);

  f = fopen("elxxx.c","w");
  fprintf(f,"static elem *(*elxxx[OPMAX]) (elem *, goal_t) = \n\t{\n");
  for (i = 0; i < OPMAX - 1; i++)
        fprintf(f,"\t%s,\n",elxxx[i]);
  fprintf(f,"\t%s\n\t};\n",elxxx[i]);
  fclose(f);
}

void fltables()
{       FILE *f;
        int i;
        char segfl[FLMAX];
        char datafl[FLMAX];
        char stackfl[FLMAX];
        char flinsymtab[FLMAX];

        static char indatafl[] =        /* is FLxxxx a data type?       */
        { FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,
          FLcs,FLfltreg,FLallocatmp,FLdatseg,FLtlsdata,FLbprel,
          FLstack,FLregsave,
#if TX86
          FLndp,
#endif
        };
#if TARGET_SEGMENTED
        static char indatafl_s[] = { FLfardata, };
#endif

        static char instackfl[] =       /* is FLxxxx a stack data type? */
        { FLauto,FLfast,FLpara,FLcs,FLfltreg,FLallocatmp,FLbprel,FLstack,FLregsave,
#if TX86
          FLndp,
#endif
        };

        static char inflinsymtab[] =    /* is FLxxxx in the symbol table? */
        { FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,FLfunc,
          FLtlsdata,FLbprel,FLstack };
#if TARGET_SEGMENTED
        static char inflinsymtab_s[] = { FLfardata,FLcsdata, };
#endif

        for (i = 0; i < FLMAX; i++)
                datafl[i] = stackfl[i] = flinsymtab[i] = 0;

        for (i = 0; i < sizeof(indatafl); i++)
                datafl[indatafl[i]] = 1;

        for (i = 0; i < sizeof(instackfl); i++)
                stackfl[instackfl[i]] = 1;

        for (i = 0; i < sizeof(inflinsymtab); i++)
                flinsymtab[inflinsymtab[i]] = 1;

#if TARGET_SEGMENTED
        for (i = 0; i < sizeof(indatafl_s); i++)
                datafl[indatafl_s[i]] = 1;

        for (i = 0; i < sizeof(inflinsymtab_s); i++)
                flinsymtab[inflinsymtab_s[i]] = 1;
#endif

/* Segment registers    */
/* The #undefs are to appease the compiler on Solaris because
   it, for some reason, ends up including regset.h in standard
   C/POSIX headers, polluting the global namespace */
#ifdef ES
#undef ES
#endif
#define ES      0

#ifdef CS
#undef CS
#endif
#define CS      1

#ifdef SS
#undef SS
#endif
#define SS      2

#ifdef DS
#undef DS
#endif
#define DS      3

        for (i = 0; i < FLMAX; i++)
        {   switch (i)
            {
                case 0:         segfl[i] = -1;  break;
                case FLconst:   segfl[i] = -1;  break;
                case FLoper:    segfl[i] = -1;  break;
                case FLfunc:    segfl[i] = CS;  break;
                case FLdata:    segfl[i] = DS;  break;
                case FLudata:   segfl[i] = DS;  break;
                case FLreg:     segfl[i] = -1;  break;
                case FLpseudo:  segfl[i] = -1;  break;
                case FLauto:    segfl[i] = SS;  break;
                case FLfast:    segfl[i] = SS;  break;
                case FLstack:   segfl[i] = SS;  break;
                case FLbprel:   segfl[i] = SS;  break;
                case FLpara:    segfl[i] = SS;  break;
                case FLextern:  segfl[i] = DS;  break;
                case FLcode:    segfl[i] = CS;  break;
                case FLblock:   segfl[i] = CS;  break;
                case FLblockoff: segfl[i] = CS; break;
                case FLcs:      segfl[i] = SS;  break;
                case FLregsave: segfl[i] = SS;  break;
                case FLndp:     segfl[i] = SS;  break;
                case FLswitch:  segfl[i] = -1;  break;
                case FLfltreg:  segfl[i] = SS;  break;
                case FLoffset:  segfl[i] = -1;  break;
                case FLfardata: segfl[i] = -1;  break;
                case FLcsdata:  segfl[i] = CS;  break;
                case FLdatseg:  segfl[i] = DS;  break;
                case FLctor:    segfl[i] = -1;  break;
                case FLdtor:    segfl[i] = -1;  break;
                case FLdsymbol: segfl[i] = -1;  break;
                case FLgot:     segfl[i] = -1;  break;
                case FLgotoff:  segfl[i] = -1;  break;
                case FLlocalsize: segfl[i] = -1;        break;
                case FLtlsdata: segfl[i] = -1;  break;
                case FLframehandler:    segfl[i] = -1;  break;
                case FLasm:     segfl[i] = -1;  break;
                case FLallocatmp:       segfl[i] = SS;  break;
                default:
                        printf("error in segfl[%d]\n", i);
                        exit(1);
            }
        }

        f = fopen("fltables.c","w");

        fprintf(f,"const char datafl[FLMAX] = \n\t{ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"%d,",datafl[i]);
        fprintf(f,"%d };\n",datafl[i]);

        fprintf(f,"const char stackfl[FLMAX] = \n\t{ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"%d,",stackfl[i]);
        fprintf(f,"%d };\n",stackfl[i]);

        fprintf(f,"const char segfl[FLMAX] = \n\t{ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"%d,",segfl[i]);
        fprintf(f,"%d };\n",segfl[i]);

        fprintf(f,"const char flinsymtab[FLMAX] = \n\t{ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"%d,",flinsymtab[i]);
        fprintf(f,"%d };\n",flinsymtab[i]);

        fclose(f);
}

void dotytab()
{
    static tym_t _ptr[]      = { TYjhandle,TYnptr };
#if TARGET_SEGMENTED
    static tym_t _ptr_nflat[]= { TYsptr,TYcptr,TYf16ptr,TYfptr,TYhptr,TYvptr };
#endif
    static tym_t _real[]     = { TYfloat,TYdouble,TYdouble_alias,TYldouble,
                                 TYfloat4,TYdouble2,
                               };
    static tym_t _imaginary[] = {
                                 TYifloat,TYidouble,TYildouble,
                               };
    static tym_t _complex[] =  {
                                 TYcfloat,TYcdouble,TYcldouble,
                               };
    static tym_t _integral[] = { TYbool,TYchar,TYschar,TYuchar,TYshort,
                                 TYwchar_t,TYushort,TYenum,TYint,TYuint,
                                 TYlong,TYulong,TYllong,TYullong,TYdchar,
                                 TYschar16,TYuchar16,TYshort8,TYushort8,
                                 TYlong4,TYulong4,TYllong2,TYullong2,
                                 TYchar16, TYcent, TYucent };
    static tym_t _ref[]      = { TYnref,TYref };
    static tym_t _func[]     = { TYnfunc,TYnpfunc,TYnsfunc,TYifunc,TYmfunc,TYjfunc,TYhfunc };
#if TARGET_SEGMENTED
    static tym_t _ref_nflat[] = { TYfref };
    static tym_t _func_nflat[]= { TYffunc,TYfpfunc,TYf16func,TYfsfunc,TYnsysfunc,TYfsysfunc, };
#endif
    static tym_t _uns[]     = { TYuchar,TYushort,TYuint,TYulong,
#if MARS
                                TYwchar_t,
#endif
                                TYuchar16,TYushort8,TYulong4,TYullong2,
                                TYdchar,TYullong,TYucent,TYchar16 };
#if !MARS
    static tym_t _mptr[]    = { TYmemptr };
#endif
    static tym_t _nullptr[] = { TYnullptr };
#if TARGET_SEGMENTED
    static tym_t _fv[]      = { TYfptr, TYvptr };
#if TARGET_WINDOS
    static tym_t _farfunc[] = { TYffunc,TYfpfunc,TYfsfunc,TYfsysfunc };
#endif
#endif
    static tym_t _pasfunc[] = { TYnpfunc,TYnsfunc,TYmfunc,TYjfunc };
#if TARGET_SEGMENTED
    static tym_t _pasfunc_nf[] = { TYfpfunc,TYf16func,TYfsfunc, };
#endif
    static tym_t _revfunc[] = { TYnpfunc,TYjfunc };
#if TARGET_SEGMENTED
    static tym_t _revfunc_nf[] = { TYfpfunc,TYf16func, };
#endif
    static tym_t _short[]     = { TYbool,TYchar,TYschar,TYuchar,TYshort,
                                  TYwchar_t,TYushort,TYchar16 };
    static tym_t _aggregate[] = { TYstruct,TYarray };
#if TX86
    static tym_t _xmmreg[] = {
                                 TYfloat,TYdouble,TYifloat,TYidouble,
                                 TYfloat4,TYdouble2,
                                 TYschar16,TYuchar16,TYshort8,TYushort8,
                                 TYlong4,TYulong4,TYllong2,TYullong2,
                             };
#endif
    static tym_t _simd[] = {
                                 TYfloat4,TYdouble2,
                                 TYschar16,TYuchar16,TYshort8,TYushort8,
                                 TYlong4,TYulong4,TYllong2,TYullong2,
                             };

    static struct
    {
        const char *string;     /* name of type                 */
        tym_t ty;       /* TYxxxx                       */
        tym_t unsty;    /* conversion to unsigned type  */
        tym_t relty;    /* type for relaxed type checking */
        int size;
        int debtyp;     /* Codeview 1 type in debugger record   */
        int debtyp4;    /* Codeview 4 type in debugger record   */
    } typetab[] =
    {
/* Note that chars are signed, here     */
"bool",         TYbool,         TYbool,    TYchar,      1,      0x80,   0x30,
"char",         TYchar,         TYuchar,   TYchar,      1,      0x80,   0x70,
"signed char",  TYschar,        TYuchar,   TYchar,      1,      0x80,   0x10,
"unsigned char",TYuchar,        TYuchar,   TYchar,      1,      0x84,   0x20,
"char16_t",     TYchar16,       TYchar16,  TYint,       2,      0x85,   0x21,
"short",        TYshort,        TYushort,  TYint,       SHORTSIZE, 0x81,0x11,
"wchar_t",      TYwchar_t,      TYwchar_t, TYint,       SHORTSIZE, 0x85,0x71,
"unsigned short",TYushort,      TYushort,  TYint,       SHORTSIZE, 0x85,0x21,

// These values are adjusted for 32 bit ints in cv_init() and util_set32()
"enum",         TYenum,         TYuint,    TYint,       -1,        0x81,0x72,
"int",          TYint,          TYuint,    TYint,       2,         0x81,0x72,
"unsigned",     TYuint,         TYuint,    TYint,       2,         0x85,0x73,

"long",         TYlong,         TYulong,   TYlong,      LONGSIZE,  0x82,0x12,
"unsigned long",TYulong,        TYulong,   TYlong,      LONGSIZE,  0x86,0x22,
"dchar",        TYdchar,        TYdchar,   TYlong,      4,         0x86,0x22,
"long long",    TYllong,        TYullong,  TYllong,     LLONGSIZE, 0x82,0x13,
"uns long long",TYullong,       TYullong,  TYllong,     LLONGSIZE, 0x86,0x23,
"cent",         TYcent,         TYucent,   TYcent,      16,        0x82,0x603,
"ucent",        TYucent,        TYucent,   TYcent,      16,        0x86,0x603,
"float",        TYfloat,        TYfloat,   TYfloat,     FLOATSIZE, 0x88,0x40,
"double",       TYdouble,       TYdouble,  TYdouble,    DOUBLESIZE,0x89,0x41,
"double alias", TYdouble_alias, TYdouble_alias,  TYdouble_alias,8, 0x89,0x41,
"long double",  TYldouble,      TYldouble,  TYldouble,  LNGDBLSIZE, 0x89,0x42,

"imaginary float",      TYifloat,       TYifloat,   TYifloat,   FLOATSIZE, 0x88,0x40,
"imaginary double",     TYidouble,      TYidouble,  TYidouble,  DOUBLESIZE,0x89,0x41,
"imaginary long double",TYildouble,     TYildouble, TYildouble, LNGDBLSIZE,0x89,0x42,

"complex float",        TYcfloat,       TYcfloat,   TYcfloat,   2*FLOATSIZE, 0x88,0x50,
"complex double",       TYcdouble,      TYcdouble,  TYcdouble,  2*DOUBLESIZE,0x89,0x51,
"complex long double",  TYcldouble,     TYcldouble, TYcldouble, 2*LNGDBLSIZE,0x89,0x52,

"float[4]",              TYfloat4,    TYfloat4,  TYfloat4,    16,     0,      0,
"double[2]",             TYdouble2,   TYdouble2, TYdouble2,   16,     0,      0,
"signed char[16]",       TYschar16,   TYuchar16, TYschar16,   16,     0,      0,
"unsigned char[16]",     TYuchar16,   TYuchar16, TYuchar16,   16,     0,      0,
"short[8]",              TYshort8,    TYushort8, TYshort8,    16,     0,      0,
"unsigned short[8]",     TYushort8,   TYushort8, TYushort8,   16,     0,      0,
"long[4]",               TYlong4,     TYulong4,  TYlong4,     16,     0,      0,
"unsigned long[4]",      TYulong4,    TYulong4,  TYulong4,    16,     0,      0,
"long long[2]",          TYllong2,    TYullong2, TYllong2,    16,     0,      0,
"unsigned long long[2]", TYullong2,   TYullong2, TYullong2,   16,     0,      0,

"__near *",     TYjhandle,      TYjhandle, TYjhandle,   2,  0x20,       0x100,
"nullptr_t",    TYnullptr,      TYnullptr, TYptr,       2,  0x20,       0x100,
"*",            TYnptr,         TYnptr,    TYnptr,      2,  0x20,       0x100,
"&",            TYref,          TYref,     TYref,       -1,     0,      0,
"void",         TYvoid,         TYvoid,    TYvoid,      -1,     0x85,   3,
"struct",       TYstruct,       TYstruct,  TYstruct,    -1,     0,      0,
"array",        TYarray,        TYarray,   TYarray,     -1,     0x78,   0,
"C func",       TYnfunc,        TYnfunc,   TYnfunc,     -1,     0x63,   0,
"Pascal func",  TYnpfunc,       TYnpfunc,  TYnpfunc,    -1,     0x74,   0,
"std func",     TYnsfunc,       TYnsfunc,  TYnsfunc,    -1,     0x63,   0,
"*",            TYptr,          TYptr,     TYptr,       2,  0x20,       0x100,
"member func",  TYmfunc,        TYmfunc,   TYmfunc,     -1,     0x64,   0,
"D func",       TYjfunc,        TYjfunc,   TYjfunc,     -1,     0x74,   0,
"C func",       TYhfunc,        TYhfunc,   TYhfunc,     -1,     0,      0,
"__near &",     TYnref,         TYnref,    TYnref,      2,      0,      0,

#if TARGET_SEGMENTED
"__ss *",       TYsptr,         TYsptr,    TYsptr,      2,  0x20,       0x100,
"__cs *",       TYcptr,         TYcptr,    TYcptr,      2,  0x20,       0x100,
"__far16 *",    TYf16ptr,       TYf16ptr,  TYf16ptr,    4,  0x40,       0x200,
"__far *",      TYfptr,         TYfptr,    TYfptr,      4,  0x40,       0x200,
"__huge *",     TYhptr,         TYhptr,    TYhptr,      4,  0x40,       0x300,
"__handle *",   TYvptr,         TYvptr,    TYvptr,      4,  0x40,       0x200,
"far C func",   TYffunc,        TYffunc,   TYffunc,     -1,     0x64,   0,
"far Pascal func", TYfpfunc,    TYfpfunc,  TYfpfunc,    -1,     0x73,   0,
"far std func", TYfsfunc,       TYfsfunc,  TYfsfunc,    -1,     0x64,   0,
"_far16 Pascal func", TYf16func, TYf16func, TYf16func,  -1,     0x63,   0,
"sys func",     TYnsysfunc,     TYnsysfunc,TYnsysfunc,  -1,     0x63,   0,
"far sys func", TYfsysfunc,     TYfsysfunc,TYfsysfunc,  -1,     0x64,   0,
"__far &",      TYfref,         TYfref,    TYfref,      4,      0,      0,
#endif
#if !MARS
"interrupt func", TYifunc,      TYifunc,   TYifunc,     -1,     0x64,   0,
"memptr",       TYmemptr,       TYmemptr,  TYmemptr,    -1,     0,      0,
"ident",        TYident,        TYident,   TYident,     -1,     0,      0,
"template",     TYtemplate,     TYtemplate, TYtemplate, -1,     0,      0,
"vtshape",      TYvtshape,      TYvtshape,  TYvtshape,  -1,     0,      0,
#endif
    };

    FILE *f;
    static unsigned tytab[64 * 4];
    static tym_t tytouns[64 * 4];
    static tym_t _tyrelax[TYMAX];
    static tym_t _tyequiv[TYMAX];
    static signed char tysize[64 * 4];
    static const char *tystring[TYMAX];
    static unsigned char dttab[TYMAX];
    static unsigned short dttab4[TYMAX];
    int i;

#define T1(arr,mask) for (i=0; i<arraysize(arr); i++) \
                     {  tytab[arr[i]] |= mask; \
                     };
#define T2(arr,mask) for (i=0; i<arraysize(arr); i++) \
                     {  tytab[arr[i]] |= mask; \
                     };

    T1(_ptr,      TYFLptr);
#if TARGET_SEGMENTED
    T1(_ptr_nflat,TYFLptr);
#endif
    T1(_real,     TYFLreal);
    T1(_integral, TYFLintegral);
    T1(_imaginary,TYFLimaginary);
    T1(_complex,  TYFLcomplex);
    T1(_uns,      TYFLuns);
#if !MARS
    T1(_mptr,     TYFLmptr);
#endif

#if TARGET_SEGMENTED
    T1(_fv,       TYFLfv);
    T2(_farfunc,  TYFLfarfunc);
#endif
    T2(_pasfunc,  TYFLpascal);
    T2(_revfunc,  TYFLrevparam);
    T2(_short,    TYFLshort);
    T2(_aggregate,TYFLaggregate);
    T2(_ref,      TYFLref);
    T2(_func,     TYFLfunc);
    T2(_nullptr,  TYFLnullptr);
#if TARGET_SEGMENTED
    T2(_pasfunc_nf, TYFLpascal);
    T2(_revfunc_nf, TYFLrevparam);
    T2(_ref_nflat,  TYFLref);
    T2(_func_nflat, TYFLfunc);
#endif
#if TX86
    T1(_xmmreg,    TYFLxmmreg);
#endif
    T1(_simd,      TYFLsimd);
#undef T1
#undef T2

    f = fopen("tytab.c","w");

    fprintf(f,"unsigned tytab[] =\n{ ");
    for (i = 0; i < arraysize(tytab); i++)
    {   fprintf(f,"0x%02x,",tytab[i]);
        if ((i & 7) == 7 && i < arraysize(tytab) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

#if 0
    fprintf(f,"unsigned char tytab2[] =\n{ ");
    for (i = 0; i < arraysize(tytab2); i++)
    {   fprintf(f,"0x%02x,",tytab2[i]);
        if ((i & 7) == 7 && i < arraysize(tytab2) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");
#endif

    for (i = 0; i < arraysize(typetab); i++)
    {   tytouns[typetab[i].ty] = typetab[i].unsty;
    }
    fprintf(f,"const tym_t tytouns[] =\n{ ");
    for (i = 0; i < arraysize(tytouns); i++)
    {   fprintf(f,"0x%02x,",tytouns[i]);
        if ((i & 7) == 7 && i < arraysize(tytouns) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    for (i = 0; i < arraysize(typetab); i++)
    {   tysize[typetab[i].ty | 0x00] = typetab[i].size;
        /*printf("tysize[%d] = %d\n",typetab[i].ty,typetab[i].size);*/
    }
    fprintf(f,"signed char tysize[] =\n{ ");
    for (i = 0; i < arraysize(tysize); i++)
    {   fprintf(f,"%d,",tysize[i]);
        if ((i & 7) == 7 && i < arraysize(tysize) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    for (i = 0; i < arraysize(tysize); i++)
        tysize[i] = 0;
    for (i = 0; i < arraysize(typetab); i++)
    {   signed char sz = typetab[i].size;
        switch (typetab[i].ty)
        {
            case TYldouble:
            case TYildouble:
            case TYcldouble:
#if TARGET_OSX
                sz = 16;
#elif TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
                sz = 4;
#elif TARGET_WINDOS
                sz = 2;
#else
#error "fix this"
#endif
                break;

            case TYcent:
            case TYucent:
                sz = 8;
                break;
        }
        tysize[typetab[i].ty | 0x00] = sz;
        /*printf("tyalignsize[%d] = %d\n",typetab[i].ty,typetab[i].size);*/
    }
    fprintf(f,"signed char tyalignsize[] =\n{ ");
    for (i = 0; i < arraysize(tysize); i++)
    {   fprintf(f,"%d,",tysize[i]);
        if ((i & 7) == 7 && i < arraysize(tysize) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    for (i = 0; i < arraysize(typetab); i++)
    {   _tyrelax[typetab[i].ty] = typetab[i].relty;
        /*printf("_tyrelax[%d] = %d\n",typetab[i].ty,typetab[i].relty);*/
    }
    fprintf(f,"unsigned char _tyrelax[] =\n{ ");
    for (i = 0; i < arraysize(_tyrelax); i++)
    {   fprintf(f,"0x%02x,",_tyrelax[i]);
        if ((i & 7) == 7 && i < arraysize(_tyrelax) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    /********** tyequiv[] ************/
    for (i = 0; i < arraysize(_tyequiv); i++)
        _tyequiv[i] = i;
    _tyequiv[TYchar] = TYschar;         /* chars are signed by default  */

    // These values are adjusted in util_set32() for 32 bit ints
    _tyequiv[TYint] = TYshort;
    _tyequiv[TYuint] = TYushort;

    fprintf(f,"unsigned char tyequiv[] =\n{ ");
    for (i = 0; i < arraysize(_tyequiv); i++)
    {   fprintf(f,"0x%02x,",_tyequiv[i]);
        if ((i & 7) == 7 && i < arraysize(_tyequiv) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    for (i = 0; i < arraysize(typetab); i++)
        tystring[typetab[i].ty] = typetab[i].string;
    fprintf(f,"const char *tystring[] =\n{ ");
    for (i = 0; i < arraysize(tystring); i++)
    {   fprintf(f,"\"%s\",",tystring[i]);
        if ((i & 7) == 7 && i < arraysize(tystring) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    for (i = 0; i < arraysize(typetab); i++)
        dttab[typetab[i].ty] = typetab[i].debtyp;
    fprintf(f,"unsigned char dttab[] =\n{ ");
    for (i = 0; i < arraysize(dttab); i++)
    {   fprintf(f,"0x%02x,",dttab[i]);
        if ((i & 7) == 7 && i < arraysize(dttab) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    for (i = 0; i < arraysize(typetab); i++)
        dttab4[typetab[i].ty] = typetab[i].debtyp4;
    fprintf(f,"unsigned short dttab4[] =\n{ ");
    for (i = 0; i < arraysize(dttab4); i++)
    {   fprintf(f,"0x%02x,",dttab4[i]);
        if ((i & 7) == 7 && i < arraysize(dttab4) - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n};\n");

    fclose(f);
}
