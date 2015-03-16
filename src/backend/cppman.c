// Copyright (C) 1987-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/* C++ name mangling routines                           */

#include        <stdio.h>
#include        <ctype.h>
#include        <string.h>
#include        "cc.h"

#if !NEWMANGLE

#define NEW_UNMANGLER   1

#include        "parser.h"
#include        "token.h"
#include        "global.h"
#include        "oper.h"
#include        "el.h"
#include        "type.h"
#include        "cpp.h"
#include        "filespec.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

//char *cpp_name = NULL;
char cpp_name[2 * IDMAX + 1] = { 0 };

/* Names for special variables  */
char cpp_name_new[]     = "__nw";
char cpp_name_delete[]  = "__dl";
char cpp_name_ct[]      = "__ct";
char cpp_name_dt[]      = "__dt";
char cpp_name_as[]      = "__as";
char cpp_name_vc[]      = "__vc";
char cpp_name_primdt[]  = "__pd";
char cpp_name_scaldeldt[]       = "__sd";
static symbol *ssymbol;

/****************************
 */

struct OPTABLE oparray[] =
{
    {   TKnew, OPnew,           cpp_name_new,   "new" },
    {   TKdelete, OPdelete,     cpp_name_delete,"del" },
    {   TKadd, OPadd,           "__pl",         "+" },
    {   TKadd, OPuadd,          "__pl",         "+" },
    {   TKmin, OPmin,           "__mi",         "-" },
    {   TKmin, OPneg,           "__mi",         "-" },
    {   TKstar, OPmul,          "__ml",         "*" },
    {   TKstar, OPind,          "__ml",         "*" },
    {   TKdiv, OPdiv,           "__dv",         "/" },
    {   TKmod, OPmod,           "__md",         "%" },
    {   TKxor, OPxor,           "__er",         "^" },
    {   TKand, OPand,           "__ad",         "&" },
    {   TKand, OPaddr,          "__ad",         "&" },
    {   TKor, OPor,             "__or",         "|" },
    {   TKcom, OPcom,           "__co",         "~" },
    {   TKnot, OPnot,           "__nt",         "!" },
    {   TKeq, OPeq,             "__as",         "=" },
    {   TKeq, OPstreq,          "__as",         "=" },
    {   TKlt, OPlt,             "__lt",         "<" },
    {   TKgt, OPgt,             "__gt",         ">" },
    {   TKunord, OPunord,       "__uno",        "!<>=" },
    {   TKlg, OPlg,             "__lg",         "<>"   },
    {   TKleg, OPleg,           "__leg",        "<>="  },
    {   TKule, OPule,           "__ule",        "!>"   },
    {   TKul, OPul,             "__ul",         "!>="  },
    {   TKuge, OPuge,           "__uge",        "!<"   },
    {   TKug, OPug,             "__ug",         "!<="  },
    {   TKue, OPue,             "__ue",         "!<>"  },
    {   TKaddass, OPaddass,     "__apl",        "+=" },
    {   TKminass, OPminass,     "__ami",        "-=" },
    {   TKmulass, OPmulass,     "__amu",        "*=" },
    {   TKdivass, OPdivass,     "__adv",        "/=" },
    {   TKmodass, OPmodass,     "__amd",        "%=" },
    {   TKxorass, OPxorass,     "__aer",        "^=" },
    {   TKandass, OPandass,     "__aad",        "&=" },
    {   TKorass, OPorass,       "__aor",        "|=" },
    {   TKshl, OPshl,           "__ls",         "<<" },
    {   TKshr, OPshr,           "__rs",         ">>" },
    {   TKshrass, OPshrass,     "__ars",        "<<=" },
    {   TKshlass, OPshlass,     "__als",        ">>=" },
    {   TKeqeq, OPeqeq,         "__eq",         "==" },
    {   TKne, OPne,             "__ne",         "!=" },
    {   TKle, OPle,             "__le",         "<=" },
    {   TKge, OPge,             "__ge",         ">=" },
    {   TKandand, OPandand,     "__aa",         "&&" },
    {   TKoror, OPoror,         "__oo",         "||" },
    {   TKplpl, OPpostinc,      "__pp",         "++" },
    {   TKplpl, OPpreinc,       "__pp",         "++" },
    {   TKmimi, OPpostdec,      "__mm",         "--" },
    {   TKmimi, OPpredec,       "__mm",         "--" },
    {   TKlpar, OPcall,         "__cl",         "()" },
    {   TKlbra, OPbrack,        "__vc",         "[]" },
    {   TKarrow, OParrow,       "__rf",         "->" },
    {   TKcomma, OPcomma,       "__cm",         "," },
    {   TKarrowstar, OParrowstar, "__rm",       "->*" },
};

/***********************************
 * Cat together two names into a static buffer.
 * n1 can be the same as the static buffer.
 */


char *cpp_catname(char *n1,char *n2)
{
    static char cpp_name[IDMAX + 1];

#ifdef DEBUG
    assert(n1 && n2);
#endif
    if (strlen(n1) + strlen(n2) >= sizeof(cpp_name))
    {
#if SCPP
        lexerr(EM_ident2big);           // identifier is too long
#else
        assert(0);
#endif
        cpp_name[0] = 0;
    }
    else
        strcat(strcpy(cpp_name,n1),n2);
    return cpp_name;
}

/***********************************
 * 'Combine' a class and a member name into one name.
 */

char *cpp_genname(char *cl_name,char *mem_name)
{
#if NEWMANGLE
    return cpp_catname(alloca_strdup2(mem_name,cl_name),"@");
#else
    char format[2 + 3 + 1];

    sprintf(format,"__%d",strlen(cl_name));
    return cpp_catname(cpp_catname(mem_name,format),cl_name);
#endif
}

/****************************************
 * Convert from identifier to operator
 */

char *cpp_unmangleident(const char *p)
{   int i;

    for (i = 0; i < arraysize(oparray); i++)
    {   if (strcmp(p,oparray[i].string) == 0)
        {
            strcpy(cpp_name,"operator ");
            strcat(cpp_name,oparray[i].pretty);
            p = cpp_name;
            break;
        }
    }
    return (char *)p;
}

/****************************************
 * Find index in oparray[] for operator.
 * Returns:
 *      index or -1 if not found
 */

int cpp_opidx(int op)
{   int i;

    for (i = 0; i < arraysize(oparray); i++)
        if (oparray[i].oper == (char) op)
            return i;
    return -1;
}

/***************************************
 * Find identifier string associated with operator.
 * Returns:
 *      NULL if not found
 */

char *cpp_opident(int op)
{   int i;

    i = cpp_opidx(op);
    return (i == -1) ? NULL : oparray[i].string;
}

/********************************
 * 'Mangle' a name for output.
 * Returns:
 *      pointer to mangled name (a static buffer)
 */

char *cpp_mangle(symbol *s)
{   char *p;
    symbol *sclass;

    if (!CPP)
        return s->Sident;

    ssymbol = s;

    symbol_debug(s);
    //dbg_printf("cpp_mangle(%s)\n",s->Sident);
    p = symbol_ident(s);
    sclass = s->Sscope;
    if (sclass)
    {   symbol_debug(sclass);
        p = cpp_genname(symbol_ident(sclass),p);
        while (1)
        {
            char format[10 + 1];
            char *cl_name;

            sclass = sclass->Sscope;
            if (!sclass)
                break;

            cl_name = symbol_ident(sclass);
            sprintf(format,"%d",strlen(cl_name));
            p = cpp_catname(cpp_catname(p,format),cl_name);
        }
    }
    type_debug(s->Stype);
    // Function symbols defined statically don't have Sfunc
    if (tyfunc(s->Stype->Tty) &&
    s->Sfunc && s->Sfunc->Fflags & Ftypesafe)
    {   if (!s->Sscope)
            p = cpp_catname(p,"__");
        p = cpp_typetostring(s->Stype,p);
    }
    /*dbg_printf("cpp_mangle(%s)\n",p);*/
    ssymbol = NULL;
    return p;
}

/**********************************
 * Convert from operator token to name.
 * Returns:
 *      pointer to corresponding name
 */

#if SCPP

char *cpp_operator(int *poper,type **pt)
{
    int i;
    type *typ_spec;

    *pt = NULL;
    stoken();                           /* skip over operator keyword   */
    for (i = 0; i < arraysize(oparray); i++)
    {   if (oparray[i].tokn == tok.TKval)
            goto L1;
    }

    /* Look for type conversion */
    if (type_specifier(&typ_spec,NULL ARG_FALSE))
    {   type *t;

        t = ptr_operator(typ_spec);     // parse ptr-operator
        fixdeclar(t);
        type_free(typ_spec);
        *pt = t;
        return cpp_typetostring(t,"__op");
    }

    cpperr(EM_not_overloadable);        // that token cannot be overloaded
    stoken();
    return "_";

L1:
    *poper = oparray[i].oper;
    switch (*poper)
    {   case OPcall:
            if (stoken() != TKrpar)
                synerr(EM_rpar);                /* ')' expected                 */
            break;
        case OPbrack:
            if (stoken() != TKrbra)
                synerrEM_rbra);         /* ']' expected                 */
            break;
    }
    stoken();
    return oparray[i].string;
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
    param_t *p;
    type *tstart;
    bool dofuncret = FALSE;     /* BUG: this should be passed in        */
    static int nest = 0;
    symbol *s;

    if (prefix)
    {   strcpy(cpp_name, prefix);
        i = strlen(prefix);
    }
    else
        i = 0;
    /*dbg_printf("cpp_typetostring:\n");
    type_print(t);*/
    tstart = t;
    for (; t; t = t->Tnext, dofuncret = TRUE)
    {   char c1,c2;
        int nestclass;

        type_debug(t);
        if (i > IDMAX - 4)      /* if not room for 4 more + 0   */
        {   //cpperr(EM_type_complex);  // type is too complex
            assert(0);
            i = 0;
        }

        if (t->Tty & mTYconst)
            cpp_name[i++] = 'C';
        if (t->Tty & mTYvolatile)
            cpp_name[i++] = 'V';
        c1 = 0;
        nestclass = 0;
        /* Function return types are ignored                            */
        switch (tybasic(t->Tty))
        {
            case TYschar:       c1 = 'S';       goto L2;
            case TYuchar:       c1 = 'U';       goto L2;
            case TYchar:    L2: c2 = 'c';       break;
            case TYushort:      c1 = 'U';
            case TYshort:       c2 = 's';       break;
            case TYuint:        c1 = 'U';
            case TYint:         c2 = 'i';       break;
#if LONGLONG && __INTSIZE == 4 // DJB
            case TYullong:      c1 = 'U';
            case TYllong:       c2 = 'x';       break;
#endif
            case TYulong:       c1 = 'U';
            case TYlong:        c2 = 'l';       break;
#if M_UNIX
            case TYnptr:        // For Gnu gdb and ARM compatibility
#endif
            case TYfptr:        c2 = 'P';       break;
            case TYvptr:        c2 = 'h';       break;
            case TYfloat:       c2 = 'f';       break;
            case TYldouble:     c2 = 'r';       break;
            case TYdouble:      c2 = 'd';       break;
            case TYvoid:        c2 = 'v';       break;
#if TX86
            case TYnref:
            case TYfref:
#endif
            case TYref:         c2 = 'R';       break;
#if M_UNIX
            case TYmfunc:
            case TYnfunc:
            case TYnpfunc:              // Near functions under Unix are coded as F
            case TYnsysfunc:    // see ARM page 124
#endif
            case TYfpfunc:      c2 = 'F';       goto L4;
#if TX86
            case TYfsysfunc:
#endif
            case TYffunc:       c2 = 'D';       goto L4;
#if TX86
            case TYsptr:        c2 = 'b';       break;
#if !M_UNIX
            case TYnptr:        c2 = 'p';       break;
#endif
            case TYcptr:        c2 = 'E';       break;
            case TYf16ptr:      c2 = 'g';       break;
            case TYf16func:     c2 = 'G';       goto L4;
            case TYhptr:        c2 = 'H';       break;
#if !M_UNIX
            case TYnpfunc:      c2 = 'N';       goto L4;
            case TYmfunc:
            case TYnsysfunc:
            case TYnfunc:       c2 = 'B';       goto L4;
#endif
            case TYfsfunc:      c2 = 'I';       goto L4;
            case TYnsfunc:      c2 = 'j';       goto L4;
#else
            case TYpsfunc:      c2 = 'F';       goto L4;
            case TYcomp:        c2 = 'o';       break;
            case TYmemptr:      c2 = 'm';       break;
#endif
            L4:
                cpp_name[i++] = c2;
                if (i > IDMAX - 2)
                {   //cpperr(EM_type_complex);
                    assert(0);
                    i = 0;
                }
                /* Append the types of the parameters to the name       */
            {   int n;
                int paramidx[10];               /* previous parameter indices */

                n = 1;                          /* parameter number     */
                for (p = t->Tparamtypes; p; p = p->Pnext)
                {   int len;

                    cpp_name[i] = 0;
                    nest++;
                    cpp_typetostring(p->Ptype,cpp_name);
                    nest--;
                    len = strlen(cpp_name);
                    if (n < arraysize(paramidx))
                    {   paramidx[n] = i;
                        if (len - i > 2)        /* only if we get real savings */
                        {   int j;

                            /* 'common subexpression' with any previous */
                            /* matching type, if match, replace with    */
                            /* 'T' parameter_number                     */
                            for (j = 1; j < n; j++)
                                if (memcmp(&cpp_name[paramidx[j]],&cpp_name[i],len - i) == 0)
                                {   sprintf(cpp_name + i,"T%d",j);
                                    len = i + 2;
                                    break;
                                }
                        }
                    }
                    if (len > IDMAX - 2)
                    {   //cpperr(EM_type_complex);
                        assert(0);
                        len = 0;
                        n = 0;
                    }
                    i = len;
                    n++;
                }
            }
                if (variadic(t))
                    cpp_name[i++] = 'e';
                else if (t->Tflags & TFfixed && !t->Tparamtypes)
                    cpp_name[i++] = 'v';                /* func(void)           */

                /* Determine if function return types should be considered */
                if (dofuncret || nest)
                {   cpp_name[i++] = '_';
                    continue;
                }
                else
                    goto L1;            /* ignore what the function returns */

#if TX86
            case TYmemptr:
                cpp_name[i++] = 'm';
#endif
            case TYstruct:
                s = t->Ttag;
            L6:
                if (s->Sstruct->Sflags & STRnotagname)
                {
                    s->Sstruct->Sflags &= ~STRnotagname;
#if SCPP
                    warerr(WM_notagname,ssymbol ? (char *)ssymbol->Sident : "Unknown" );                /* no tag name for struct       */
#endif
                }
                goto L5;
            case TYenum:
                s = t->Ttag;
                if (s->Senum->SEflags & SENnotagname)
                {
                    s->Senum->SEflags &= ~SENnotagname;
#if SCPP
                    warerr(WM_notagname, ssymbol ? (char *)ssymbol->Sident : "Unknown" );               /* no tag name for struct       */
#endif
                }
            L5:
            {   int len;
                char *p;

                /* Append the tag to the name   */
                p = symbol_ident(s);
                len = strlen(p);
                if (i + len + nestclass > IDMAX - sizeof(len) * 3)
                {   //cpperr(EM_type_complex);          /* type is too complex  */
                    assert(0);
                    goto L1;
                }
                sprintf(cpp_name + i,("X%d%s" + 1 - nestclass),len,p);

                /* Handle nested classes        */
                s = s->Sscope;
                if (s)
                {   nestclass = 1;
                    i = strlen(cpp_name);
                    goto L6;
                }

                goto L3;
            }
            case TYarray:
                if (i > IDMAX - 1 - sizeof(t->Tdim) * 3)
                {   //cpperr(EM_type_complex);          // type is too complex
                    assert(0);
                    goto L1;
                }
                sprintf(cpp_name + i,"A%d",t->Tdim);
            L3: i = strlen(cpp_name);
                continue;
            default:
                debug(type_print(t));
                assert(0);
        }
        if (c1)
            cpp_name[i++] = c1;
        cpp_name[i++] = c2;
    }
L1:
    cpp_name[i] = 0;                    // terminate the string
    return cpp_name;
}

/***********************************
 * Create mangled name for template instantiation.
 */

#if SCPP

char *template_mangle(symbol *s,param_t *arglist)
{
    /*  mangling    ::= "__PT" N template_name { type | expr }
        N           ::= number of characters in template_name
        type        ::= mangled type
        expr        ::= "V" value
        value       ::= integer | string | address | float | double | long_double | numeric 
        integer     ::= digit { digit }
        string      ::= "S" integer "_" { char }
        address     ::= "R" integer "_" { char }
        float       ::= "F" hex_digits
        double      ::= "D" hex_digits
        long_double ::= "L" hex_digits
     */
    char *n;
    param_t *p;

    ssymbol = s;

    assert(s);
    symbol_debug(s);
    assert(s->Sclass == SCtemplate);
    n = cpp_catname("__PT",unsstr(strlen((char *)s->Sident)));
    n = cpp_catname(n,(char *)s->Sident);
    for (p = arglist; p; p = p->Pnext)
    {
        if (p->Ptype)
        {   /* Argument is a type       */
            n = cpp_typetostring(p->Ptype,n);
        }
        else
        {   /* Argument is an expression        */
            elem *e = p->Pelem;
            tym_t ty = tybasic(e->ET->Tty);
            char *p;
            char a[2];
            int ni;
#if NEW_UNMANGLER
            double d;
#endif

            n = cpp_catname(n,"V");
            /*n = cpp_typetostring(e->ET,n);*/
            switch (e->Eoper)
            {   case OPconst:
                    switch (ty)
                    {
#if !(NEW_UNMANGLER)
                        case TYfloat:   ni = FLOATSIZE;  a[0] = 'F'; goto L1;
                        case TYdouble:  ni = DOUBLESIZE; a[0] = 'D'; goto L1;
                        case TYldouble: ni = LNGDBLSIZE; a[0] = 'L'; goto L1;
                        L1:
                            a[1] = 0;
                            n = cpp_catname(n,a);
                            p = (char *)&e->EV.Vdouble;

#elif !NEW_UNMANGLER
                        case TYfloat:
                            float f;
                            ni = FLOATSIZE;
                            a[0] = 'F';
                            f = e->EV.Vfloat;
                            p = (char *)&f;
                            goto L1;
                        case TYdouble:
                            double d;
                            ni = tysize[TYdouble];
                            a[0] = 'D';
                            d = e->EV.Vdouble;
                            p = (char *)&d;
                            goto L1;
                        case TYldouble:
                            ni = tysize[TYldouble];
                            a[0] = 'L';
                            if (config.flags & CFGldblisdbl)
                                p = (char *)&e->EV.Vdouble;
                            else
                            {
                                d = e->EV.Vldouble;
                            }
                            p = (char *)&d;
//                          ni = tysize[TYdouble];
                            ni = sizeof(longdouble); // just until new unmangler is in
                        L1:
                            a[1] = 0;
                            n = cpp_catname(n,a);
#endif
#if !NEW_UNMANGLER
                            while (ni--)
                            {   char c;
                                static char hex[17] = "0123456789ABCDEF";
                                static char buf[3];

                                c = *p++;
                                buf[0] = hex[c & 15];
                                buf[1] = hex[(c >> 4) & 15];
                                n = cpp_catname(n,buf);
                            }
                            break;
#else // NEW_UNMANGLER
                        case TYfloat:   d = e->EV.Vfloat;  goto L1;
                        case TYdouble:  d = e->EV.Vdouble; goto L1;
                        case TYldouble: if (config.flags & CFGldblisdbl)
                                            d = e->EV.Vdouble;
                                        else
                                            d = e->EV.Vldouble;
                        L1: char buf[32];
                            n = cpp_catname(n,"N");
                            ni = sprintf(buf, "%g", d);
                            p = buf-1;
                            while (ni--)
                            {   char c;
                                c = *++p;
                                if (c == '-')
                                    *p = 'n';
                                else if (c == '+')
                                    *p = 'p';
                                else if (c == '.')
                                    *p = 'd';
                            }
                            p = buf;
                            goto L2;
#endif // NEW_UNMANGLER
                        default:
                            if (tyintegral(ty))
                            {   char buf[sizeof(long) * 3 + 1];
                                sprintf(buf,"%lu",el_tolong(e));
                                cpp_catname(n,buf);
                                break;
                            }
                            assert(0);
                    }
                    break;
                case OPstring:
                    p = e->EV.ss.Vstring;
                    n = cpp_catname(n,"S");
                    goto L2;
                case OPrelconst:
                    p = (char *)e->EV.sp.Vsym->Sident;
                    n = cpp_catname(n,"R");
                L2:
                    n = cpp_catname(n,unsstr(strlen(p)));
                    n = cpp_catname(n,"_");
                    n = cpp_catname(n,p);
                    break;
                default:
                    assert(errcnt);
                    break;
            }
        }
    } /* for */
    ssymbol = NULL;
    return n;
}

#endif

/*********************************
 * Mangle a vtbl or vbtbl name.
 * Returns:
 *      pointer to generated symbol with mangled name
 */

#if SCPP

symbol *mangle_tbl(
        int flag,               // 0: vtbl, 1: vbtbl
        type *t,                // type for symbol
        Classsym *stag,         // class we're putting tbl in
        Classsym *sbase)        // base class (NULL if none)
{   const char *id;
    symbol *s;

    if (flag == 0)
        id = config.flags3 & CFG3rtti ? "rttivtbl" : "vtbl";
    else
        id = "vbtbl";
    if (sbase)
        id = cpp_genname((char *)stag->Sident,cpp_genname((char *)sbase->Sident,id));
    else
        id = cpp_genname((char *)stag->Sident,id);

//
// This can happen for MI cases, the virtual table could already be defined
//

    s = scope_search( id, SCTglobal | SCTnspace | SCTlocal );
    if (s)
        return(s);
    s = scope_define(id,SCTglobal | SCTnspace | SCTlocal, SCunde);
    s->Stype = t;
    t->Tcount++;
#if XCOFF_OBJ || CFM68K || CFMV2
    if (config.CFMOption && config.CFMxf)       // cross fragment C++
        s->Scfmflags = stag->Scfmflags;         // Copy the flags from the stag
#endif
    return s;
}

#endif

#endif
