/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/optabgen.d, backend/optabgen.d)
 */

module optabgen;

/* Generate op-code tables
 * Creates optab.d,tytab.d,debtab.d,cdxxx.d,elxxx.d
 */

import core.stdc.stdio;
import core.stdc.stdlib;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.oper;
import dmd.backend.ty;

ubyte[OPMAX] xptab1,xptab2,xptab3;

int[] _binary = [
         OPadd,OPmul,OPand,OPmin,OPcond,OPcomma,OPdiv,OPmod,OPxor,
         OPor,OPoror,OPandand,OPshl,OPshr,OPashr,OPstreq,OPstrcpy,OPstrcat,OPstrcmp,
         OPpostinc,OPpostdec,OPeq,OPaddass,OPminass,OPmulass,OPdivass,
         OPmodass,OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,
         OPle,OPgt,OPlt,OPge,OPeqeq,OPne,OPparam,OPcall,OPcallns,OPcolon,OPcolon2,
         OPbit,OPbrack,OParrowstar,OPmemcpy,OPmemcmp,OPmemset,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
         OPinfo,OPpair,OPrpair,
         OPbt,OPbtc,OPbtr,OPbts,OPror,OProl,OPbtst,
         OPremquo,OPcmpxchg,
         OPoutp,OPscale,OPyl2x,OPyl2xp1,
         OPvecsto,OPprefetch
        ];
int[] _unary =
        [OPnot,OPcom,OPind,OPaddr,OPneg,OPuadd,
         OPabs,OPrndtol,OPrint,
         OPpreinc,OPpredec,
         OPbool,OPstrlen,
         OPb_8,OPs16_32,OPu16_32,OPd_s32,OPd_u32,
         OPs32_d,OPu32_d,OPd_s16,OPs16_d,OP32_16,
         OPd_f,OPf_d,OPu8_16,OPs8_16,OP16_8,
         OPd_ld, OPld_d,OPc_r,OPc_i,
         OPu32_64,OPs32_64,OP64_32,OPmsw,
         OPd_s64,OPs64_d,OPd_u64,OPu64_d,OPld_u64,
         OP128_64,OPs64_128,OPu64_128,
         OPucall,OPucallns,OPstrpar,OPstrctor,OPu16_d,OPd_u16,
         OParrow,OPnegass,
         OPctor,OPdtor,OPsetjmp,OPvoid,
         OPbsf,OPbsr,OPbswap,OPpopcnt,
         OPddtor,
         OPvector,OPvecfill,
         OPva_start,
         OPsqrt,OPsin,OPcos,OPinp,
         OPvp_fp,OPcvp_fp,OPnp_fp,OPnp_f16p,OPf16p_np,OPoffset,
        ];
int[] _commut = [OPadd,OPand,OPor,OPxor,OPmul,OPeqeq,OPne,OPle,OPlt,OPge,OPgt,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
        ];
int[] _assoc = [OPadd,OPand,OPor,OPxor,OPmul];
int[] _assign =
        [OPstreq,OPeq,OPaddass,OPminass,OPmulass,OPdivass,OPmodass,
         OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,OPpostinc,OPpostdec,
         OPnegass,OPvecsto,OPcmpxchg,
        ];
int[] _wid =
        [OPadd,OPmin,OPand,OPor,OPxor,OPcom,OPneg,OPmul,OPaddass,OPnegass,
         OPminass,OPandass,OPorass,OPxorass,OPmulass,OPshlass,OPshl,OPshrass,
         OPashrass,
        ];
int[] _eop0e =
        [OPadd,OPmin,OPxor,OPor,OPshl,OPshr,OPashr,OPpostinc,OPpostdec,OPaddass,
         OPminass,OPshrass,OPashrass,OPshlass,OPxorass,OPorass,
         OPror,OProl,
        ];
int[] _eop00 = [OPmul,OPand,OPmulass,OPandass];
int[] _eop1e = [OPmul,OPdiv,OPmulass,OPdivass];
int[] _call = [OPcall,OPucall,OPcallns,OPucallns];
int[] _rel = [OPeqeq,OPne,OPle,OPlt,OPgt,OPge,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
        ];
int[] _logical = [OPeqeq,OPne,OPle,OPlt,OPgt,OPge,OPandand,OPoror,OPnot,OPbool,
         OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
         OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
         OPbt,OPbtst,
        ];
int[] _def = [OPstreq,OPeq,OPaddass,OPminass,OPmulass,OPdivass,OPmodass,
                OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,
                OPpostinc,OPpostdec,
                OPcall,OPucall,OPasm,OPstrcpy,OPmemcpy,OPmemset,OPstrcat,
                OPnegass,
                OPbtc,OPbtr,OPbts,
                OPvecsto,OPcmpxchg,
             ];
int[] _sideff = [OPasm,OPucall,OPstrcpy,OPmemcpy,OPmemset,OPstrcat,
                OPcall,OPeq,OPstreq,OPpostinc,OPpostdec,
                OPaddass,OPminass,OPmulass,OPdivass,OPmodass,OPandass,
                OPorass,OPxorass,OPshlass,OPshrass,OPashrass,
                OPnegass,OPctor,OPdtor,OPmark,OPvoid,
                OPbtc,OPbtr,OPbts,
                OPhalt,OPdctor,OPddtor,
                OPcmpxchg,
                OPva_start,
                OPinp,OPoutp,OPvecsto,OPprefetch,
                ];
int[] _rtol = [OPeq,OPstreq,OPstrcpy,OPmemcpy,OPpostinc,OPpostdec,OPaddass,
                OPminass,OPmulass,OPdivass,OPmodass,OPandass,
                OPorass,OPxorass,OPshlass,OPshrass,OPashrass,
                OPcall,OPcallns,OPinfo,OPmemset,
                OPvecsto,OPcmpxchg,
                ];
int[] _ae = [OPvar,OPconst,OPrelconst,OPneg,
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
                OPsizeof,
                OPcallns,OPucallns,OPpair,OPrpair,
                OPbsf,OPbsr,OPbt,OPbswap,OPb_8,OPbtst,OPpopcnt,
                OPgot,OPremquo,
                OPnullptr,
                OProl,OPror,
                OPsqrt,OPsin,OPcos,OPscale,
                OPvp_fp,OPcvp_fp,OPnp_fp,OPnp_f16p,OPf16p_np,OPoffset,OPvecfill,
                ];
int[] _boolnop = [OPuadd,OPbool,OPs16_32,OPu16_32,
                OPs16_d,
                OPf_d,OPu8_16,OPs8_16,
                OPd_ld, OPld_d,
                OPu32_64,OPs32_64,/*OP64_32,OPmsw,*/
                OPs64_128,OPu64_128,
                OPu16_d,OPb_8,
                OPnullptr,
                OPnp_fp,OPvp_fp,OPcvp_fp,
                OPvecfill,
                ];
int[] _lvalue = [OPvar,OPind,OPcomma,OPbit];

FILE *fdeb;

int main()
{
    printf("OPTABGEN... generating files\n");
    fdeb = fopen("debtab.d","w");
    dooptab();
    dotab();
    fltables();
    dotytab();
    fclose(fdeb);
    return 0;
}

int cost(OPER op)
{       uint c;

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
            case OPcall:
            case OPucall:
            case OPcallns:
            case OPucallns:
                                c += 10; break; // very high cost for function calls

            default:
                break;
        }
        return c;
}

void dooptab()
{       int i;
        FILE *f;

        /* Load optab[] */
        static void X1(int[] arr, uint mask) { for(int i=0; i<arr.length; i++) xptab1[arr[i]] |= mask; }
        static void X2(int[] arr, uint mask) { for(int i=0; i<arr.length; i++) xptab2[arr[i]] |= mask; }
        static void X3(int[] arr, uint mask) { for(int i=0; i<arr.length; i++) xptab3[arr[i]] |= mask; }

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

        X3(_boolnop,_OTboolnop);

        f = fopen("optab.d","w");
        fprintf(f,"extern (C) __gshared ubyte[OPMAX] optab1 =\n\t[");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",xptab1[i]);
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t];\n");
        fprintf(f,"extern (C) __gshared ubyte[OPMAX] optab2 =\n\t[");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",xptab2[i]);
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t];\n");
        fprintf(f,"extern (C) __gshared ubyte[OPMAX] optab3 =\n\t[");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",xptab3[i]);
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t];\n");

        fprintf(f,"extern (C) __gshared ubyte[OPMAX] opcost =\n\t[");
        for (i = 0; i < OPMAX; i++)
        {       if ((i & 7) == 0)
                        fprintf(f,"\n\t");
                fprintf(f,"0x%x",cost(i));
                if (i != OPMAX - 1)
                        fprintf(f,",");
        }
        fprintf(f,"\t];\n");

        doreltables(f);
        fclose(f);
}

/********************************************************
 */

void doreltables(FILE *f)
{
        struct RelTables
        {   OPER op;            /* operator                             */
            OPER inot;          /* for logical negation                 */
            OPER swap;          /* if operands are swapped              */
            OPER integral;      /* if operands are integral types       */
            int exception;      /* if invalid exception is generated    */
            int unord;          /* result of unordered operand(s)       */
        }
        static RelTables[26] reltables =
        [ /*    op      not     swap    int     exc     unord   */
            { OPeqeq,   OPne,   OPeqeq, OPeqeq, 0,      0 },
            { OPne,     OPeqeq, OPne,   OPne,   0,      1 },
            { OPgt,     OPngt,  OPlt,   OPgt,   1,      0 },
            { OPge,     OPnge,  OPle,   OPge,   1,      0 },
            { OPlt,     OPnlt,  OPgt,   OPlt,   1,      0 },
            { OPle,     OPnle,  OPge,   OPle,   1,      0 },

            { OPunord, OPord,   OPunord, cast(OPER)0,0,1 },
            { OPlg,     OPnlg,  OPlg,   OPne,   1,      0 },
            { OPleg,    OPnleg, OPleg,  cast(OPER)1,1, 0 },
            { OPule,    OPnule, OPuge,  OPle,   0,      1 },
            { OPul,     OPnul,  OPug,   OPlt,   0,      1 },
            { OPuge,    OPnuge, OPule,  OPge,   0,      1 },
            { OPug,     OPnug,  OPul,   OPgt,   0,      1 },
            { OPue,     OPnue,  OPue,   OPeqeq, 0,      1 },

            { OPngt,    OPgt,   OPnlt,  OPle,   1,      1 },
            { OPnge,    OPge,   OPnle,  OPlt,   1,      1 },
            { OPnlt,    OPlt,   OPngt,  OPge,   1,      1 },
            { OPnle,    OPle,   OPnge,  OPgt,   1,      1 },
            { OPord,    OPunord, OPord, cast(OPER)1,0, 0 },
            { OPnlg,    OPlg,   OPnlg,  OPeqeq, 1,      1 },
            { OPnleg,   OPleg,  OPnleg, cast(OPER)0,1, 1 },
            { OPnule,   OPule,  OPnuge, OPgt,   0,      0 },
            { OPnul,    OPul,   OPnug,  OPge,   0,      0 },
            { OPnuge,   OPuge,  OPnule, OPlt,   0,      0 },
            { OPnug,    OPug,   OPnul,  OPle,   0,      0 },
            { OPnue,    OPue,   OPnue,  OPne,   0,      0 },
        ];
        enum RELMAX = reltables.length;
        OPER[RELMAX] rel_not;
        OPER[RELMAX] rel_swap;
        OPER[RELMAX] rel_integral;
        int[RELMAX] rel_exception;
        int[RELMAX] rel_unord;
        int i;

        for (i = 0; i < RELMAX; i++)
        {   int j = cast(int)(reltables[i].op) - RELOPMIN;

            assert(j >= 0 && j < RELMAX);
            rel_not      [j] = reltables[i].inot;
            rel_swap     [j] = reltables[i].swap;
            rel_integral [j] = reltables[i].integral;
            rel_exception[j] = reltables[i].exception;
            rel_unord    [j] = reltables[i].unord;
        }

    fprintf(f,"__gshared ubyte[%d] _rel_not =\n[ ", RELMAX);
    for (i = 0; i < rel_not.length; i++)
    {   fprintf(f,"0x%02x,",rel_not[i]);
        if ((i & 7) == 7 && i < rel_not.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    fprintf(f,"__gshared ubyte[%d] _rel_swap =\n[ ", RELMAX);
    for (i = 0; i < rel_swap.length; i++)
    {   fprintf(f,"0x%02x,",rel_swap[i]);
        if ((i & 7) == 7 && i < rel_swap.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    fprintf(f,"__gshared ubyte[%d] _rel_integral =\n[ ", RELMAX);
    for (i = 0; i < rel_integral.length; i++)
    {   fprintf(f,"0x%02x,",rel_integral[i]);
        if ((i & 7) == 7 && i < rel_integral.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    fprintf(f,"__gshared ubyte[%d] _rel_exception =\n[ ", RELMAX);
    for (i = 0; i < rel_exception.length; i++)
    {   fprintf(f,"0x%02x,",rel_exception[i]);
        if ((i & 7) == 7 && i < rel_exception.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    fprintf(f,"__gshared ubyte[%d] _rel_unord =\n[ ", RELMAX);
    for (i = 0; i < rel_unord.length; i++)
    {   fprintf(f,"0x%02x,",rel_unord[i]);
        if ((i & 7) == 7 && i < rel_unord.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");
}


/********************************************************
 */

string[OPMAX] debtab, cdxxx, elxxx;

void dotab()
{ int i;
  FILE *f;

  void X(string d, string e, string c) { debtab[i]=d; cdxxx[i]=c; elxxx[i]=e; }

  for (i = 0; i < OPMAX; i++)
  {
    switch (i)
    {
        case OPunde:    X("unde",       "elerr",  "cderr"); break;
        case OPadd:     X("+",          "eladd",  "cdorth"); break;
        case OPmul:     X("*",          "elmul",  "cdmul"); break;
        case OPand:     X("&",          "elbitwise", "cdorth"); break;
        case OPmin:     X("-",          "elmin",  "cdorth"); break;
        case OPnot:     X("!",          "elnot",  "cdnot"); break;
        case OPcom:     X("~",          "elcom",  "cdcom"); break;
        case OPcond:    X("?",          "elcond", "cdcond"); break;
        case OPcomma:   X(",",          "elcomma", "cdcomma"); break;
        case OPremquo:  X("/%",         "elremquo", "cdmul"); break;
        case OPdiv:     X("/",          "eldiv",  "cdmul"); break;
        case OPmod:     X("%",          "elmod",  "cdmul"); break;
        case OPxor:     X("^",          "elxor",  "cdorth"); break;
        case OPstring:  X("string",     "elstring", "cderr"); break;
        case OPrelconst: X("relconst",  "elzot", "cdrelconst"); break;
        case OPinp:     X("inp",        "elzot", "cdport"); break;
        case OPoutp:    X("outp",       "elzot", "cdport"); break;
        case OPasm:     X("asm",        "elzot", "cdasm"); break;
        case OPinfo:    X("info",       "elinfo", "cdinfo"); break;
        case OPdctor:   X("dctor",      "elzot", "cddctor"); break;
        case OPddtor:   X("ddtor",      "elddtor", "cdddtor"); break;
        case OPctor:    X("ctor",       "elinfo", "cdctor"); break;
        case OPdtor:    X("dtor",       "elinfo", "cddtor"); break;
        case OPmark:    X("mark",       "elinfo", "cdmark"); break;
        case OPvoid:    X("void",       "elzot", "cdvoid"); break;
        case OPhalt:    X("halt",       "elzot", "cdhalt"); break;
        case OPnullptr: X("nullptr",    "elerr", "cderr"); break;
        case OPpair:    X("pair",       "elpair", "cdpair"); break;
        case OPrpair:   X("rpair",      "elpair", "cdpair"); break;

        case OPor:      X("|",          "elor",   "cdorth"); break;
        case OPoror:    X("||",         "eloror", "cdloglog"); break;
        case OPandand:  X("&&",         "elandand", "cdloglog"); break;
        case OProl:     X("<<|",        "elshl",  "cdshift"); break;
        case OPror:     X(">>|",        "elshl",  "cdshift"); break;
        case OPshl:     X("<<",         "elshl",  "cdshift"); break;
        case OPshr:     X(">>>",        "elshr",  "cdshift"); break;
        case OPashr:    X(">>",         "elshr",  "cdshift"); break;
        case OPbit:     X("bit",        "elbit",  "cderr"); break;
        case OPind:     X("*",          "elind",  "cdind"); break;
        case OPaddr:    X("&",          "eladdr", "cderr"); break;
        case OPneg:     X("-",          "elneg",  "cdneg"); break;
        case OPuadd:    X("+",          "elzot",  "cderr"); break;
        case OPabs:     X("abs",        "evalu8", "cdabs"); break;
        case OPsqrt:    X("sqrt",       "evalu8", "cdneg"); break;
        case OPsin:     X("sin",        "evalu8", "cdneg"); break;
        case OPcos:     X("cos",        "evalu8", "cdneg"); break;
        case OPscale:   X("scale",      "elzot",  "cdscale"); break;
        case OPyl2x:    X("yl2x",       "elzot",  "cdscale"); break;
        case OPyl2xp1:  X("yl2xp1",     "elzot",  "cdscale"); break;
        case OPcmpxchg:     X("cas",        "elzot",  "cdcmpxchg"); break;
        case OPrint:    X("rint",       "evalu8", "cdneg"); break;
        case OPrndtol:  X("rndtol",     "evalu8", "cdrndtol"); break;
        case OPstrlen:  X("strlen",     "elzot",  "cdstrlen"); break;
        case OPstrcpy:  X("strcpy",     "elstrcpy", "cdstrcpy"); break;
        case OPmemcpy:  X("memcpy",     "elmemcpy", "cdmemcpy"); break;
        case OPmemset:  X("memset",     "elmemset", "cdmemset"); break;
        case OPstrcat:  X("strcat",     "elzot",  "cderr"); break;
        case OPstrcmp:  X("strcmp",     "elstrcmp", "cdstrcmp"); break;
        case OPmemcmp:  X("memcmp",     "elmemcmp", "cdmemcmp"); break;
        case OPsetjmp:  X("setjmp",     "elzot",  "cdsetjmp"); break;
        case OPnegass:  X("negass",     "elnegass", "cdaddass"); break;
        case OPpreinc:  X("U++",        "elzot",  "cderr"); break;
        case OPpredec:  X("U--",        "elzot",  "cderr"); break;
        case OPstreq:   X("streq",      "elstruct", "cdstreq"); break;
        case OPpostinc: X("++",         "elpost", "cdpost"); break;
        case OPpostdec: X("--",         "elpost", "cdpost"); break;
        case OPeq:      X("=",          "eleq",   "cdeq"); break;
        case OPaddass:  X("+=",         "elopass", "cdaddass"); break;
        case OPminass:  X("-=",         "elopass", "cdaddass"); break;
        case OPmulass:  X("*=",         "elopass", "cdmulass"); break;
        case OPdivass:  X("/=",         "elopass", "cdmulass"); break;
        case OPmodass:  X("%=",         "elopass", "cdmulass"); break;
        case OPshrass:  X(">>>=",       "elopass", "cdshass"); break;
        case OPashrass: X(">>=",        "elopass", "cdshass"); break;
        case OPshlass:  X("<<=",        "elopass", "cdshass"); break;
        case OPandass:  X("&=",         "elopass", "cdaddass"); break;
        case OPxorass:  X("^=",         "elopass", "cdaddass"); break;
        case OPorass:   X("|=",         "elopass", "cdaddass"); break;

        case OPle:      X("<=",         "elcmp",  "cdcmp"); break;
        case OPgt:      X(">",          "elcmp",  "cdcmp"); break;
        case OPlt:      X("<",          "elcmp",  "cdcmp"); break;
        case OPge:      X(">=",         "elcmp",  "cdcmp"); break;
        case OPeqeq:    X("==",         "elcmp",  "cdcmp"); break;
        case OPne:      X("!=",         "elcmp",  "cdcmp"); break;

        case OPunord:   X("!<>=",       "elcmp",  "cdcmp"); break;
        case OPlg:      X("<>",         "elcmp",  "cdcmp"); break;
        case OPleg:     X("<>=",        "elcmp",  "cdcmp"); break;
        case OPule:     X("!>",         "elcmp",  "cdcmp"); break;
        case OPul:      X("!>=",        "elcmp",  "cdcmp"); break;
        case OPuge:     X("!<",         "elcmp",  "cdcmp"); break;
        case OPug:      X("!<=",        "elcmp",  "cdcmp"); break;
        case OPue:      X("!<>",        "elcmp",  "cdcmp"); break;
        case OPngt:     X("~>",         "elcmp",  "cdcmp"); break;
        case OPnge:     X("~>=",        "elcmp",  "cdcmp"); break;
        case OPnlt:     X("~<",         "elcmp",  "cdcmp"); break;
        case OPnle:     X("~<=",        "elcmp",  "cdcmp"); break;
        case OPord:     X("~!<>=",      "elcmp",  "cdcmp"); break;
        case OPnlg:     X("~<>",        "elcmp",  "cdcmp"); break;
        case OPnleg:    X("~<>=",       "elcmp",  "cdcmp"); break;
        case OPnule:    X("~!>",        "elcmp",  "cdcmp"); break;
        case OPnul:     X("~!>=",       "elcmp",  "cdcmp"); break;
        case OPnuge:    X("~!<",        "elcmp",  "cdcmp"); break;
        case OPnug:     X("~!<=",       "elcmp",  "cdcmp"); break;
        case OPnue:     X("~!<>",       "elcmp",  "cdcmp"); break;

        case OPvp_fp:   X("vptrfptr",   "elvptrfptr", "cdcnvt"); break;
        case OPcvp_fp:  X("cvptrfptr",  "elvptrfptr", "cdcnvt"); break;
        case OPoffset:  X("offset",     "ellngsht", "cdlngsht"); break;
        case OPnp_fp:   X("ptrlptr",    "elptrlptr", "cdshtlng"); break;
        case OPnp_f16p: X("tofar16",    "elzot",  "cdfar16"); break;
        case OPf16p_np: X("fromfar16",  "elzot",  "cdfar16"); break;

        case OPs16_32:  X("s16_32",     "evalu8", "cdshtlng"); break;
        case OPu16_32:  X("u16_32",     "evalu8", "cdshtlng"); break;
        case OPd_s32:   X("d_s32",      "evalu8", "cdcnvt"); break;
        case OPb_8:     X("b_8",        "evalu8", "cdcnvt"); break;
        case OPs32_d:   X("s32_d",      "evalu8", "cdcnvt"); break;
        case OPd_s16:   X("d_s16",      "evalu8", "cdcnvt"); break;
        case OPs16_d:   X("s16_d",      "evalu8", "cdcnvt"); break;
        case OPd_u16:   X("d_u16",      "evalu8", "cdcnvt"); break;
        case OPu16_d:   X("u16_d",      "evalu8", "cdcnvt"); break;
        case OPd_u32:   X("d_u32",      "evalu8", "cdcnvt"); break;
        case OPu32_d:   X("u32_d",      "evalu8", "cdcnvt"); break;
        case OP32_16:   X("32_16",      "ellngsht", "cdlngsht"); break;
        case OPd_f:     X("d_f",        "evalu8", "cdcnvt"); break;
        case OPf_d:     X("f_d",        "evalu8", "cdcnvt"); break;
        case OPd_ld:    X("d_ld",       "evalu8", "cdcnvt"); break;
        case OPld_d:    X("ld_d",       "evalu8", "cdcnvt"); break;
        case OPc_r:     X("c_r",        "elc_r",  "cdconvt87"); break;
        case OPc_i:     X("c_i",        "elc_i",  "cdconvt87"); break;
        case OPu8_16:   X("u8_16",      "elbyteint", "cdbyteint"); break;
        case OPs8_16:   X("s8_16",      "elbyteint", "cdbyteint"); break;
        case OP16_8:    X("16_8",       "ellngsht", "cdlngsht"); break;
        case OPu32_64:  X("u32_64",     "el32_64", "cdshtlng"); break;
        case OPs32_64:  X("s32_64",     "el32_64", "cdshtlng"); break;
        case OP64_32:   X("64_32",      "el64_32", "cdlngsht"); break;
        case OPu64_128: X("u64_128",    "evalu8", "cdshtlng"); break;
        case OPs64_128: X("s64_128",    "evalu8", "cdshtlng"); break;
        case OP128_64:  X("128_64",     "el64_32", "cdlngsht"); break;
        case OPmsw:     X("msw",        "elmsw", "cdmsw"); break;

        case OPd_s64:   X("d_s64",      "evalu8", "cdcnvt"); break;
        case OPs64_d:   X("s64_d",      "evalu8", "cdcnvt"); break;
        case OPd_u64:   X("d_u64",      "evalu8", "cdcnvt"); break;
        case OPu64_d:   X("u64_d",      "elu64_d", "cdcnvt"); break;
        case OPld_u64:  X("ld_u64",     "evalu8", "cdcnvt"); break;
        case OPparam:   X("param",      "elparam", "cderr"); break;
        case OPsizeof:  X("sizeof",     "elzot",  "cderr"); break;
        case OParrow:   X("->",         "elzot",  "cderr"); break;
        case OParrowstar: X("->*",      "elzot",  "cderr"); break;
        case OPcolon:   X("colon",      "elzot",  "cderr"); break;
        case OPcolon2:  X("colon2",     "elzot",  "cderr"); break;
        case OPbool:    X("bool",       "elbool", "cdnot"); break;
        case OPcall:    X("call",       "elcall", "cdfunc"); break;
        case OPucall:   X("ucall",      "elcall", "cdfunc"); break;
        case OPcallns:  X("callns",     "elcall", "cdfunc"); break;
        case OPucallns: X("ucallns",    "elcall", "cdfunc"); break;
        case OPstrpar:  X("strpar",     "elstruct", "cderr"); break;
        case OPstrctor: X("strctor",    "elzot",  "cderr"); break;
        case OPstrthis: X("strthis",    "elzot",  "cdstrthis"); break;
        case OPconst:   X("const",      "elerr",  "cderr"); break;
        case OPvar:     X("var",        "elerr",  "loaddata"); break;
        case OPreg:     X("reg",        "elerr",  "cderr"); break;
        case OPnew:     X("new",        "elerr",  "cderr"); break;
        case OPanew:    X("new[]",      "elerr",  "cderr"); break;
        case OPdelete:  X("delete",     "elerr",  "cderr"); break;
        case OPadelete: X("delete[]",   "elerr",  "cderr"); break;
        case OPbrack:   X("brack",      "elerr",  "cderr"); break;
        case OPframeptr: X("frameptr",  "elzot",  "cdframeptr"); break;
        case OPgot:     X("got",        "elzot",  "cdgot"); break;

        case OPbsf:     X("bsf",        "elzot",  "cdbscan"); break;
        case OPbsr:     X("bsr",        "elzot",  "cdbscan"); break;
        case OPbtst:    X("btst",       "elzot",  "cdbtst"); break;
        case OPbt:      X("bt",         "elzot",  "cdbt"); break;
        case OPbtc:     X("btc",        "elzot",  "cdbt"); break;
        case OPbtr:     X("btr",        "elzot",  "cdbt"); break;
        case OPbts:     X("bts",        "elzot",  "cdbt"); break;

        case OPbswap:   X("bswap",      "evalu8", "cdbswap"); break;
        case OPpopcnt:  X("popcnt",     "evalu8", "cdpopcnt"); break;
        case OPvector:  X("vector",     "elzot",  "cdvector"); break;
        case OPvecsto:  X("vecsto",     "elzot",  "cdvecsto"); break;
        case OPvecfill: X("vecfill",    "elzot",  "cdvecfill"); break;
        case OPva_start: X("va_start",  "elvalist", "cderr"); break;
        case OPprefetch: X("prefetch",  "elzot",  "cdprefetch"); break;

        default:
                printf("opcode hole x%x\n",i);
                exit(EXIT_FAILURE);
    }
  }

  fprintf(fdeb,"extern (C++) __gshared const(char)*[OPMAX] debtab = \n\t[\n");
  for (i = 0; i < OPMAX - 1; i++)
        fprintf(fdeb,"\t\"%.*s\",\n",cast(int)debtab[i].length, debtab[i].ptr);
  fprintf(fdeb,"\t\"%.*s\"\n\t];\n",cast(int)debtab[i].length, debtab[i].ptr);

  f = fopen("cdxxx.d","w");
  fprintf(f,"__gshared void function (ref CodeBuilder,elem *,regm_t *)[OPMAX] cdxxx = \n\t[\n");
  for (i = 0; i < OPMAX - 1; i++)
        fprintf(f,"\t&%.*s,\n",cast(int)cdxxx[i].length, cdxxx[i].ptr);
  fprintf(f,"\t&%.*s\n\t];\n", cast(int)cdxxx[i].length, cdxxx[i].ptr);
  fclose(f);

static if (1)
{
    {
        f = fopen("elxxx.d","w");
        fprintf(f,"extern (C++) __gshared elem *function(elem *, goal_t)[OPMAX] elxxx = \n\t[\n");
        for (i = 0; i < OPMAX - 1; i++)
            fprintf(f,"\t&%s,\n",elxxx[i].ptr);
        fprintf(f,"\t&%s\n\t];\n",elxxx[i].ptr);
        fclose(f);
    }
}
else
{
    {
        f = fopen("elxxx.c","w");
        fprintf(f,"static elem *(*elxxx[OPMAX]) (elem *, goal_t) = \n\t{\n");
        for (i = 0; i < OPMAX - 1; i++)
            fprintf(f,"\t%s,\n",elxxx[i].ptr);
        fprintf(f,"\t%s\n\t};\n",elxxx[i].ptr);
        fclose(f);
    }
}
}

void fltables()
{       FILE *f;
        int i;
        char[FLMAX] segfl, datafl, stackfl, flinsymtab;

        static char[] indatafl =        /* is FLxxxx a data type?       */
        [ FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,
          FLcs,FLfltreg,FLallocatmp,FLdatseg,FLtlsdata,FLbprel,
          FLstack,FLregsave,FLfuncarg,
          FLndp,
        ];
        static char[] indatafl_s = [ FLfardata, ];

        static char[] instackfl =       /* is FLxxxx a stack data type? */
        [ FLauto,FLfast,FLpara,FLcs,FLfltreg,FLallocatmp,FLbprel,FLstack,FLregsave,
          FLfuncarg,
          FLndp,
        ];

        static char[] inflinsymtab =    /* is FLxxxx in the symbol table? */
        [ FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,FLfunc,
          FLtlsdata,FLbprel,FLstack ];
        static char[] inflinsymtab_s = [ FLfardata,FLcsdata, ];

        for (i = 0; i < FLMAX; i++)
                datafl[i] = stackfl[i] = flinsymtab[i] = 0;

        for (i = 0; i < indatafl.length; i++)
                datafl[indatafl[i]] = 1;

        for (i = 0; i < instackfl.length; i++)
                stackfl[instackfl[i]] = 1;

        for (i = 0; i < inflinsymtab.length; i++)
                flinsymtab[inflinsymtab[i]] = 1;

        for (i = 0; i < indatafl_s.length; i++)
                datafl[indatafl_s[i]] = 1;

        for (i = 0; i < inflinsymtab_s.length; i++)
                flinsymtab[inflinsymtab_s[i]] = 1;

/* Segment registers    */
enum ES = 0;
enum CS = 1;
enum SS = 2;
enum DS = 3;

        for (i = 0; i < FLMAX; i++)
        {   switch (i)
            {
                case 0:         segfl[i] = cast(byte)-1;  break;
                case FLconst:   segfl[i] = cast(byte)-1;  break;
                case FLoper:    segfl[i] = cast(byte)-1;  break;
                case FLfunc:    segfl[i] = CS;  break;
                case FLdata:    segfl[i] = DS;  break;
                case FLudata:   segfl[i] = DS;  break;
                case FLreg:     segfl[i] = cast(byte)-1;  break;
                case FLpseudo:  segfl[i] = cast(byte)-1;  break;
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
                case FLswitch:  segfl[i] = cast(byte)-1;  break;
                case FLfltreg:  segfl[i] = SS;  break;
                case FLoffset:  segfl[i] = cast(byte)-1;  break;
                case FLfardata: segfl[i] = cast(byte)-1;  break;
                case FLcsdata:  segfl[i] = CS;  break;
                case FLdatseg:  segfl[i] = DS;  break;
                case FLctor:    segfl[i] = cast(byte)-1;  break;
                case FLdtor:    segfl[i] = cast(byte)-1;  break;
                case FLdsymbol: segfl[i] = cast(byte)-1;  break;
                case FLgot:     segfl[i] = cast(byte)-1;  break;
                case FLgotoff:  segfl[i] = cast(byte)-1;  break;
                case FLlocalsize: segfl[i] = cast(byte)-1;        break;
                case FLtlsdata: segfl[i] = cast(byte)-1;  break;
                case FLframehandler:    segfl[i] = cast(byte)-1;  break;
                case FLasm:     segfl[i] = cast(byte)-1;  break;
                case FLallocatmp:       segfl[i] = SS;  break;
                case FLfuncarg:         segfl[i] = SS;  break;
                default:
                        printf("error in segfl[%d]\n", i);
                        exit(1);
            }
        }

        f = fopen("fltables.d","w");
        fprintf(f, "extern (C++) __gshared {\n");

        fprintf(f,"ubyte[FLMAX] datafl = \n\t[ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"cast(ubyte)%d,",datafl[i]);
        fprintf(f,"cast(ubyte)%d ];\n",datafl[i]);

        fprintf(f,"ubyte[FLMAX] stackfl = \n\t[ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"cast(ubyte)%d,",stackfl[i]);
        fprintf(f,"cast(ubyte)%d ];\n",stackfl[i]);

        fprintf(f,"ubyte[FLMAX] segfl = \n\t[ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"cast(ubyte)%d,",segfl[i]);
        fprintf(f,"cast(ubyte)%d ];\n",segfl[i]);

        fprintf(f,"ubyte[FLMAX] flinsymtab = \n\t[ ");
        for (i = 0; i < FLMAX - 1; i++)
                fprintf(f,"cast(ubyte)%d,",flinsymtab[i]);
        fprintf(f,"cast(ubyte)%d ];\n",flinsymtab[i]);

        fprintf(f, "}\n");
        fclose(f);
}

void dotytab()
{
    static tym_t[] _ptr      = [ TYnptr ];
    static tym_t[] _ptr_nflat= [ TYsptr,TYcptr,TYf16ptr,TYfptr,TYhptr,TYvptr ];
    static tym_t[] _real     = [ TYfloat,TYdouble,TYdouble_alias,TYldouble,
                                 TYfloat4,TYdouble2,
                                 TYfloat8,TYdouble4,
                                 TYfloat16,TYdouble8,
                               ];
    static tym_t[] _imaginary = [
                                 TYifloat,TYidouble,TYildouble,
                               ];
    static tym_t[] _complex =  [
                                 TYcfloat,TYcdouble,TYcldouble,
                               ];
    static tym_t[] _integral = [ TYbool,TYchar,TYschar,TYuchar,TYshort,
                                 TYwchar_t,TYushort,TYenum,TYint,TYuint,
                                 TYlong,TYulong,TYllong,TYullong,TYdchar,
                                 TYschar16,TYuchar16,TYshort8,TYushort8,
                                 TYlong4,TYulong4,TYllong2,TYullong2,
                                 TYschar32,TYuchar32,TYshort16,TYushort16,
                                 TYlong8,TYulong8,TYllong4,TYullong4,
                                 TYschar64,TYuchar64,TYshort32,TYushort32,
                                 TYlong16,TYulong16,TYllong8,TYullong8,
                                 TYchar16,TYcent,TYucent,
                               ];
    static tym_t[] _ref      = [ TYnref,TYref ];
    static tym_t[] _func     = [ TYnfunc,TYnpfunc,TYnsfunc,TYifunc,TYmfunc,TYjfunc,TYhfunc ];
    static tym_t[] _ref_nflat = [ TYfref ];
    static tym_t[] _func_nflat= [ TYffunc,TYfpfunc,TYf16func,TYfsfunc,TYnsysfunc,TYfsysfunc, ];
    static tym_t[] _uns     = [ TYuchar,TYushort,TYuint,TYulong,
                                TYwchar_t,
                                TYuchar16,TYushort8,TYulong4,TYullong2,
                                TYdchar,TYullong,TYucent,TYchar16 ];
    static tym_t[] _mptr    = [ TYmemptr ];
    static tym_t[] _nullptr = [ TYnullptr ];
    static tym_t[] _fv      = [ TYfptr, TYvptr ];
    static tym_t[] _farfunc = [ TYffunc,TYfpfunc,TYfsfunc,TYfsysfunc ];
    static tym_t[] _pasfunc = [ TYnpfunc,TYnsfunc,TYmfunc,TYjfunc ];
    static tym_t[] _pasfunc_nf = [ TYfpfunc,TYf16func,TYfsfunc, ];
    static tym_t[] _revfunc = [ TYnpfunc,TYjfunc ];
    static tym_t[] _revfunc_nf = [ TYfpfunc,TYf16func, ];
    static tym_t[] _short     = [ TYbool,TYchar,TYschar,TYuchar,TYshort,
                                  TYwchar_t,TYushort,TYchar16 ];
    static tym_t[] _aggregate = [ TYstruct,TYarray ];
    static tym_t[] _xmmreg = [
                                 TYfloat,TYdouble,TYifloat,TYidouble,
                                 TYfloat4,TYdouble2,
                                 TYschar16,TYuchar16,TYshort8,TYushort8,
                                 TYlong4,TYulong4,TYllong2,TYullong2,
                                 TYfloat8,TYdouble4,
                                 TYschar32,TYuchar32,TYshort16,TYushort16,
                                 TYlong8,TYulong8,TYllong4,TYullong4,
                                 TYschar64,TYuchar64,TYshort32,TYushort32,
                                 TYlong16,TYulong16,TYllong8,TYullong8,
                                 TYfloat16,TYdouble8,
                             ];
    static tym_t[] _simd = [
                                 TYfloat4,TYdouble2,
                                 TYschar16,TYuchar16,TYshort8,TYushort8,
                                 TYlong4,TYulong4,TYllong2,TYullong2,
                                 TYfloat8,TYdouble4,
                                 TYschar32,TYuchar32,TYshort16,TYushort16,
                                 TYlong8,TYulong8,TYllong4,TYullong4,
                                 TYschar64,TYuchar64,TYshort32,TYushort32,
                                 TYlong16,TYulong16,TYllong8,TYullong8,
                                 TYfloat16,TYdouble8,
                             ];

    struct TypeTab
    {
        string str;     /* name of type                 */
        tym_t ty;       /* TYxxxx                       */
        tym_t unsty;    /* conversion to unsigned type  */
        tym_t relty;    /* type for relaxed type checking */
        int size;
        int debtyp;     /* Codeview 1 type in debugger record   */
        int debtyp4;    /* Codeview 4 type in debugger record   */
    }
    static TypeTab[] typetab =
    [
/* Note that chars are signed, here     */
{"bool",         TYbool,         TYbool,    TYchar,      1,      0x80,   0x30},
{"char",         TYchar,         TYuchar,   TYchar,      1,      0x80,   0x70},
{"signed char",  TYschar,        TYuchar,   TYchar,      1,      0x80,   0x10},
{"unsigned char",TYuchar,        TYuchar,   TYchar,      1,      0x84,   0x20},
{"char16_t",     TYchar16,       TYchar16,  TYint,       2,      0x85,   0x21},
{"short",        TYshort,        TYushort,  TYint,       SHORTSIZE, 0x81,0x11},
{"wchar_t",      TYwchar_t,      TYwchar_t, TYint,       SHORTSIZE, 0x85,0x71},
{"unsigned short",TYushort,      TYushort,  TYint,       SHORTSIZE, 0x85,0x21},

// These values are adjusted for 32 bit ints in cv_init() and util_set32()
{"enum",         TYenum,         TYuint,    TYint,       -1,        0x81,0x72},
{"int",          TYint,          TYuint,    TYint,       2,         0x81,0x72},
{"unsigned",     TYuint,         TYuint,    TYint,       2,         0x85,0x73},

{"long",         TYlong,         TYulong,   TYlong,      LONGSIZE,  0x82,0x12},
{"unsigned long",TYulong,        TYulong,   TYlong,      LONGSIZE,  0x86,0x22},
{"dchar",        TYdchar,        TYdchar,   TYlong,      4,         0x86,0x22},
{"long long",    TYllong,        TYullong,  TYllong,     LLONGSIZE, 0x82,0x13},
{"uns long long",TYullong,       TYullong,  TYllong,     LLONGSIZE, 0x86,0x23},
{"cent",         TYcent,         TYucent,   TYcent,      16,        0x82,0x603},
{"ucent",        TYucent,        TYucent,   TYcent,      16,        0x86,0x603},
{"float",        TYfloat,        TYfloat,   TYfloat,     FLOATSIZE, 0x88,0x40},
{"double",       TYdouble,       TYdouble,  TYdouble,    DOUBLESIZE,0x89,0x41},
{"double alias", TYdouble_alias, TYdouble_alias,  TYdouble_alias,8, 0x89,0x41},
{"long double",  TYldouble,      TYldouble,  TYldouble,  -1, 0x89,0x42},

{"imaginary float",      TYifloat,       TYifloat,   TYifloat,   FLOATSIZE, 0x88,0x40},
{"imaginary double",     TYidouble,      TYidouble,  TYidouble,  DOUBLESIZE,0x89,0x41},
{"imaginary long double",TYildouble,     TYildouble, TYildouble, -1,0x89,0x42},

{"complex float",        TYcfloat,       TYcfloat,   TYcfloat,   2*FLOATSIZE, 0x88,0x50},
{"complex double",       TYcdouble,      TYcdouble,  TYcdouble,  2*DOUBLESIZE,0x89,0x51},
{"complex long double",  TYcldouble,     TYcldouble, TYcldouble, -1,0x89,0x52},

{"float[4]",              TYfloat4,    TYfloat4,  TYfloat4,    16,     0,      0},
{"double[2]",             TYdouble2,   TYdouble2, TYdouble2,   16,     0,      0},
{"signed char[16]",       TYschar16,   TYuchar16, TYschar16,   16,     0,      0},
{"unsigned char[16]",     TYuchar16,   TYuchar16, TYuchar16,   16,     0,      0},
{"short[8]",              TYshort8,    TYushort8, TYshort8,    16,     0,      0},
{"unsigned short[8]",     TYushort8,   TYushort8, TYushort8,   16,     0,      0},
{"long[4]",               TYlong4,     TYulong4,  TYlong4,     16,     0,      0},
{"unsigned long[4]",      TYulong4,    TYulong4,  TYulong4,    16,     0,      0},
{"long long[2]",          TYllong2,    TYullong2, TYllong2,    16,     0,      0},
{"unsigned long long[2]", TYullong2,   TYullong2, TYullong2,   16,     0,      0},

{"float[8]",              TYfloat8,    TYfloat8,  TYfloat8,    32,     0,      0},
{"double[4]",             TYdouble4,   TYdouble4, TYdouble4,   32,     0,      0},
{"signed char[32]",       TYschar32,   TYuchar32, TYschar32,   32,     0,      0},
{"unsigned char[32]",     TYuchar32,   TYuchar32, TYuchar32,   32,     0,      0},
{"short[16]",             TYshort16,   TYushort16, TYshort16,  32,     0,      0},
{"unsigned short[16]",    TYushort16,  TYushort16, TYushort16, 32,     0,      0},
{"long[8]",               TYlong8,     TYulong8,  TYlong8,     32,     0,      0},
{"unsigned long[8]",      TYulong8,    TYulong8,  TYulong8,    32,     0,      0},
{"long long[4]",          TYllong4,    TYullong4, TYllong4,    32,     0,      0},
{"unsigned long long[4]", TYullong4,   TYullong4, TYullong4,   32,     0,      0},

{"float[16]",             TYfloat16,   TYfloat16, TYfloat16,   64,     0,      0},
{"double[8]",             TYdouble8,   TYdouble8, TYdouble8,   64,     0,      0},
{"signed char[64]",       TYschar64,   TYuchar64, TYschar64,   64,     0,      0},
{"unsigned char[64]",     TYuchar64,   TYuchar64, TYuchar64,   64,     0,      0},
{"short[32]",             TYshort32,   TYushort32, TYshort32,  64,     0,      0},
{"unsigned short[32]",    TYushort32,  TYushort32, TYushort32, 64,     0,      0},
{"long[16]",              TYlong16,    TYulong16, TYlong16,    64,     0,      0},
{"unsigned long[16]",     TYulong16,   TYulong16, TYulong16,   64,     0,      0},
{"long long[8]",          TYllong8,    TYullong8, TYllong8,    64,     0,      0},
{"unsigned long long[8]", TYullong8,   TYullong8, TYullong8,   64,     0,      0},

{"nullptr_t",    TYnullptr,      TYnullptr, TYptr,       2,  0x20,       0x100},
{"*",            TYnptr,         TYnptr,    TYnptr,      2,  0x20,       0x100},
{"&",            TYref,          TYref,     TYref,       -1,     0,      0},
{"void",         TYvoid,         TYvoid,    TYvoid,      -1,     0x85,   3},
{"struct",       TYstruct,       TYstruct,  TYstruct,    -1,     0,      0},
{"array",        TYarray,        TYarray,   TYarray,     -1,     0x78,   0},
{"C func",       TYnfunc,        TYnfunc,   TYnfunc,     -1,     0x63,   0},
{"Pascal func",  TYnpfunc,       TYnpfunc,  TYnpfunc,    -1,     0x74,   0},
{"std func",     TYnsfunc,       TYnsfunc,  TYnsfunc,    -1,     0x63,   0},
{"*",            TYptr,          TYptr,     TYptr,       2,  0x20,       0x100},
{"member func",  TYmfunc,        TYmfunc,   TYmfunc,     -1,     0x64,   0},
{"D func",       TYjfunc,        TYjfunc,   TYjfunc,     -1,     0x74,   0},
{"C func",       TYhfunc,        TYhfunc,   TYhfunc,     -1,     0,      0},
{"__near &",     TYnref,         TYnref,    TYnref,      2,      0,      0},

{"__ss *",       TYsptr,         TYsptr,    TYsptr,      2,  0x20,       0x100},
{"__cs *",       TYcptr,         TYcptr,    TYcptr,      2,  0x20,       0x100},
{"__far16 *",    TYf16ptr,       TYf16ptr,  TYf16ptr,    4,  0x40,       0x200},
{"__far *",      TYfptr,         TYfptr,    TYfptr,      4,  0x40,       0x200},
{"__huge *",     TYhptr,         TYhptr,    TYhptr,      4,  0x40,       0x300},
{"__handle *",   TYvptr,         TYvptr,    TYvptr,      4,  0x40,       0x200},
{"far C func",   TYffunc,        TYffunc,   TYffunc,     -1,     0x64,   0},
{"far Pascal func", TYfpfunc,    TYfpfunc,  TYfpfunc,    -1,     0x73,   0},
{"far std func", TYfsfunc,       TYfsfunc,  TYfsfunc,    -1,     0x64,   0},
{"_far16 Pascal func", TYf16func, TYf16func, TYf16func,  -1,     0x63,   0},
{"sys func",     TYnsysfunc,     TYnsysfunc,TYnsysfunc,  -1,     0x63,   0},
{"far sys func", TYfsysfunc,     TYfsysfunc,TYfsysfunc,  -1,     0x64,   0},
{"__far &",      TYfref,         TYfref,    TYfref,      4,      0,      0},

{"interrupt func", TYifunc,      TYifunc,   TYifunc,     -1,     0x64,   0},
{"memptr",       TYmemptr,       TYmemptr,  TYmemptr,    -1,     0,      0},
{"ident",        TYident,        TYident,   TYident,     -1,     0,      0},
{"template",     TYtemplate,     TYtemplate, TYtemplate, -1,     0,      0},
{"vtshape",      TYvtshape,      TYvtshape,  TYvtshape,  -1,     0,      0},
    ];

    FILE *f;
    static uint[64 * 4] tytab;
    static tym_t[64 * 4] tytouns;
    static tym_t[TYMAX] _tyrelax;
    static tym_t[TYMAX] _tyequiv;
    static byte[64 * 4] _tysize;
    static string[TYMAX] tystring;
    static ubyte[TYMAX] dttab;
    static ushort[TYMAX] dttab4;
    int i;

    static void T1(tym_t[] arr, uint mask) { for (int i=0; i< arr.length; i++)
                     {  tytab[arr[i]] |= mask; }
                     }
    static void T2(tym_t[] arr, uint mask) { for (int i=0; i< arr.length; i++)
                     {  tytab[arr[i]] |= mask; }
                     }

    T1(_ptr,      TYFLptr);
    T1(_ptr_nflat,TYFLptr);
    T1(_real,     TYFLreal);
    T1(_integral, TYFLintegral);
    T1(_imaginary,TYFLimaginary);
    T1(_complex,  TYFLcomplex);
    T1(_uns,      TYFLuns);
    T1(_mptr,     TYFLmptr);

    T1(_fv,       TYFLfv);
    T2(_farfunc,  TYFLfarfunc);
    T2(_pasfunc,  TYFLpascal);
    T2(_revfunc,  TYFLrevparam);
    T2(_short,    TYFLshort);
    T2(_aggregate,TYFLaggregate);
    T2(_ref,      TYFLref);
    T2(_func,     TYFLfunc);
    T2(_nullptr,  TYFLnullptr);
    T2(_pasfunc_nf, TYFLpascal);
    T2(_revfunc_nf, TYFLrevparam);
    T2(_ref_nflat,  TYFLref);
    T2(_func_nflat, TYFLfunc);
    T1(_xmmreg,    TYFLxmmreg);
    T1(_simd,      TYFLsimd);

    f = fopen("tytab.d","w");

    fprintf(f,"__gshared uint[256] tytab =\n[ ");
    for (i = 0; i < tytab.length; i++)
    {   fprintf(f,"0x%02x,",tytab[i]);
        if ((i & 7) == 7 && i < tytab.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

static if (0)
{
    fprintf(f,"__gshared ubyte[TYMAX] tytab2 =\n[ ");
    for (i = 0; i < tytab2.length; i++)
    {   fprintf(f,"0x%02x,",tytab2[i]);
        if ((i & 7) == 7 && i < tytab2.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");
}

    for (i = 0; i < typetab.length; i++)
    {   tytouns[typetab[i].ty] = typetab[i].unsty;
    }
    fprintf(f,"__gshared tym_t[256] tytouns =\n[ ");
    for (i = 0; i < tytouns.length; i++)
    {   fprintf(f,"0x%02x,",tytouns[i]);
        if ((i & 7) == 7 && i < tytouns.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
    {   _tysize[typetab[i].ty | 0x00] = cast(byte)typetab[i].size;
        /*printf("_tysize[%d] = %d\n",typetab[i].ty,typetab[i].size);*/
    }
    fprintf(f,"__gshared byte[256] _tysize =\n[ ");
    for (i = 0; i < _tysize.length; i++)
    {   fprintf(f,"%d,",_tysize[i]);
        if ((i & 7) == 7 && i < _tysize.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < _tysize.length; i++)
        _tysize[i] = 0;
    for (i = 0; i < typetab.length; i++)
    {   byte sz = cast(byte)typetab[i].size;
        switch (typetab[i].ty)
        {
            case TYldouble:
            case TYildouble:
            case TYcldouble:
static if (TARGET_OSX)
{
                sz = 16;
}
else static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS)
{
                sz = 4;
}
else static if (TARGET_WINDOS)
{
                sz = 2;
}
else
{
                static assert(0, "fix this");
}
                break;

            case TYcent:
            case TYucent:
                sz = 8;
                break;

            default:
                break;
        }
        _tysize[typetab[i].ty | 0x00] = sz;
        /*printf("_tyalignsize[%d] = %d\n",typetab[i].ty,typetab[i].size);*/
    }

    fprintf(f,"__gshared byte[256] _tyalignsize =\n[ ");
    for (i = 0; i < _tysize.length; i++)
    {   fprintf(f,"%d,",_tysize[i]);
        if ((i & 7) == 7 && i < _tysize.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
    {   _tyrelax[typetab[i].ty] = typetab[i].relty;
        /*printf("_tyrelax[%d] = %d\n",typetab[i].ty,typetab[i].relty);*/
    }
    fprintf(f,"__gshared ubyte[TYMAX] _tyrelax =\n[ ");
    for (i = 0; i < _tyrelax.length; i++)
    {   fprintf(f,"0x%02x,",_tyrelax[i]);
        if ((i & 7) == 7 && i < _tyrelax.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    /********** tyequiv ************/
    for (i = 0; i < _tyequiv.length; i++)
        _tyequiv[i] = i;
    _tyequiv[TYchar] = TYschar;         /* chars are signed by default  */

    // These values are adjusted in util_set32() for 32 bit ints
    _tyequiv[TYint] = TYshort;
    _tyequiv[TYuint] = TYushort;

    fprintf(f,"__gshared ubyte[TYMAX] tyequiv =\n[ ");
    for (i = 0; i < _tyequiv.length; i++)
    {   fprintf(f,"0x%02x,",_tyequiv[i]);
        if ((i & 7) == 7 && i < _tyequiv.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
        tystring[typetab[i].ty] = typetab[i].str;
    fprintf(f,"extern (C) __gshared const(char)*[TYMAX] tystring =\n[ ");
    for (i = 0; i < tystring.length; i++)
    {   fprintf(f,"\"%s\",",tystring[i].ptr);
        if ((i & 7) == 7 && i < tystring.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
        dttab[typetab[i].ty] = cast(ubyte)typetab[i].debtyp;
    fprintf(f,"__gshared ubyte[TYMAX] dttab =\n[ ");
    for (i = 0; i < dttab.length; i++)
    {   fprintf(f,"0x%02x,",dttab[i]);
        if ((i & 7) == 7 && i < dttab.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
        dttab4[typetab[i].ty] = cast(ushort)typetab[i].debtyp4;
    fprintf(f,"__gshared ushort[TYMAX] dttab4 =\n[ ");
    for (i = 0; i < dttab4.length; i++)
    {   fprintf(f,"0x%02x,",dttab4[i]);
        if ((i & 7) == 7 && i < dttab4.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    fclose(f);
}
