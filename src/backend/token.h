// Copyright (C) 1984-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/**********************************
 * Symbol tokens:
 *
 * TKstar       *       TKdot           .       TKeq            =
 * TKand        &       TKlbra          [       TKaddass        +=
 * TKmin        -       TKrbra          ]       TKminass        -=
 * TKnot        !       TKarrow         ->      TKmulass        *=
 * TKcom        ~       TKdiv           /       TKdivass        /=
 * TKplpl       ++      TKmod           %       TKmodass        %=
 * TKlpar       (       TKxor           ^       TKshrass        >>=
 * TKrpar       )       TKor            |       TKshlass        <<=
 * TKques       ?       TKoror          ||      TKandass        &=
 * TKcolon      :       TKandand        &&      TKxorass        ^=
 * TKcomma      ,       TKshl           <<      TKorass         |=
 * TKmimi       --      TKshr           >>      TKsemi          ;
 * TKlcur       {       TKrcur          }       TKlt            <
 * TKle         <=      TKgt            >       TKge            >=
 * TKeqeq       ==      TKne            !=      TKadd           +
 * TKellipsis   ...     TKcolcol        ::      TKdollar        $
 *
 * Other tokens:
 *
 * TKstring     string
 * TKfilespec   <filespec>
 */

//#pragma once
#ifndef TOKEN_H
#define TOKEN_H 1

#if !defined(TOKENS_ONLY) || TOKENS_ONLY
// Keyword tokens. Needn't be ascii sorted
typedef unsigned char enum_TK;
enum TK {
        TKauto,
        TKbreak,
        TKcase,
        TKchar,
        TKconst,
        TKcontinue,
        TKdefault,
        TKdo,
        TKdouble,
        TKelse,
        TKenum,
        TKextern,
        TKfloat,
        TKfor,
        TKgoto,
        TKif,
        TKint,
        TKlong,
        TKregister,
        TKreturn,
        TKshort,
        TKsigned,
        TKsizeof,
        TKstatic,
        TKstruct,
        TKswitch,
        TKtypedef,
        TKunion,
        TKunsigned,
        TKvoid,
        TKvolatile,
        TKwhile,

        // ANSI C99
        TK_Complex,
        TK_Imaginary,
        TKrestrict,

//#if CPP
        TKbool,
        TKcatch,
        TKclass,
        TKconst_cast,
        TKdelete,
        TKdynamic_cast,
        TKexplicit,
        TKfalse,
        TKfriend,
        TKinline,
        TKmutable,
        TKnamespace,
        TKnew,
        TKoperator,
        TKoverload,
        TKprivate,
        TKprotected,
        TKpublic,
        TKreinterpret_cast,
        TKstatic_cast,
        TKtemplate,
        TKthis,
        TKthrow,
        TKtrue,
        TKtry,
        TKtypeid,
        TKtypename,
        TKusing,
        TKvirtual,
        TKwchar_t,
        TK_typeinfo,
        TK_typemask,
//#endif

#if CPP0X
        TKalignof,
        TKchar16_t,
        TKchar32_t,
        TKconstexpr,
        TKdecltype,
        TKnoexcept,
        TKnullptr,
        TKstatic_assert,
        TKthread_local,
#endif

        TKasm,
        TK_inf,
        TK_nan,
        TK_nans,
        TK_i,           // imaginary constant i
        TK_with,
        TK_istype,
        TK_cdecl,
        TK_fortran,
        TK_pascal,

        TK_debug,
        TK_in,
        TK_out,
        TK_body,
        TK_invariant,
#if TX86
        TK_Seg16,
        TK_System,
        TK__emit__,
        TK_far,
        TK_huge,
        TK_near,

        TK_asm,
        TK_based,
        TK_cs,
        TK_declspec,
        TK_except,
        TK_export,
        TK_far16,
        TK_fastcall,
        TK_finally,
        TK_handle,
        TK_java,
        TK_int64,
        TK_interrupt,
        TK_leave,
        TK_loadds,
        TK_real80,
        TK_saveregs,
        TK_segname,
        TK_ss,
        TK_stdcall,
        TK_syscall,
        TK_try,
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        TK_attribute,
        TK_extension,
        TK_format,
        TK_restrict,
        TK_bltin_const,
#endif
#else
        TKcomp,
        TKextended,
        TK_handle,
        TK_machdl,
        TK_pasobj,
//#if CPP
        TK__class,
        TKinherited,
//#endif
#endif
        TK_unaligned,
        TKsymbol,                       // special internal token

#define KWMAX   (TK_unaligned + 1)      // number of keywords

        TKcolcol,               //      ::
        TKarrowstar,            //      ->*
        TKdotstar,              //      .*

        TKstar,TKand,TKmin,TKnot,TKcom,TKplpl,TKlpar,TKrpar,TKques,TKcolon,TKcomma,
        TKmimi,TKlcur,TKdot,TKlbra,TKrbra,TKarrow,TKdiv,TKmod,TKxor,TKor,TKoror,
        TKandand,TKshl,TKshr,TKrcur,TKeq,TKaddass,TKminass,TKmulass,TKdivass,
        TKmodass,TKshrass,TKshlass,TKandass,TKxorass,TKorass,TKsemi,
        TKadd,TKellipsis,
#if !TX86 || TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        TKdollar,
#endif

 /* The following relational tokens must be in the same order as the
    corresponding operators.
  */
 /*   ==     !=         */
        TKle,TKgt,TKlt,TKge,TKeqeq,TKne,

 /*   !<>=    <>   <>=   !>    !>=  !<    !<=  !<>      */
        TKunord,TKlg,TKleg,TKule,TKul,TKuge,TKug,TKue,

        TKstring,
        TKfilespec,     /* <filespec>           */
        TKpragma,
        TKnum,  /* integral number      */
        TKreal_f,
        TKreal_d,
        TKreal_da,
        TKreal_ld,
        TKident,        /* identifier           */
        TKeol,  /* end of line          */
        TKeof,  /* end of file          */
        TKnone, /* no token             */
        TKMAX   /* number of tokens     */
};
#endif

#if !defined(TOKENS_ONLY) || !TOKENS_ONLY
struct token_t
{
    enum_TK TKval;              // what the token is
    unsigned char TKflags;      // Token flags
#define TKFfree         1       // free the token after it's scanned
#define TKFinherited    2       // keyword INHERITED prior to token
#define TKFpasstr       4       // pascal string
    unsigned char TKty;         // TYxxxx for TKstring and TKnum
    union _TKutok
    {
        // Scheme for short IDs avoids malloc/frees
        struct _ident   // TKident
        {   char *ident;        // pointer to identifier
            char idtext[4];     // if short identifier
        } _idx;

        struct _uts     /* TKstring and TKfilespec              */
        {
            char *string;/* for strings (not null terminated)   */
            int lenstr;  /* length of string                    */
        } uts;
        symbol *sym;    // TKsymbol
        int pragma;             // TKpragma: PRxxxx, pragma number
                                // -1 if unrecognized pragma
        targ_long Vlong;        /* integer when TKnum           */
        targ_llong Vllong;
        targ_float Vfloat;
        targ_double Vdouble;
        targ_ldouble Vldouble;
    } TKutok;
    Srcpos TKsrcpos;            // line number from where it was taken
    token_t *TKnext;            // to create a list of tokens

#ifdef DEBUG
    unsigned short id;
#define IDtoken 0xA745
#define token_debug(e) assert((e)->id == IDtoken)
#else
#define token_debug(e)
#endif

    void setSymbol(symbol *s);
    void print();
};

#define TKstr           TKutok.uts.string
#define TKlenstr        TKutok.uts.lenstr
#define TKid            TKutok._idx.ident
#define TKsym           TKutok.sym

// Use this for fast scans
#define _IDS    1       // start of identifier
#define _ID     2       // identifier
#define _TOK    4       // single character token
#define _EOL    8       // end of line
#define _MUL    0x10    // start of multibyte character sequence
#define _BCS    0x20    // in basic-source-character-set
#define _MTK    0x40    // could be multi-character token
#define _ZFF    0x80    // 0 or 0xFF (must be sign bit)

#define istok(x)        (_chartype[(x) + 1] & _TOK)
#define iseol(x)        (_chartype[(x) + 1] & _EOL)
#define isidstart(x)    (_chartype[(x) + 1] & _IDS)
#define isidchar(x)     (_chartype[(x) + 1] & (_IDS | _ID))
#define ismulti(x)      (_chartype[(x) + 1] & _MUL)
#define isbcs(x)        (_chartype[(x) + 1] & _BCS)

/* from token.c */
extern int igncomment;
extern char *tok_arg;
extern unsigned argmax;
extern  token_t tok;
extern  int ininclude;
extern char tok_ident[];       // identifier
extern  unsigned char _chartype[];
extern token_t *toklist;

void token_setdbcs(int);
void token_setlocale(const char *);
token_t *token_copy(void);
void token_free(token_t *tl);
void token_hydrate(token_t **ptl);
void token_dehydrate(token_t **ptl);
token_t *token_funcbody(int bFlag);
token_t *token_defarg(void);
void token_funcbody_print(token_t *t);
void token_setlist(token_t *t);
void token_poplist(void);
void token_unget(void);
void token_markfree(token_t *t);
void token_setident(char *);
void token_semi(void);
Srcpos token_linnum(void);
enum_TK token_peek();

enum_TK rtoken(int);
#if SPP
#define stoken() rtoken(1)
#else
enum_TK stokenx(void);
inline enum_TK stoken() { return toklist ? stokenx() : rtoken(1); }
#endif

void token_init(void);
void removext(void);
void comment(void);
void cppcomment(void);
char *combinestrings(targ_size_t *plen);
char *combinestrings(targ_size_t *plen, tym_t *pty);
void inident(void);
void inidentX(char *p);
unsigned comphash(const char *p);
int insertSpace(unsigned char xclast, unsigned char xcnext);
void panic(enum_TK ptok);
void chktok(enum_TK toknum , unsigned errnum);
void chktok(enum_TK toknum , unsigned errnum, const char *str);
void opttok(enum_TK toknum);
bool iswhite(int c);
void token_term(void);

#define ptoken()        rtoken(1)
#define token()         rtoken(0)

#if !MARS
/* from pragma.c */
//enum_TK ptoken(void);
void pragma_process();
int pragma_search(const char *id);
macro_t * macfind(void);
macro_t *macdefined(const char *id, unsigned hash);
void listident(void);
void pragma_term(void);
macro_t *defmac(const char *name , const char *text);
int pragma_defined(void);
#endif

#if SPP && TX86
#define token_linnum()  getlinnum()
#endif

//      listing control
//      Listings can be produce via -l and SCpre
//              -l      expand all characters not if'd out including
//                      comments
//              SCpre   list only characters to be compiled
//                      i.e. exclude comments and # preprocess lines

#if SPP
#define SCPRE_LISTING_ON()      expflag--; assert(expflag >= 0)
#define SCPRE_LISTING_OFF()     assert(expflag >= 0); expflag++
#define EXPANDED_LISTING_ON()   expflag--; assert(expflag >= 0)
#define EXPANDED_LISTING_OFF()  assert(expflag >= 0); expflag++
#else
#define SCPRE_LISTING_OFF()
#define SCPRE_LISTING_ON()
#define EXPANDED_LISTING_ON()   expflag--; assert(expflag >= 0)
#define EXPANDED_LISTING_OFF()  assert(expflag >= 0); expflag++
#endif

#define EXPANDING_LISTING()     (expflag == 0)
#define NOT_EXPANDING_LISTING() (expflag)
#endif

/***********************************************
 * This is the token lookahead API, which enables us to
 * look an arbitrary number of tokens ahead and then
 * be able to 'unget' all of them.
 */

struct Token_lookahead
{
    int inited;                 // 1 if initialized
    token_t *toks;              // list of tokens
    token_t **pend;             // pointer to end of that list

    void init()
    {
        toks = NULL;
        pend = &toks;
        inited = 1;
    }

    enum_TK lookahead()
    {
    #ifdef DEBUG
        //assert(inited == 1);
    #endif
        *pend = token_copy();
        (*pend)->TKflags |= TKFfree;
        pend = &(*pend)->TKnext;
        return stoken();
    }

    void term()
    {
#ifdef DEBUG
        //assert(inited == 1);
#endif
        inited--;
        if (toks)
        {
            token_unget();
            token_setlist(toks);
            stoken();
        }
    }

    void discard()
    {
        inited--;
        token_free(toks);
    }
};


#endif /* TOKEN_H */
