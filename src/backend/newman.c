// Copyright (C) 1992-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
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
#include        <ctype.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "token.h"
#include        "global.h"
#include        "oper.h"
#include        "el.h"
#include        "type.h"
#include        "filespec.h"

#if NEWMANGLE

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#define BUFIDMAX (2 * IDMAX)

struct Mangle
{
    char buf[BUFIDMAX + 2];

    char *np;                   // index into buf[]

    // Used for compression of redundant znames
    const char *zname[10];
    int znamei;

    type *arg[10];              // argument_replicator
    int argi;                   // number used in arg[]
};

static Mangle mangle;

static int mangle_inuse;

struct MangleInuse
{
    MangleInuse()
    {
#if 0
        assert(mangle_inuse == 0);
        mangle_inuse++;
#endif
    }

    ~MangleInuse()
    {
#if 0
        assert(mangle_inuse == 1);
        mangle_inuse--;
#endif
    }
};

/* Names for special variables  */
char cpp_name_new[]     = "?2";
char cpp_name_delete[]  = "?3";
char cpp_name_anew[]    = "?_P";
char cpp_name_adelete[] = "?_Q";
char cpp_name_ct[]      = "?0";
char cpp_name_dt[]      = "?1";
char cpp_name_as[]      = "?4";
char cpp_name_vc[]      = "?_H";
char cpp_name_primdt[]  = "?_D";
char cpp_name_scaldeldt[] = "?_G";
char cpp_name_priminv[] = "?_R";

STATIC int cpp_cvidx ( tym_t ty );
STATIC int cpp_protection ( symbol *s );
STATIC void cpp_decorated_name ( symbol *s );
STATIC void cpp_symbol_name ( symbol *s );
STATIC void cpp_zname ( const char *p );
STATIC void cpp_scope ( symbol *s );
STATIC void cpp_type_encoding ( symbol *s );
STATIC void cpp_external_function_type(symbol *s);
STATIC void cpp_external_data_type ( symbol *s );
STATIC void cpp_member_function_type ( symbol *s );
STATIC void cpp_static_member_function_type ( symbol *s );
STATIC void cpp_static_member_data_type ( symbol *s );
STATIC void cpp_local_static_data_type ( symbol *s );
STATIC void cpp_vftable_type(symbol *s);
STATIC void cpp_adjustor_thunk_type(symbol *s);
STATIC void cpp_function_type ( type *t );
STATIC void cpp_throw_types ( type *t );
STATIC void cpp_ecsu_name ( symbol *s );
STATIC void cpp_return_type ( symbol *s );
STATIC void cpp_data_type ( type *t );
STATIC void cpp_storage_convention ( symbol *s );
STATIC void cpp_this_type ( type *t,Classsym *s );
STATIC void cpp_vcall_model_type ( void );
STATIC void cpp_calling_convention ( type *t );
STATIC void cpp_argument_types ( type *t );
STATIC void cpp_argument_list ( type *t, int flag );
STATIC void cpp_primary_data_type ( type *t );
STATIC void cpp_reference_type ( type *t );
STATIC void cpp_pointer_type ( type *t );
STATIC void cpp_ecsu_data_indirect_type ( type *t );
STATIC void cpp_data_indirect_type ( type *t );
STATIC void cpp_function_indirect_type ( type *t );
STATIC void cpp_basic_data_type ( type *t );
STATIC void cpp_ecsu_data_type(type *t);
STATIC void cpp_pointer_data_type ( type *t );
STATIC void cpp_reference_data_type ( type *t, int flag );
STATIC void cpp_enum_name ( symbol *s );
STATIC void cpp_dimension ( targ_ullong u );
STATIC void cpp_dimension_ld ( targ_ldouble ld );
STATIC void cpp_string ( char *s, size_t len );

/****************************
 */

struct OPTABLE
#if MARS
{
    unsigned char tokn;
    unsigned char oper;
    char *string;
    char *pretty;
}
#endif
 oparray[] = {
    {   TKnew, OPnew,           cpp_name_new,   "new" },
    {   TKdelete, OPdelete,     cpp_name_delete,"del" },
    {   TKadd, OPadd,           "?H",           "+" },
    {   TKadd, OPuadd,          "?H",           "+" },
    {   TKmin, OPmin,           "?G",           "-" },
    {   TKmin, OPneg,           "?G",           "-" },
    {   TKstar, OPmul,          "?D",           "*" },
    {   TKstar, OPind,          "?D",           "*" },
    {   TKdiv, OPdiv,           "?K",           "/" },
    {   TKmod, OPmod,           "?L",           "%" },
    {   TKxor, OPxor,           "?T",           "^" },
    {   TKand, OPand,           "?I",           "&" },
    {   TKand, OPaddr,          "?I",           "&" },
    {   TKor, OPor,             "?U",           "|" },
    {   TKcom, OPcom,           "?S",           "~" },
    {   TKnot, OPnot,           "?7",           "!" },
    {   TKeq, OPeq,             cpp_name_as,    "=" },
    {   TKeq, OPstreq,          "?4",           "=" },
    {   TKlt, OPlt,             "?M",           "<" },
    {   TKgt, OPgt,             "?O",           ">" },
    {   TKnew, OPanew,          cpp_name_anew,  "n[]" },
    {   TKdelete, OPadelete,    cpp_name_adelete,"d[]" },
    {   TKunord, OPunord,       "?_S",          "!<>=" },
    {   TKlg, OPlg,             "?_T",          "<>"   },
    {   TKleg, OPleg,           "?_U",          "<>="  },
    {   TKule, OPule,           "?_V",          "!>"   },
    {   TKul, OPul,             "?_W",          "!>="  },
    {   TKuge, OPuge,           "?_X",          "!<"   },
    {   TKug, OPug,             "?_Y",          "!<="  },
    {   TKue, OPue,             "?_Z",          "!<>"  },
    {   TKaddass, OPaddass,     "?Y",           "+=" },
    {   TKminass, OPminass,     "?Z",           "-=" },
    {   TKmulass, OPmulass,     "?X",           "*=" },
    {   TKdivass, OPdivass,     "?_0",          "/=" },
    {   TKmodass, OPmodass,     "?_1",          "%=" },
    {   TKxorass, OPxorass,     "?_6",          "^=" },
    {   TKandass, OPandass,     "?_4",          "&=" },
    {   TKorass, OPorass,       "?_5",          "|=" },
    {   TKshl, OPshl,           "?6",           "<<" },
    {   TKshr, OPshr,           "?5",           ">>" },
    {   TKshrass, OPshrass,     "?_2",          ">>=" },
    {   TKshlass, OPshlass,     "?_3",          "<<=" },
    {   TKeqeq, OPeqeq,         "?8",           "==" },
    {   TKne, OPne,             "?9",           "!=" },
    {   TKle, OPle,             "?N",           "<=" },
    {   TKge, OPge,             "?P",           ">=" },
    {   TKandand, OPandand,     "?V",           "&&" },
    {   TKoror, OPoror,         "?W",           "||" },
    {   TKplpl, OPpostinc,      "?E",           "++" },
    {   TKplpl, OPpreinc,       "?E",           "++" },
    {   TKmimi, OPpostdec,      "?F",           "--" },
    {   TKmimi, OPpredec,       "?F",           "--" },
    {   TKlpar, OPcall,         "?R",           "()" },
    {   TKlbra, OPbrack,        "?A",           "[]" },
    {   TKarrow, OParrow,       "?C",           "->" },
    {   TKcomma, OPcomma,       "?Q",           "," },
    {   TKarrowstar, OParrowstar, "?J",         "->*" },
};

/****************************************
 * Convert from identifier to operator
 */
#if SCPP

#if __GNUC__    // NOT DONE - FIX
char * unmangle_pt(const char **s)
{
    return (char *)*s;
}
#else
#if __cplusplus
extern "C"
#endif
        char * __cdecl unmangle_pt(const char **);

#endif

char *cpp_unmangleident(const char *p)
{   int i;
    MangleInuse m;

    //printf("cpp_unmangleident('%s')\n", p);
    if (*p == '$')              // if template name
    {   char *s;
        const char *q;

    L1:
        q = p;
        s = unmangle_pt(&q);
        if (s)
        {   if (strlen(s) <= BUFIDMAX)
                p = strcpy(mangle.buf, s);
            free(s);
        }
    }
    else if (*p == '?')         // if operator name
    {   int i;

        if (NEWTEMPMANGLE && p[1] == '$')       // if template name
            goto L1;
        for (i = 0; i < arraysize(oparray); i++)
        {   if (strcmp(p,oparray[i].string) == 0)
            {   char *s;

                strcpy(mangle.buf, "operator ");
                switch (oparray[i].oper)
                {   case OPanew:
                        s = "new[]";
                        break;
                    case OPadelete:
                        s = "delete[]";
                        break;
                    case OPdelete:
                        s = "delete";
                        break;
                    default:
                        s = oparray[i].pretty;
                        break;
                }
                strcat(mangle.buf,s);
                p = mangle.buf;
                break;
            }
        }
    }
    //printf("-cpp_unmangleident() = '%s'\n", p);
    return (char *)p;
}
#endif

/****************************************
 * Find index in oparray[] for operator.
 * Returns:
 *      index or -1 if not found
 */

#if SCPP

int cpp_opidx(int op)
{   int i;

    for (i = 0; i < arraysize(oparray); i++)
        if (oparray[i].oper == op)
            return i;
    return -1;
}

#endif

/***************************************
 * Find identifier string associated with operator.
 * Returns:
 *      NULL if not found
 */

#if SCPP

char *cpp_opident(int op)
{   int i;

    i = cpp_opidx(op);
    return (i == -1) ? NULL : oparray[i].string;
}

#endif

/**********************************
 * Convert from operator token to name.
 * Output:
 *      *poper  OPxxxx
 *      *pt     set to type for user defined conversion
 * Returns:
 *      pointer to corresponding name
 */

#if SCPP

char *cpp_operator(int *poper,type **pt)
{
    int i;
    type *typ_spec;
    char *s;

    *pt = NULL;
    stoken();                           /* skip over operator keyword   */
    for (i = 0; i < arraysize(oparray); i++)
    {   if (oparray[i].tokn == tok.TKval)
            goto L1;
    }

    /* Look for type conversion */
    if (type_specifier(&typ_spec))
    {   type *t;

        t = ptr_operator(typ_spec);     // parse ptr-operator
        fixdeclar(t);
        type_free(typ_spec);
        *pt = t;
        return cpp_typetostring(t,"?B");
    }

    cpperr(EM_not_overloadable);        // that token cannot be overloaded
    s = "_";
    goto L2;

L1:
    s = oparray[i].string;
    *poper = oparray[i].oper;
    switch (*poper)
    {   case OPcall:
            if (stoken() != TKrpar)
                synerr(EM_rpar);                /* ')' expected                 */
            break;

        case OPbrack:
            if (stoken() != TKrbra)
                synerr(EM_rbra);                /* ']' expected                 */
            break;

        case OPnew:
            if (stoken() != TKlbra)
                goto Lret;
            *poper = OPanew;            // operator new[]
            s = cpp_name_anew;
            goto L3;

        case OPdelete:
            if (stoken() != TKlbra)
                goto Lret;
            *poper = OPadelete;         // operator delete[]
            s = cpp_name_adelete;
        L3:
            if (stoken() != TKrbra)
                synerr(EM_rbra);                // ']' expected
            if (!(config.flags4 & CFG4anew))
            {   cpperr(EM_enable_anew);         // throw -Aa to support this
                config.flags4 |= CFG4anew;
            }
            break;
    }
L2:
    stoken();
Lret:
    return s;
}

/******************************************
 * Alternate version that works on a list of token's.
 * Input:
 *      to      list of tokens
 * Output:
 *      *pcastoverload  1 if user defined type conversion
 */

char *cpp_operator2(token_t *to, int *pcastoverload)
{
    int i;
    char *s;
    token_t *tn;
    int oper;

    *pcastoverload = 0;
    if (!to || !to->TKnext)
        return NULL;

    for (i = 0; i < arraysize(oparray); i++)
    {
        //printf("[%d] %d, %d\n", i, oparray[i].tokn, tok.TKval);
        if (oparray[i].tokn == to->TKval)
            goto L1;
    }

    //printf("cpp_operator2(): castoverload\n");
    *pcastoverload = 1;
    return NULL;

L1:
    tn = to->TKnext;
    s = oparray[i].string;
    oper = oparray[i].oper;
    switch (oper)
    {   case OPcall:
            if (tn->TKval != TKrpar)
                synerr(EM_rpar);        // ')' expected
            break;

        case OPbrack:
            if (tn->TKval != TKrbra)
                synerr(EM_rbra);        // ']' expected
            break;

        case OPnew:
            if (tn->TKval != TKlbra)
                break;
            oper = OPanew;              // operator new[]
            s = cpp_name_anew;
            goto L3;

        case OPdelete:
            if (tn->TKval != TKlbra)
                break;
            oper = OPadelete;           // operator delete[]
            s = cpp_name_adelete;
        L3:
            if (tn->TKval != TKrbra)
                synerr(EM_rbra);                // ']' expected
            if (!(config.flags4 & CFG4anew))
            {   cpperr(EM_enable_anew);         // throw -Aa to support this
                config.flags4 |= CFG4anew;
            }
            break;
    }
Lret:
    return s;
}

#endif

/***********************************
 * Generate and return a pointer to a string constructed from
 * the type, appended to the prefix.
 * Since these generated strings determine the uniqueness of names,
 * they are also used to determine if two types are the same.
 * Returns:
 *      pointer to static name[]
 */

char *cpp_typetostring(type *t,char *prefix)
{   int i;

    if (prefix)
    {   strcpy(mangle.buf,prefix);
        i = strlen(prefix);
    }
    else
        i = 0;
    //dbg_printf("cpp_typetostring:\n");
    //type_print(t);
    MangleInuse m;
    mangle.znamei = 0;
    mangle.argi = 0;
    mangle.np = mangle.buf + i;
    mangle.buf[BUFIDMAX + 1] = 0x55;
    cpp_data_type(t);
    *mangle.np = 0;                     // 0-terminate mangle.buf[]
    //dbg_printf("cpp_typetostring: '%s'\n", mangle.buf);
    assert(strlen(mangle.buf) <= BUFIDMAX);
    assert(mangle.buf[BUFIDMAX + 1] == 0x55);
    return mangle.buf;
}

/********************************
 * 'Mangle' a name for output.
 * Returns:
 *      pointer to mangled name (a static buffer)
 */

char *cpp_mangle(symbol *s)
{
    symbol_debug(s);
    //printf("cpp_mangle(s = %p, '%s')\n", s, s->Sident);
    //type_print(s->Stype);

#if SCPP
    if (!CPP)
        return symbol_ident(s);
#endif

    if (type_mangle(s->Stype) != mTYman_cpp)
        return symbol_ident(s);
    else
    {
        MangleInuse m;

        mangle.znamei = 0;
        mangle.argi = 0;
        mangle.np = mangle.buf;
        mangle.buf[BUFIDMAX + 1] = 0x55;
        cpp_decorated_name(s);
        *mangle.np = 0;                 // 0-terminate cpp_name[]
        //dbg_printf("cpp_mangle() = '%s'\n", mangle.buf);
        assert(strlen(mangle.buf) <= BUFIDMAX);
        assert(mangle.buf[BUFIDMAX + 1] == 0x55);
        return mangle.buf;
    }
}

///////////////////////////////////////////////////////

/*********************************
 * Add char into cpp_name[].
 */

STATIC void __inline CHAR(char c)
{
    if (mangle.np < &mangle.buf[BUFIDMAX])
        *mangle.np++ = c;
}

/*********************************
 * Add char into cpp_name[].
 */

STATIC void STR(const char *p)
{
    size_t len;

    len = strlen(p);
    if (mangle.np + len <= &mangle.buf[BUFIDMAX])
    {   memcpy(mangle.np,p,len);
        mangle.np += len;
    }
    else
        for (; *p; p++)
            CHAR(*p);
}

/***********************************
 * Convert const volatile combinations into 0..3
 */

STATIC int cpp_cvidx(tym_t ty)
{   int i;

    i  = (ty & mTYconst) ? 1 : 0;
    i |= (ty & mTYvolatile) ? 2 : 0;
    return i;
}

/******************************
 * Turn protection into 0..2
 */

STATIC int cpp_protection(symbol *s)
{   int i;

    switch (s->Sflags & SFLpmask)
    {   case SFLprivate:        i = 0;  break;
        case SFLprotected:      i = 1;  break;
        case SFLpublic:         i = 2;  break;
        default:
#ifdef DEBUG
            symbol_print(s);
#endif
            assert(0);
    }
    return i;
}

/***********************************
 * Create mangled name for template instantiation.
 */

#if SCPP

char *template_mangle(symbol *s,param_t *arglist)
{
    /*  mangling ::= '$' template_name { type | expr }
        type ::= "T" mangled type
        expr ::= integer | string | address | float | double | long_double
        integer ::= "I" dimension
        string ::= "S" string
        address ::= "R" zname
        float ::= "F" hex_digits
        double ::= "D" hex_digits
        long_double ::= "L" hex_digits
     */
    param_t *p;

    assert(s);
    symbol_debug(s);
    //assert(s->Sclass == SCtemplate);

    //printf("\ntemplate_mangle(s = '%s', arglist = %p)\n", s->Sident, arglist);
    //arglist->print_list();

    MangleInuse m;
    mangle.znamei = 0;
    mangle.argi = 0;
    mangle.np = mangle.buf;
    mangle.buf[BUFIDMAX + 1] = 0x55;

    if (NEWTEMPMANGLE)
        STR("?$");
    else
        CHAR('$');

    // BUG: this is for templates nested inside class scopes.
    // Need to check if it creates names that are properly unmanglable.
    cpp_zname(s->Sident);
    if (s->Sscope)
        cpp_scope(s->Sscope);

    for (p = arglist; p; p = p->Pnext)
    {
        if (p->Ptype)
        {   /* Argument is a type       */
            if (!NEWTEMPMANGLE)
                CHAR('T');
            cpp_argument_list(p->Ptype, 1);
        }
        else if (p->Psym)
        {
            CHAR('V');  // this is a 'class' name, but it should be a 'template' name
            cpp_ecsu_name(p->Psym);
        }
        else
        {   /* Argument is an expression        */
            elem *e = p->Pelem;
            tym_t ty = tybasic(e->ET->Tty);
            char *p;
            char a[2];
            int ni;
            char c;

        L2:
            switch (e->Eoper)
            {   case OPconst:
                    switch (ty)
                    {   case TYfloat:   ni = FLOATSIZE;  c = 'F'; goto L1;
                        case TYdouble_alias:
                        case TYdouble:  ni = DOUBLESIZE; c = 'D'; goto L1;
                        case TYldouble: ni = LNGDBLSIZE; c = 'L'; goto L1;
                        L1:
                            if (NEWTEMPMANGLE)
                                CHAR('$');
                            CHAR(c);
                            p = (char *)&e->EV.Vdouble;
                            while (ni--)
                            {   char c;
#if __GNUC__
                                static char hex[16] =
                                    {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
#else
                                static char hex[16] = "0123456789ABCDEF";
#endif

                                c = *p++;
                                CHAR(hex[c & 15]);
                                CHAR(hex[(c >> 4) & 15]);
                            }
                            break;
                        default:
#ifdef DEBUG
                            if (!tyintegral(ty) && !tymptr(ty))
                                elem_print(e);
#endif
                            assert(tyintegral(ty) || tymptr(ty));
                            if (NEWTEMPMANGLE)
                                STR("$0");
                            else
                                CHAR('I');
                            cpp_dimension(el_tolongt(e));
                            break;
                    }
                    break;
                case OPstring:
                    if (NEWTEMPMANGLE)
                        STR("$S");
                    else
                        CHAR('S');
                    if (e->EV.ss.Voffset)
                        synerr(EM_const_init);          // constant initializer expected
                    cpp_string(e->EV.ss.Vstring,e->EV.ss.Vstrlen);
                    break;
                case OPrelconst:
                    if (e->EV.sp.Voffset)
                        synerr(EM_const_init);          // constant initializer expected
                    s = e->EV.sp.Vsym;
                    if (NEWTEMPMANGLE)
                    {   STR("$1");
                        cpp_decorated_name(s);
                    }
                    else
                    {   CHAR('R');
                        cpp_zname(s->Sident);
                    }
                    break;
                case OPvar:
                    if (e->EV.sp.Vsym->Sflags & SFLvalue &&
                        tybasic(e->ET->Tty) != TYstruct)
                    {
                        e = e->EV.sp.Vsym->Svalue;
                        goto L2;
                    }
                    else if (e->EV.sp.Vsym->Sclass == SCconst /*&&
                             pstate.STintemplate*/)
                    {
                        CHAR('V');              // pretend to be a class name
                        cpp_zname(e->EV.sp.Vsym->Sident);
                        break;
                    }
                default:
#if SCPP
#ifdef DEBUG
                    if (!errcnt)
                        elem_print(e);
#endif
                    synerr(EM_const_init);              // constant initializer expected
                    assert(errcnt);
#endif
                    break;
            }
        }
    }
    *mangle.np = 0;
    //printf("template_mangle() = '%s'\n", mangle.buf);
    assert(strlen(mangle.buf) <= BUFIDMAX);
    assert(mangle.buf[BUFIDMAX + 1] == 0x55);
    return mangle.buf;
}

#endif

//////////////////////////////////////////////////////
// Functions corresponding to the name mangling grammar in the
// "Microsoft Object Mapping Specification"

STATIC void cpp_string(char *s,size_t len)
{   char c;

    for (; --len; s++)
    {   static char special_char[] = ",/\\:. \n\t'-";
        char *p;

        c = *s;
        if (c & 0x80 && isalpha(c & 0x7F))
        {   CHAR('?');
            c &= 0x7F;
        }
        else if (isalnum(c))
            ;
        else
        {
            CHAR('?');
            if ((p = (char *)strchr(special_char,c)) != NULL)
                c = '0' + (p - special_char);
            else
            {
                CHAR('$');
                CHAR('A' + ((c >> 4) & 0x0F));
                c = 'A' + (c & 0x0F);
            }
        }
        CHAR(c);
    }
    CHAR('@');
}

STATIC void cpp_dimension(targ_ullong u)
{
    if (u && u <= 10)
        CHAR('0' + (char)u - 1);
    else
    {   char buffer[sizeof(u) * 2 + 1];
        char __ss *p;

        buffer[sizeof(buffer) - 1] = 0;
        for (p = &buffer[sizeof(buffer) - 1]; u; u >>= 4)
        {
            *--p = 'A' + (u & 0x0F);
        }
        STR(p);
        CHAR('@');
    }
}

#if 0
STATIC void cpp_dimension_ld(targ_ldouble ld)
{   unsigned char ldbuf[sizeof(targ_ldouble)];

    memcpy(ldbuf,&ld,sizeof(ld));
    if (u && u <= 10)
        CHAR('0' + (char)u - 1);
    else
    {   char buffer[sizeof(u) * 2 + 1];
        char __ss *p;

        buffer[sizeof(buffer) - 1] = 0;
        for (p = &buffer[sizeof(buffer) - 1]; u; u >>= 4)
        {
            *--p = 'A' + (u & 0x0F);
        }
        STR(p);
        CHAR('@');
    }
}
#endif

STATIC void cpp_enum_name(symbol *s)
{   type *t;
    char c;

    t = tsint;
    switch (tybasic(t->Tty))
    {
        case TYschar:   c = '0';        break;
        case TYuchar:   c = '1';        break;
        case TYshort:   c = '2';        break;
        case TYushort:  c = '3';        break;
        case TYint:     c = '4';        break;
        case TYuint:    c = '5';        break;
        case TYlong:    c = '6';        break;
        case TYulong:   c = '7';        break;
        default:        assert(0);
    }
    CHAR(c);
    cpp_ecsu_name(s);
}

STATIC void cpp_reference_data_type(type *t, int flag)
{
    if (tybasic(t->Tty) == TYarray)
    {
        int ndim;
        type *tn;
        int i;

        CHAR('Y');

        // Compute number of dimensions (we have at least one)
        ndim = 0;
        tn = t;
        do
        {   ndim++;
            tn = tn->Tnext;
        } while (tybasic(tn->Tty) == TYarray);

        cpp_dimension(ndim);
        for (; tybasic(t->Tty) == TYarray; t = t->Tnext)
        {
            if (t->Tflags & TFvla)
                CHAR('X');                      // DMC++ extension
            else
                cpp_dimension(t->Tdim);
        }

        // DMC++ extension
        if (flag)                       // if template type argument
        {
            i = cpp_cvidx(t->Tty);
            if (i)
            {   CHAR('_');
                //CHAR('X' + i - 1);            // _X, _Y, _Z
                CHAR('O' + i - 1);              // _O, _P, _Q
            }
        }

        cpp_basic_data_type(t);
    }
    else
        cpp_basic_data_type(t);
}

STATIC void cpp_pointer_data_type(type *t)
{
    if (tybasic(t->Tty) == TYvoid)
        CHAR('X');
    else
        cpp_reference_data_type(t, 0);
}

STATIC void cpp_ecsu_data_type(type *t)
{   char c;
    symbol *stag;
    int i;

    type_debug(t);
    switch (tybasic(t->Tty))
    {
        case TYstruct:
            stag = t->Ttag;
            switch (stag->Sstruct->Sflags & (STRclass | STRunion))
            {   case 0:         c = 'U';        break;
                case STRunion:  c = 'T';        break;
                case STRclass:  c = 'V';        break;
                default:
                    assert(0);
            }
            CHAR(c);
            cpp_ecsu_name(stag);
            break;
        case TYenum:
            CHAR('W');
            cpp_enum_name(t->Ttag);
            break;
        default:
#ifdef DEBUG
            type_print(t);
#endif
            assert(0);
    }
}

STATIC void cpp_basic_data_type(type *t)
{   char c;
    int i;

    //printf("cpp_basic_data_type(t)\n");
    //type_print(t);
    switch (tybasic(t->Tty))
    {
        case TYschar:   c = 'C';        goto dochar;
        case TYchar:    c = 'D';        goto dochar;
        case TYuchar:   c = 'E';        goto dochar;
        case TYshort:   c = 'F';        goto dochar;
        case TYushort:  c = 'G';        goto dochar;
        case TYint:     c = 'H';        goto dochar;
        case TYuint:    c = 'I';        goto dochar;
        case TYlong:    c = 'J';        goto dochar;
        case TYulong:   c = 'K';        goto dochar;
        case TYfloat:   c = 'M';        goto dochar;
        case TYdouble:  c = 'N';        goto dochar;

        case TYdouble_alias:
                        if (intsize == 4)
                        {   c = 'O';
                            goto dochar;
                        }
                        c = 'Z';
                        goto dochar2;

        case TYldouble:
                        if (intsize == 2)
                        {   c = 'O';
                            goto dochar;
                        }
                        c = 'Z';
                        goto dochar2;
        dochar:
            CHAR(c);
            break;

        case TYllong:   c = 'J';        goto dochar2;
        case TYullong:  c = 'K';        goto dochar2;
        case TYbool:    c = 'N';        goto dochar2;   // was 'X' prior to 8.1b8
        case TYwchar_t:
            if (config.flags4 & CFG4nowchar_t)
            {
                c = 'G';
                goto dochar;    // same as TYushort
            }
            else
            {
                pstate.STflags |= PFLmfc;
                c = 'Y';
                goto dochar2;
            }

        // Digital Mars extensions
        case TYifloat:  c = 'R';        goto dochar2;
        case TYidouble: c = 'S';        goto dochar2;
        case TYildouble: c = 'T';       goto dochar2;
        case TYcfloat:  c = 'U';        goto dochar2;
        case TYcdouble: c = 'V';        goto dochar2;
        case TYcldouble: c = 'W';       goto dochar2;

        case TYchar16:   c = 'X';       goto dochar2;
        case TYdchar:    c = 'Y';       goto dochar2;
        case TYnullptr:  c = 'Z';       goto dochar2;

        dochar2:
            CHAR('_');
            goto dochar;

#if TARGET_SEGMENTED
        case TYsptr:
        case TYcptr:
        case TYf16ptr:
        case TYfptr:
        case TYhptr:
        case TYvptr:
#endif
#if !MARS
        case TYmemptr:
#endif
        case TYnptr:
            c = 'P' + cpp_cvidx(t->Tty);
            CHAR(c);
            if(I64)
                CHAR('E'); // __ptr64 modifier
            cpp_pointer_type(t);
            break;
        case TYstruct:
        case TYenum:
            cpp_ecsu_data_type(t);
            break;
        case TYarray:
            i = cpp_cvidx(t->Tty);
            i |= 1;                     // always const
            CHAR('P' + i);
            cpp_pointer_type(t);
            break;
        case TYvoid:
            c = 'X';
            goto dochar;
#if !MARS
        case TYident:
            if (pstate.STintemplate)
            {
                CHAR('V');              // pretend to be a class name
                cpp_zname(t->Tident);
            }
            else
            {
#if SCPP
                cpperr(EM_no_type,t->Tident);   // no type for argument
#endif
                c = 'X';
                goto dochar;
            }
            break;
        case TYtemplate:
            if (pstate.STintemplate)
            {
                CHAR('V');              // pretend to be a class name
                cpp_zname(((typetemp_t *)t)->Tsym->Sident);
            }
            else
                goto Ldefault;
            break;
#endif

        default:
        Ldefault:
            if (tyfunc(t->Tty))
                cpp_function_type(t);
            else
            {
#if SCPP
#ifdef DEBUG
                if (!errcnt)
                    type_print(t);
#endif
                assert(errcnt);
#endif
            }
    }
}

STATIC void cpp_function_indirect_type(type *t)
{   int farfunc;

    farfunc = tyfarfunc(t->Tnext->Tty) != 0;
#if !MARS
    if (tybasic(t->Tty) == TYmemptr)
    {
        CHAR('8' + farfunc);
        cpp_scope(t->Ttag);
        CHAR('@');
        //cpp_this_type(t->Tnext,t->Ttag);      // MSC doesn't do this
    }
    else
#endif
        CHAR('6' + farfunc);
}

STATIC void cpp_data_indirect_type(type *t)
{   int i;
#if !MARS
    if (tybasic(t->Tty) == TYmemptr)    // if pointer to member
    {
        i = cpp_cvidx(t->Tty);
        if (t->Tty & mTYfar)
            i += 4;
        CHAR('Q' + i);
        cpp_scope(t->Ttag);
        CHAR('@');
    }
    else
#endif
        cpp_ecsu_data_indirect_type(t);
}

STATIC void cpp_ecsu_data_indirect_type(type *t)
{   int i;
    tym_t ty;

    i = 0;
    if (t->Tnext)
    {   ty = t->Tnext->Tty & (mTYconst | mTYvolatile);
        switch (tybasic(t->Tty))
        {
#if TARGET_SEGMENTED
            case TYfptr:
            case TYvptr:
            case TYfref:
                ty |= mTYfar;
                break;

            case TYhptr:
                i += 8;
                break;
            case TYref:
            case TYarray:
                if (LARGEDATA && !(ty & mTYLINK))
                    ty |= mTYfar;
                break;
#endif
        }
    }
    else
        ty = t->Tty & (mTYLINK | mTYconst | mTYvolatile);
    i |= cpp_cvidx(ty);
#if TARGET_SEGMENTED
    if (ty & (mTYcs | mTYfar))
        i += 4;
#endif
    CHAR('A' + i);
}

STATIC void cpp_pointer_type(type *t)
{   tym_t ty;

    if (tyfunc(t->Tnext->Tty))
    {
        cpp_function_indirect_type(t);
        cpp_function_type(t->Tnext);
    }
    else
    {
        cpp_data_indirect_type(t);
        cpp_pointer_data_type(t->Tnext);
    }
}

STATIC void cpp_reference_type(type *t)
{
    cpp_data_indirect_type(t);
    cpp_reference_data_type(t->Tnext, 0);
}

STATIC void cpp_primary_data_type(type *t)
{
    if (tyref(t->Tty))
    {
#if 1
        // C++98 8.3.2 says cv-qualified references are ignored
        CHAR('A');
#else
        switch (t->Tty & (mTYconst | mTYvolatile))
        {
            case 0:                      CHAR('A');     break;
            case mTYvolatile:            CHAR('B');     break;

            // Digital Mars extensions
            case mTYconst | mTYvolatile: CHAR('_'); CHAR('L');  break;
            case mTYconst:               CHAR('_'); CHAR('M');  break;
        }
#endif
        cpp_reference_type(t);
    }
    else
        cpp_basic_data_type(t);
}

/*****
 * flag: 1 = template argument
 */

STATIC void cpp_argument_list(type *t, int flag)
{   int i;
    tym_t ty;

    //printf("cpp_argument_list(flag = %d)\n", flag);
    // If a data type that encodes only into one character
    ty = tybasic(t->Tty);
    if (ty <= TYldouble && ty != TYenum
        && ty != TYbool         // added for versions >= 8.1b9
#if OVERLOAD_CV_PARAM
        && !(t->Tty & (mTYconst | mTYvolatile))
#endif
       )
    {
        cpp_primary_data_type(t);
    }
    else
    {
        // See if a match with a previously used type
        for (i = 0; 1; i++)
        {
            if (i == mangle.argi)               // no match
            {
#if OVERLOAD_CV_PARAM
                if (ty <= TYcldouble || ty == TYstruct)
                {
                    int cvidx = cpp_cvidx(t->Tty);
                    if (cvidx)
                    {
                        // Digital Mars extensions
                        CHAR('_');
                        CHAR('N' + cvidx);      // _O, _P, _Q prefix
                    }
                }
#endif
                if (flag && tybasic(t->Tty) == TYarray)
                {
                   cpp_reference_data_type(t, flag);
                }
                else
                    cpp_primary_data_type(t);
                if (mangle.argi < 10)
                    mangle.arg[mangle.argi++] = t;
                break;
            }
            if (typematch(t,mangle.arg[i],0))
            {
                CHAR('0' + i);          // argument_replicator
                break;
            }
        }
    }
}

STATIC void cpp_argument_types(type *t)
{   param_t *p;
    char c;

    //printf("cpp_argument_types()\n");
    //type_debug(t);
    for (p = t->Tparamtypes; p; p = p->Pnext)
        cpp_argument_list(p->Ptype, 0);
    if (t->Tflags & TFfixed)
        c = t->Tparamtypes ? '@' : 'X';
    else
        c = 'Z';
    CHAR(c);
}

STATIC void cpp_calling_convention(type *t)
{   char c;

    switch (tybasic(t->Tty))
    {
        case TYnfunc:
        case TYhfunc:
#if TARGET_SEGMENTED
        case TYffunc:
#endif
            c = 'A';        break;
#if TARGET_SEGMENTED
        case TYf16func:
        case TYfpfunc:
#endif
        case TYnpfunc:
            c = 'C';        break;
        case TYnsfunc:
#if TARGET_SEGMENTED
        case TYfsfunc:
#endif
            c = 'G';        break;
        case TYjfunc:
        case TYmfunc:
#if TARGET_SEGMENTED
        case TYnsysfunc:
        case TYfsysfunc:
#endif
            c = 'E';       break;
        case TYifunc:
            c = 'K';        break;
        default:
            assert(0);
    }
    CHAR(c);
}

STATIC void cpp_vcall_model_type()
{
}

#if SCPP || MARS

STATIC void cpp_this_type(type *tfunc,Classsym *stag)
{   type *t;

    type_debug(tfunc);
    symbol_debug(stag);
#if MARS
    t = type_pointer(stag->Stype);
#else
    t = cpp_thistype(tfunc,stag);
#endif
    //cpp_data_indirect_type(t);
    cpp_ecsu_data_indirect_type(t);
    type_free(t);
}

#endif

STATIC void cpp_storage_convention(symbol *s)
{   tym_t ty;
    type *t = s->Stype;

    ty = t->Tty;
#if TARGET_SEGMENTED
    if (LARGEDATA && !(ty & mTYLINK))
        t->Tty |= mTYfar;
#endif
    cpp_data_indirect_type(t);
    t->Tty = ty;
}

STATIC void cpp_data_type(type *t)
{
    type_debug(t);
    switch (tybasic(t->Tty))
    {   case TYvoid:
            CHAR('X');
            break;
        case TYstruct:
        case TYenum:
            CHAR('?');
            cpp_ecsu_data_indirect_type(t);
            cpp_ecsu_data_type(t);
            break;
        default:
            cpp_primary_data_type(t);
            break;
    }
}

STATIC void cpp_return_type(symbol *s)
{
    if (s->Sfunc->Fflags & (Fctor | Fdtor))     // if ctor or dtor
        CHAR('@');                              // no type
    else
        cpp_data_type(s->Stype->Tnext);
}

STATIC void cpp_ecsu_name(symbol *s)
{
    //printf("cpp_ecsu_name(%s)\n", symbol_ident(s));
    cpp_zname(symbol_ident(s));
#if SCPP || MARS
    if (s->Sscope)
        cpp_scope(s->Sscope);
#endif
    CHAR('@');
}

STATIC void cpp_throw_types(type *t)
{
    //cpp_argument_types(?);
    CHAR('Z');
}

STATIC void cpp_function_type(type *t)
{   tym_t ty;
    type *tn;

    //printf("cpp_function_type()\n");
    //type_debug(t);
    assert(tyfunc(t->Tty));
    cpp_calling_convention(t);
    //cpp_return_type(s);
    tn = t->Tnext;
    ty = tn->Tty;
#if TARGET_SEGMENTED
    if (LARGEDATA && (tybasic(ty) == TYstruct || tybasic(ty) == TYenum) &&
        !(ty & mTYLINK))
        tn->Tty |= mTYfar;
#endif
    cpp_data_type(tn);
    tn->Tty = ty;
    cpp_argument_types(t);
    cpp_throw_types(t);
}

STATIC void cpp_adjustor_thunk_type(symbol *s)
{
}

STATIC void cpp_vftable_type(symbol *s)
{
    cpp_ecsu_data_indirect_type(s->Stype);
//      vpath_name();
    CHAR('@');
}

STATIC void cpp_local_static_data_type(symbol *s)
{
    //cpp_lexical_frame(?);
    cpp_external_data_type(s);
}

STATIC void cpp_static_member_data_type(symbol *s)
{
    cpp_external_data_type(s);
}

STATIC void cpp_static_member_function_type(symbol *s)
{
    cpp_function_type(s->Stype);
}

#if SCPP || MARS
STATIC void cpp_member_function_type(symbol *s)
{
    assert(tyfunc(s->Stype->Tty));
    cpp_this_type(s->Stype,(Classsym *)s->Sscope);
    if (s->Sfunc->Fflags & (Fctor | Fdtor))
    {   type *t = s->Stype;

        cpp_calling_convention(t);
        CHAR('@');                      // return_type for ctors & dtors
        cpp_argument_types(t);
        cpp_throw_types(t);
    }
    else
        cpp_static_member_function_type(s);
}
#endif

STATIC void cpp_external_data_type(symbol *s)
{
    cpp_primary_data_type(s->Stype);
    cpp_storage_convention(s);
}

STATIC void cpp_external_function_type(symbol *s)
{
    cpp_function_type(s->Stype);
}

STATIC void cpp_type_encoding(symbol *s)
{   char c;

    //printf("cpp_type_encoding()\n");
    if (tyfunc(s->Stype->Tty))
    {   int farfunc;

        farfunc = tyfarfunc(s->Stype->Tty) != 0;
#if SCPP || MARS
        if (isclassmember(s))
        {   // Member function
            int protection;
            int ftype;

            protection = cpp_protection(s);
            if (s->Sfunc->Fthunk && !(s->Sfunc->Fflags & Finstance))
                ftype = 3;
            else
                switch (s->Sfunc->Fflags & (Fvirtual | Fstatic))
                {   case Fvirtual:      ftype = 2;      break;
                    case Fstatic:       ftype = 1;      break;
                    case 0:             ftype = 0;      break;
                    default:            assert(0);
                }
            CHAR('A' + farfunc + protection * 8 + ftype * 2);
            switch (ftype)
            {   case 0: cpp_member_function_type(s);            break;
                case 1: cpp_static_member_function_type(s);     break;
                case 2: cpp_member_function_type(s);            break;
                case 3: cpp_adjustor_thunk_type(s);             break;
            }
        }
        else
#endif
        {   // Non-member function
            CHAR('Y' + farfunc);
            cpp_external_function_type(s);
        }
    }
    else
    {
#if SCPP || MARS
        if (isclassmember(s))
        {
            {   // Static data member
                CHAR(cpp_protection(s) + '0');
                cpp_static_member_data_type(s);
            }
        }
        else
#endif
        {
            if (s->Sclass == SCstatic
#if SCPP || MARS
                || (s->Sscope &&
                 s->Sscope->Sclass != SCstruct &&
                 s->Sscope->Sclass != SCnamespace)
#endif
                )
            {   CHAR('4');
                cpp_local_static_data_type(s);
            }
            else
            {   CHAR('3');
                cpp_external_data_type(s);
            }
        }
    }
}

STATIC void cpp_scope(symbol *s)
{
    /*  scope ::=
                zname [ scope ]
                '?' decorated_name [ scope ]
                '?' lexical_frame [ scope ]
                '?' '$' template_name [ scope ]
     */
    while (s)
    {   char *p;

        symbol_debug(s);
        switch (s->Sclass)
        {
            case SCnamespace:
                cpp_zname(s->Sident);
                break;

            case SCstruct:
                cpp_zname(symbol_ident(s));
                break;

            default:
                STR("?1?");                     // Why? Who knows.
                cpp_decorated_name(s);
                break;
        }
#if SCPP || MARS
        s = s->Sscope;
#else
        break;
#endif
    }
}

STATIC void cpp_zname(const char *p)
{
    //printf("cpp_zname(%s)\n", p);
    if (*p != '?' ||                            // if not operator_name
        (NEWTEMPMANGLE && p[1] == '$'))         // ?$ is a template name
    {
#if MARS
        /* Scan forward past any dots
         */
        for (const char *q = p; *q; q++)
        {
            if (*q == '.')
                p = q + 1;
        }
#endif

        for (int i = 0; i < mangle.znamei; i++)
        {
            if (strcmp(p,mangle.zname[i]) == 0)
            {   CHAR('0' + i);
                return;
            }
        }
        if (mangle.znamei < 10)
            mangle.zname[mangle.znamei++] = p;
        STR(p);
        CHAR('@');
    }
    else if (p[1] == 'B')
        STR("?B");                      // skip return value encoding
    else
    {
        STR(p);
    }
}

STATIC void cpp_symbol_name(symbol *s)
{   char *p;

    p = s->Sident;
#if SCPP
    if (tyfunc(s->Stype->Tty) && s->Sfunc)
    {
        if (s->Sfunc->Fflags & Finstance)
        {
            Mangle save = mangle;
            char *q;
            int len;

            p = template_mangle(s, s->Sfunc->Fptal);
            len = strlen(p);
            q = (char *)alloca(len + 1);
            memcpy(q, p, len + 1);
            mangle = save;
            p = q;
        }
        else if (s->Sfunc->Fflags & Foperator)
        {   // operator_name ::= '?' operator_code
            //CHAR('?');                        // already there
            STR(p);
            return;
        }
    }
#endif
#if MARS && 0
    //It mangles correctly, but the ABI doesn't match,
    // leading to copious segfaults. At least with the
    // wrong mangling you get link errors.
    if (tyfunc(s->Stype->Tty) && s->Sfunc)
    {
        if (s->Sfunc->Fflags & Fctor)
        {
            cpp_zname(cpp_name_ct);
            return;
        }
        if (s->Sfunc->Fflags & Fdtor)
        {
            cpp_zname(cpp_name_dt);
            return;
        }
    }
#endif
    cpp_zname(p);
}

STATIC void cpp_decorated_name(symbol *s)
{   char *p;

    CHAR('?');
    cpp_symbol_name(s);
#if SCPP || MARS
    if (s->Sscope)
        cpp_scope(s->Sscope);
#endif
    CHAR('@');
    cpp_type_encoding(s);
}

/*********************************
 * Mangle a vtbl or vbtbl name.
 * Returns:
 *      pointer to generated symbol with mangled name
 */

#if SCPP

symbol *mangle_tbl(
        int flag,       // 0: vtbl, 1: vbtbl
        type *t,        // type for symbol
        Classsym *stag, // class we're putting tbl in
        baseclass_t *b) // base class (NULL if none)
{   const char *id;
    symbol *s;

#if 0
    dbg_printf("mangle_tbl(stag = '%s', sbase = '%s', parent = '%s')\n",
        stag->Sident,b ? b->BCbase->Sident : "NULL", b ? b->parent->Sident : "NULL");
#endif
    if (flag == 0)
        id = config.flags3 & CFG3rtti ? "?_Q" : "?_7";
    else
        id = "?_8";
    MangleInuse m;
    mangle.znamei = 0;
    mangle.argi = 0;
    mangle.np = mangle.buf;
    CHAR('?');
    cpp_zname(id);
    cpp_scope(stag);
    CHAR('@');
    CHAR('6' + flag);
    cpp_ecsu_data_indirect_type(t);
#if 1
    while (b)
    {
        cpp_scope(b->BCbase);
        CHAR('@');
        b = b->BCpbase;
    }
#else
    if (b)
    {   cpp_scope(b->BCbase);
        CHAR('@');
        // BUG: what if b is more than one level down?
        if (b->parent != stag)
        {   cpp_scope(b->BCparent);
            CHAR('@');
        }
    }
#endif
    CHAR('@');
    *mangle.np = 0;                     // 0-terminate mangle.buf[]
    assert(strlen(mangle.buf) <= BUFIDMAX);
    s = scope_define(mangle.buf,SCTglobal | SCTnspace | SCTlocal,SCunde);
    s->Stype = t;
    t->Tcount++;
    return s;
}

#endif

#endif

#endif
