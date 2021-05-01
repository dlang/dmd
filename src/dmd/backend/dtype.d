/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/dtype.d
 */

module dmd.backend.dtype;

version (SCPP)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (HTOD)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (MARS)
    version = COMPILE;


version (COMPILE)
{
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.dlist;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.mem;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.type;

version (SCPP_HTOD)
{
    import dtoken;
    import msgs2;
    import parser;
    import precomp;
}

extern (C++):

nothrow:
@safe:

alias MEM_PH_MALLOC = mem_malloc;
alias MEM_PH_CALLOC = mem_calloc;
alias MEM_PH_FREE = mem_free;
alias MEM_PH_STRDUP = mem_strdup;
alias MEM_PARF_MALLOC = mem_malloc;
alias MEM_PARF_CALLOC = mem_calloc;
alias MEM_PARF_REALLOC = mem_realloc;
alias MEM_PARF_FREE = mem_free;
alias MEM_PARF_STRDUP = mem_strdup;

version (SCPP_HTOD)
    @trusted
    struct_t* struct_calloc();
else
    @trusted
    struct_t* struct_calloc() { return cast(struct_t*) mem_calloc(struct_t.sizeof); }

int REGSIZE();

private __gshared
{
    type *type_list;          // free list of types
    param_t *param_list;      // free list of params

    int type_num,type_max;   /* gather statistics on # of types      */
}

__gshared
{
    type*[TYMAX] tstypes;
    type*[TYMAX] tsptr2types;

    type* tstrace,tsclib,tsjlib,tsdlib,
            tslogical;
    type* tspvoid,tspcvoid;
    type* tsptrdiff, tssize;
}

/*******************************
 * Compute size of type in bytes.
 * Mark size as known after error message if it is not known.
 * Instantiate templates as needed to compute size.
 * Params:
 *      t = type
 * Returns:
 *      size
 */

version (SCPP_HTOD)
{
@trusted
targ_size_t type_size(type* t)
{
    switch (tybasic(t.Tty))
    {
        case TYarray:
            if (t.Tflags & TFsizeunknown)
            {
                synerr(EM_unknown_size,"array".ptr);    /* size of array is unknown     */
                t.Tflags &= ~TFsizeunknown;
            }
            type_size(t.Tnext);
            break;

        case TYstruct:
            auto ts = t.Ttag.Stype;    // find main instance
                                       // (for const struct X)
            if (ts.Tflags & TFsizeunknown)
            {
                template_instantiate_forward(ts.Ttag);
                if (ts.Tflags & TFsizeunknown)
                    synerr(EM_unknown_size,ts.Tty & TYstruct ? prettyident(ts.Ttag) : "struct");
                ts.Tflags &= ~TFsizeunknown;
            }
            break;

        case TYenum:
            if (t.Ttag.Senum.SEflags & SENforward)
                synerr(EM_unknown_size, prettyident(t.Ttag));
            type_size(t.Tnext);
            break;

        default:
            break;
    }
    return type_size(cast(const)t);
}
}

/***********************
 * Compute size of type in bytes.
 * Params:
 *      t = type
 * Returns:
 *      size
 */
@trusted
targ_size_t type_size(const type *t)
{   targ_size_t s;
    tym_t tyb;

    type_debug(t);
    tyb = tybasic(t.Tty);

    debug if (tyb >= TYMAX)
        /*type_print(t),*/
        printf("tyb = x%x\n", tyb);

    assert(tyb < TYMAX);
    s = _tysize[tyb];
    if (s == cast(targ_size_t) -1)
    {
        switch (tyb)
        {
            // in case program plays games with function pointers
            case TYffunc:
            case TYfpfunc:
            case TYfsfunc:
            case TYf16func:
            case TYhfunc:
            case TYnfunc:       /* in case program plays games with function pointers */
            case TYnpfunc:
            case TYnsfunc:
            case TYifunc:
            case TYjfunc:
version (SCPP_HTOD)
{
            case TYmfunc:
                if (config.ansi_c)
                    synerr(EM_unknown_size,"function".ptr); /* size of function is not known */
}
                s = 1;
                break;
            case TYarray:
            {
                if (t.Tflags & TFsizeunknown)
                {
version (SCPP_HTOD)
{
                    synerr(EM_unknown_size,"array".ptr);    /* size of array is unknown     */
}
                }
                if (t.Tflags & TFvla)
                {
                    s = _tysize[pointertype];
                    break;
                }
                s = type_size(t.Tnext);
                uint u = cast(uint)t.Tdim * cast(uint) s;
version (SCPP_HTOD)
{
                type_chksize(u);
}
else version (MARS)
{
                if (t.Tdim && ((u / t.Tdim) != s || cast(int)u < 0))
                    assert(0);          // overflow should have been detected in front end
}
else
{
                static assert(0);
}
                s = u;
                break;
            }
            case TYstruct:
            {
                auto ts = t.Ttag.Stype;     // find main instance
                                            // (for const struct X)
                assert(ts.Ttag);
                s = ts.Ttag.Sstruct.Sstructsize;
                break;
            }
version (SCPP_HTOD)
{
            case TYenum:
                if (t.Ttag.Senum.SEflags & SENforward)
                    synerr(EM_unknown_size, prettyident(cast(Symbol*)t.Ttag));
                s = type_size(t.Tnext);
                break;
}
            case TYvoid:
version (SCPP_HTOD) static if (TARGET_WINDOS)   // GNUC allows it, so we will, too
{
                synerr(EM_void_novalue);        // voids have no value
}
                s = 1;
                break;

            case TYref:
version (MARS)
{
                s = tysize(TYnptr);
                break;
}
version (SCPP_HTOD)
{
            case TYmemptr:
            case TYvtshape:
                s = tysize(tym_conv(t));
                break;

            case TYident:
                synerr(EM_unknown_size, t.Tident);
                s = 1;
                break;
}

            default:
                debug WRTYxx(t.Tty);
                assert(0);
        }
    }
    return s;
}

/********************************
 * Return the size of a type for alignment purposes.
 */

@trusted
uint type_alignsize(type *t)
{   targ_size_t sz;

L1:
    type_debug(t);

    sz = tyalignsize(t.Tty);
    if (sz == cast(targ_size_t)-1)
    {
        switch (tybasic(t.Tty))
        {
            case TYarray:
                if (t.Tflags & TFsizeunknown)
                    goto err1;
                t = t.Tnext;
                goto L1;
            case TYstruct:
                t = t.Ttag.Stype;         // find main instance
                                            // (for const struct X)
                if (t.Tflags & TFsizeunknown)
                    goto err1;
                sz = t.Ttag.Sstruct.Salignsize;
                if (sz > t.Ttag.Sstruct.Sstructalign + 1)
                    sz = t.Ttag.Sstruct.Sstructalign + 1;
                break;

            case TYldouble:
                assert(0);

            default:
            err1:                   // let type_size() handle error messages
                sz = type_size(t);
                break;
        }
    }

    //printf("type_alignsize() = %d\n", sz);
    return cast(uint)sz;
}

/***********************************
 * Compute special zero sized struct.
 * Params:
 *      t = type of parameter
 *      tyf = function type
 * Returns:
 *      true if it is
 */
@trusted
bool type_zeroSize(type *t, tym_t tyf)
{
    if (tyf != TYjfunc && config.exe & (EX_FREEBSD | EX_OPENBSD | EX_OSX))
    {
        /* Use clang convention for 0 size structs
         */
        if (t && tybasic(t.Tty) == TYstruct)
        {
            type *ts = t.Ttag.Stype;     // find main instance
                                           // (for const struct X)
            if (ts.Tflags & TFsizeunknown)
            {
version (SCPP_HTOD)
{
                template_instantiate_forward(ts.Ttag);
                if (ts.Tflags & TFsizeunknown)
                    synerr(EM_unknown_size,ts.Tty & TYstruct ? prettyident(ts.Ttag) : "struct");
                ts.Tflags &= ~TFsizeunknown;
}
            }
            if (ts.Ttag.Sstruct.Sflags & STR0size)
//{ printf("0size\n"); type_print(t); *(char*)0=0;
                return true;
//}
        }
    }
    return false;
}

/*********************************
 * Compute the size of a single parameter.
 * Params:
 *      t = type of parameter
 *      tyf = function type
 * Returns:
 *      size in bytes
 */
uint type_parameterSize(type *t, tym_t tyf)
{
    if (type_zeroSize(t, tyf))
        return 0;
    return cast(uint)type_size(t);
}

/*****************************
 * Compute the total size of parameters for function call.
 * Used for stdcall name mangling.
 * Note that hidden parameters do not contribute to size.
 * Params:
 *   t = function type
 * Returns:
 *   total stack usage in bytes
 */

@trusted
uint type_paramsize(type *t)
{
    targ_size_t sz = 0;
    if (tyfunc(t.Tty))
    {
        for (param_t *p = t.Tparamtypes; p; p = p.Pnext)
        {
            const size_t n = type_parameterSize(p.Ptype, tybasic(t.Tty));
            sz += _align(REGSIZE,n);       // align to REGSIZE boundary
        }
    }
    return cast(uint)sz;
}

/*****************************
 * Create a type & initialize it.
 * Input:
 *      ty = TYxxxx
 * Returns:
 *      pointer to newly created type.
 */

@trusted
type *type_alloc(tym_t ty)
{   type *t;

    assert(tybasic(ty) != TYtemplate);
    if (type_list)
    {   t = type_list;
        type_list = t.Tnext;
    }
    else
        t = cast(type *) mem_fmalloc(type.sizeof);
    *t = type();
    t.Tty = ty;
version (SRCPOS_4TYPES)
{
    if (PARSER && config.fulltypes)
        t.Tsrcpos = getlinnum();
}
debug
{
    t.id = type.IDtype;
    type_num++;
    if (type_num > type_max)
        type_max = type_num;
}
    //printf("type_alloc() = %p ",t); WRTYxx(t.Tty); printf("\n");
    //if (t == (type*)0xB6B744) *(char*)0=0;
    return t;
}

/*************************************
 * Allocate a TYtemplate.
 */

version (SCPP_HTOD)
{
type *type_alloc_template(Symbol *s)
{   type *t;

    t = cast(type *) mem_fmalloc(typetemp_t.sizeof);
    memset(t, 0, typetemp_t.sizeof);
    t.Tty = TYtemplate;
    if (s.Stemplate.TMprimary)
        s = s.Stemplate.TMprimary;
    (cast(typetemp_t *)t).Tsym = s;
version (SRCPOS_4TYPES)
{
    if (PARSER && config.fulltypes)
        t.Tsrcpos = getlinnum();
}
debug
{
    t.id = type.IDtype;
    type_num++;
    if (type_num > type_max)
        type_max = type_num;
    //printf("Alloc'ing template type %p ",t); WRTYxx(t.Tty); printf("\n");
}
    return t;
}
}

/*****************************
 * Fake a type & initialize it.
 * Input:
 *      ty = TYxxxx
 * Returns:
 *      pointer to newly created type.
 */

type *type_fake(tym_t ty)
{   type *t;

version (MARS)
    assert(ty != TYstruct);

    t = type_alloc(ty);
    if (typtr(ty) || tyfunc(ty))
    {   t.Tnext = type_alloc(TYvoid);  /* fake with pointer to void    */
        t.Tnext.Tcount = 1;
    }
    return t;
}

/*****************************
 * Allocate a type of ty with a Tnext of tn.
 */

type *type_allocn(tym_t ty,type *tn)
{   type *t;

    //printf("type_allocn(ty = x%x, tn = %p)\n", ty, tn);
    assert(tn);
    type_debug(tn);
    t = type_alloc(ty);
    t.Tnext = tn;
    tn.Tcount++;
    //printf("\tt = %p\n", t);
    return t;
}

/******************************
 * Allocate a TYmemptr type.
 */

version (SCPP_HTOD)
{
type *type_allocmemptr(Classsym *stag,type *tn)
{   type *t;

    symbol_debug(stag);
    assert(stag.Sclass == SCstruct || tybasic(stag.Stype.Tty) == TYident);
    t = type_allocn(TYmemptr,tn);
    t.Ttag = stag;
    //printf("type_allocmemptr() = %p\n", t);
    //type_print(t);
    return t;
}
}

/********************************
 * Allocate a pointer type.
 * Returns:
 *      Tcount already incremented
 */

type *type_pointer(type *tnext)
{
    type *t = type_allocn(TYnptr, tnext);
    t.Tcount++;
    return t;
}

/********************************
 * Allocate a dynamic array type.
 * Returns:
 *      Tcount already incremented
 */
@trusted
type *type_dyn_array(type *tnext)
{
    type *t = type_allocn(TYdarray, tnext);
    t.Tcount++;
    return t;
}

/********************************
 * Allocate a static array type.
 * Returns:
 *      Tcount already incremented
 */

extern (C) type *type_static_array(targ_size_t dim, type *tnext)
{
    type *t = type_allocn(TYarray, tnext);
    t.Tdim = dim;
    t.Tcount++;
    return t;
}

/********************************
 * Allocate an associative array type,
 * which are key=value pairs
 * Returns:
 *      Tcount already incremented
 */

@trusted
type *type_assoc_array(type *tkey, type *tvalue)
{
    type *t = type_allocn(TYaarray, tvalue);
    t.Tkey = tkey;
    tkey.Tcount++;
    t.Tcount++;
    return t;
}

/********************************
 * Allocate a delegate type.
 * Returns:
 *      Tcount already incremented
 */

@trusted
type *type_delegate(type *tnext)
{
    type *t = type_allocn(TYdelegate, tnext);
    t.Tcount++;
    return t;
}

/***********************************
 * Allocation a function type.
 * Params:
 *      tyf      = function type
 *      ptypes   = types of the function parameters
 *      variadic = if ... function
 *      tret     = return type
 * Returns:
 *      Tcount already incremented
 */
@trusted
extern (C)
type *type_function(tym_t tyf, type*[] ptypes, bool variadic, type *tret)
{
    param_t *paramtypes = null;
    foreach (p; ptypes)
    {
        param_append_type(&paramtypes, p);
    }
    type *t = type_allocn(tyf, tret);
    t.Tflags |= TFprototype;
    if (!variadic)
        t.Tflags |= TFfixed;
    t.Tparamtypes = paramtypes;
    t.Tcount++;
    return t;
}

/***************************************
 * Create an enum type.
 * Input:
 *      name    name of enum
 *      tbase   "base" type of enum
 * Returns:
 *      Tcount already incremented
 */
@trusted
type *type_enum(const(char)* name, type *tbase)
{
    Symbol *s = symbol_calloc(name);
    s.Sclass = SCenum;
    s.Senum = cast(enum_t *) MEM_PH_CALLOC(enum_t.sizeof);
    s.Senum.SEflags |= SENforward;        // forward reference

    type *t = type_allocn(TYenum, tbase);
    t.Ttag = cast(Classsym *)s;            // enum tag name
    t.Tcount++;
    s.Stype = t;
    t.Tcount++;
    return t;
}

/**************************************
 * Create a struct/union/class type.
 * Params:
 *      name = name of struct (this function makes its own copy of the string)
 *      is0size = if struct has no fields (even if Sstructsize is 1)
 * Returns:
 *      Tcount already incremented
 */
@trusted
type *type_struct_class(const(char)* name, uint alignsize, uint structsize,
        type *arg1type, type *arg2type, bool isUnion, bool isClass, bool isPOD, bool is0size)
{
    Symbol *s = symbol_calloc(name);
    s.Sclass = SCstruct;
    s.Sstruct = struct_calloc();
    s.Sstruct.Salignsize = alignsize;
    s.Sstruct.Sstructalign = cast(ubyte)alignsize;
    s.Sstruct.Sstructsize = structsize;
    s.Sstruct.Sarg1type = arg1type;
    s.Sstruct.Sarg2type = arg2type;

    if (!isPOD)
        s.Sstruct.Sflags |= STRnotpod;
    if (isUnion)
        s.Sstruct.Sflags |= STRunion;
    if (isClass)
    {   s.Sstruct.Sflags |= STRclass;
        assert(!isUnion && isPOD);
    }
    if (is0size)
        s.Sstruct.Sflags |= STR0size;

    type *t = type_alloc(TYstruct);
    t.Ttag = cast(Classsym *)s;            // structure tag name
    t.Tcount++;
    s.Stype = t;
    t.Tcount++;
    return t;
}

/*****************************
 * Free up data type.
 */

@trusted
void type_free(type *t)
{   type *tn;
    tym_t ty;

    while (t)
    {
        //printf("type_free(%p, Tcount = %d)\n", t, t.Tcount);
        type_debug(t);
        assert(cast(int)t.Tcount != -1);
        if (--t.Tcount)                /* if usage count doesn't go to 0 */
            break;
        ty = tybasic(t.Tty);
        if (tyfunc(ty))
        {   param_free(&t.Tparamtypes);
            list_free(&t.Texcspec, cast(list_free_fp)&type_free);
            goto L1;
        }
version (SCPP_HTOD)
{
        if (ty == TYtemplate)
        {
            param_free(&t.Tparamtypes);
            goto L1;
        }
        if (ty == TYident)
        {
            MEM_PH_FREE(t.Tident);
            goto L1;
        }
}
        if (t.Tflags & TFvla && t.Tel)
        {
            el_free(t.Tel);
            goto L1;
        }
version (SCPP_HTOD)
{
        if (t.Talternate && typtr(ty))
        {
            type_free(t.Talternate);
            goto L1;
        }
}
version (MARS)
{
        if (t.Tkey && typtr(ty))
            type_free(t.Tkey);
}
      L1:

debug
{
        type_num--;
        //printf("Free'ing type %p ",t); WRTYxx(t.Tty); printf("\n");
        t.id = 0;                      /* no longer a valid type       */
}

        tn = t.Tnext;
        t.Tnext = type_list;
        type_list = t;                  /* link into free list          */
        t = tn;
    }
}

version (STATS)
{
/* count number of free types available on type list */
void type_count_free()
    {
    type *t;
    int count;

    for(t=type_list;t;t=t.Tnext)
        count++;
    printf("types on free list %d with max of %d\n",count,type_max);
    }
}

/**********************************
 * Initialize type package.
 */

private type * type_allocbasic(tym_t ty)
{   type *t;

    t = type_alloc(ty);
    t.Tmangle = mTYman_c;
    t.Tcount = 1;              /* so it is not inadvertently free'd    */
    return t;
}

@trusted
void type_init()
{
    tstypes[TYbool]    = type_allocbasic(TYbool);
    tstypes[TYwchar_t] = type_allocbasic(TYwchar_t);
    tstypes[TYdchar]   = type_allocbasic(TYdchar);
    tstypes[TYvoid]    = type_allocbasic(TYvoid);
    tstypes[TYnullptr] = type_allocbasic(TYnullptr);
    tstypes[TYchar16]  = type_allocbasic(TYchar16);
    tstypes[TYuchar]   = type_allocbasic(TYuchar);
    tstypes[TYschar]   = type_allocbasic(TYschar);
    tstypes[TYchar]    = type_allocbasic(TYchar);
    tstypes[TYshort]   = type_allocbasic(TYshort);
    tstypes[TYushort]  = type_allocbasic(TYushort);
    tstypes[TYint]     = type_allocbasic(TYint);
    tstypes[TYuint]    = type_allocbasic(TYuint);
    tstypes[TYlong]    = type_allocbasic(TYlong);
    tstypes[TYulong]   = type_allocbasic(TYulong);
    tstypes[TYllong]   = type_allocbasic(TYllong);
    tstypes[TYullong]  = type_allocbasic(TYullong);
    tstypes[TYfloat]   = type_allocbasic(TYfloat);
    tstypes[TYdouble]  = type_allocbasic(TYdouble);
    tstypes[TYdouble_alias]  = type_allocbasic(TYdouble_alias);
    tstypes[TYldouble] = type_allocbasic(TYldouble);
    tstypes[TYifloat]  = type_allocbasic(TYifloat);
    tstypes[TYidouble] = type_allocbasic(TYidouble);
    tstypes[TYildouble] = type_allocbasic(TYildouble);
    tstypes[TYcfloat]   = type_allocbasic(TYcfloat);
    tstypes[TYcdouble]  = type_allocbasic(TYcdouble);
    tstypes[TYcldouble] = type_allocbasic(TYcldouble);

    if (I64)
    {
        TYptrdiff = TYllong;
        TYsize = TYullong;
        tsptrdiff = tstypes[TYllong];
        tssize = tstypes[TYullong];
    }
    else
    {
        TYptrdiff = TYint;
        TYsize = TYuint;
        tsptrdiff = tstypes[TYint];
        tssize = tstypes[TYuint];
    }

    // Type of trace function
    tstrace = type_fake(I16 ? TYffunc : TYnfunc);
    tstrace.Tmangle = mTYman_c;
    tstrace.Tcount++;

    chartype = (config.flags3 & CFG3ju) ? tstypes[TYuchar] : tstypes[TYchar];

    // Type of far library function
    tsclib = type_fake(LARGECODE ? TYfpfunc : TYnpfunc);
    tsclib.Tmangle = mTYman_c;
    tsclib.Tcount++;

    tspvoid = type_allocn(pointertype,tstypes[TYvoid]);
    tspvoid.Tmangle = mTYman_c;
    tspvoid.Tcount++;

    // Type of far library function
    tsjlib =    type_fake(TYjfunc);
    tsjlib.Tmangle = mTYman_c;
    tsjlib.Tcount++;

    tsdlib = tsjlib;

version (SCPP_HTOD)
{
    tspcvoid = type_alloc(mTYconst | TYvoid);
    tspcvoid = newpointer(tspcvoid);
    tspcvoid.Tmangle = mTYman_c;
    tspcvoid.Tcount++;
}

    // Type of logical expression
    tslogical = (config.flags4 & CFG4bool) ? tstypes[TYbool] : tstypes[TYint];

    for (int i = 0; i < TYMAX; i++)
    {
        if (tstypes[i])
        {   tsptr2types[i] = type_allocn(pointertype,tstypes[i]);
            tsptr2types[i].Tcount++;
        }
    }
}

/**********************************
 * Free type_list.
 */

void type_term()
{
static if (TERMCODE)
{
    type *tn;
    param_t *pn;
    int i;

    for (i = 0; i < tstypes.length; i++)
    {   type *t = tsptr2types[i];

        if (t)
        {   assert(!(t.Tty & (mTYconst | mTYvolatile | mTYimmutable | mTYshared)));
            assert(!(t.Tflags));
            assert(!(t.Tmangle));
            type_free(t);
        }
        type_free(tstypes[i]);
    }

    type_free(tsclib);
    type_free(tspvoid);
    type_free(tspcvoid);
    type_free(tsjlib);
    type_free(tstrace);

    while (type_list)
    {   tn = type_list.Tnext;
        mem_ffree(type_list);
        type_list = tn;
    }

    while (param_list)
    {   pn = param_list.Pnext;
        mem_ffree(param_list);
        param_list = pn;
    }

debug
{
    printf("Max # of types = %d\n",type_max);
    if (type_num != 0)
        printf("type_num = %d\n",type_num);
/*    assert(type_num == 0);*/
}

}
}

/*******************************
 * Type type information.
 */

/**************************
 * Make copy of a type.
 */

@trusted
type *type_copy(type *t)
{   type *tn;
    param_t *p;

    type_debug(t);
version (SCPP_HTOD)
{
    if (tybasic(t.Tty) == TYtemplate)
    {
        tn = type_alloc_template((cast(typetemp_t *)t).Tsym);
    }
    else
        tn = type_alloc(t.Tty);
}
else
        tn = type_alloc(t.Tty);

    *tn = *t;
    switch (tybasic(tn.Tty))
    {
version (SCPP_HTOD)
{
            case TYtemplate:
                (cast(typetemp_t *)tn).Tsym = (cast(typetemp_t *)t).Tsym;
                goto L1;

            case TYident:
                tn.Tident = cast(char *)MEM_PH_STRDUP(t.Tident);
                break;
}

            case TYarray:
                if (tn.Tflags & TFvla)
                    tn.Tel = el_copytree(tn.Tel);
                break;

            default:
                if (tyfunc(tn.Tty))
                {
                L1:
                    tn.Tparamtypes = null;
                    for (p = t.Tparamtypes; p; p = p.Pnext)
                    {   param_t *pn;

                        pn = param_append_type(&tn.Tparamtypes,p.Ptype);
                        if (p.Pident)
                        {
                            pn.Pident = cast(char *)MEM_PH_STRDUP(p.Pident);
                        }
                        assert(!p.Pelem);
                    }
                }
                else
                {
version (SCPP_HTOD)
{
                if (tn.Talternate && typtr(tn.Tty))
                    tn.Talternate.Tcount++;
}
version (MARS)
{
                if (tn.Tkey && typtr(tn.Tty))
                    tn.Tkey.Tcount++;
}
                }
                break;
    }
    if (tn.Tnext)
    {   type_debug(tn.Tnext);
        tn.Tnext.Tcount++;
    }
    tn.Tcount = 0;
    return tn;
}

/************************************
 */

version (SCPP_HTOD)
{

elem *type_vla_fix(type **pt)
{
    type *t;
    elem *e = null;

    for (t = *pt; t; t = t.Tnext)
    {
        type_debug(t);
        if (tybasic(t.Tty) == TYarray && t.Tflags & TFvla && t.Tel)
        {   Symbol *s;
            elem *ec;

            s = symbol_genauto(tstypes[TYuint]);
            ec = el_var(s);
            ec = el_bint(OPeq, tstypes[TYuint], ec, t.Tel);
            e = el_combine(e, ec);
            t.Tel = el_var(s);
        }
    }
    return e;
}

}

/****************************
 * Modify the tym_t field of a type.
 */

type *type_setty(type **pt,uint newty)
{   type *t;

    t = *pt;
    type_debug(t);
    if (cast(tym_t)newty != t.Tty)
    {   if (t.Tcount > 1)              /* if other people pointing at t */
        {   type *tn;

            tn = type_copy(t);
            tn.Tcount++;
            type_free(t);
            t = tn;
            *pt = t;
        }
        t.Tty = newty;
    }
    return t;
}

/******************************
 * Set type field of some object to t.
 */

type *type_settype(type **pt, type *t)
{
    if (t)
    {   type_debug(t);
        t.Tcount++;
    }
    type_free(*pt);
    return *pt = t;
}

/****************************
 * Modify the Tmangle field of a type.
 */

type *type_setmangle(type **pt,mangle_t mangle)
{   type *t;

    t = *pt;
    type_debug(t);
    if (mangle != type_mangle(t))
    {
        if (t.Tcount > 1)              // if other people pointing at t
        {   type *tn;

            tn = type_copy(t);
            tn.Tcount++;
            type_free(t);
            t = tn;
            *pt = t;
        }
        t.Tmangle = mangle;
    }
    return t;
}

/******************************
 * Set/clear const and volatile bits in *pt according to the settings
 * in cv.
 */

type *type_setcv(type **pt,tym_t cv)
{   uint ty;

    type_debug(*pt);
    ty = (*pt).Tty & ~(mTYconst | mTYvolatile | mTYimmutable | mTYshared);
    return type_setty(pt,ty | (cv & (mTYconst | mTYvolatile | mTYimmutable | mTYshared)));
}

/*****************************
 * Set dimension of array.
 */

type *type_setdim(type **pt,targ_size_t dim)
{   type *t = *pt;

    type_debug(t);
    if (t.Tcount > 1)                  /* if other people pointing at t */
    {   type *tn;

        tn = type_copy(t);
        tn.Tcount++;
        type_free(t);
        t = tn;
    }
    t.Tflags &= ~TFsizeunknown; /* we have determined its size */
    t.Tdim = dim;              /* index of array               */
    return *pt = t;
}


/*****************************
 * Create a 'dependent' version of type t.
 */

type *type_setdependent(type *t)
{
    type_debug(t);
    if (t.Tcount > 0 &&                        /* if other people pointing at t */
        !(t.Tflags & TFdependent))
    {
        t = type_copy(t);
    }
    t.Tflags |= TFdependent;
    return t;
}

/************************************
 * Determine if type t is a dependent type.
 */

@trusted
int type_isdependent(type *t)
{
    Symbol *stempl;
    type *tstart;

    //printf("type_isdependent(%p)\n", t);
    //type_print(t);
    for (tstart = t; t; t = t.Tnext)
    {
        type_debug(t);
        if (t.Tflags & TFdependent)
            goto Lisdependent;
        if (tyfunc(t.Tty)
                || tybasic(t.Tty) == TYtemplate
                )
        {
            for (param_t *p = t.Tparamtypes; p; p = p.Pnext)
            {
                if (p.Ptype && type_isdependent(p.Ptype))
                    goto Lisdependent;
                if (p.Pelem && el_isdependent(p.Pelem))
                    goto Lisdependent;
            }
        }
        else if (type_struct(t) &&
                 (stempl = t.Ttag.Sstruct.Stempsym) != null)
        {
            for (param_t *p = t.Ttag.Sstruct.Sarglist; p; p = p.Pnext)
            {
                if (p.Ptype && type_isdependent(p.Ptype))
                    goto Lisdependent;
                if (p.Pelem && el_isdependent(p.Pelem))
                    goto Lisdependent;
            }
        }
    }
    //printf("\tis not dependent\n");
    return 0;

Lisdependent:
    //printf("\tis dependent\n");
    // Dependence on a dependent type makes this type dependent as well
    tstart.Tflags |= TFdependent;
    return 1;
}


/*******************************
 * Recursively check if type u is embedded in type t.
 * Returns:
 *      != 0 if embedded
 */

@trusted
int type_embed(type *t,type *u)
{   param_t *p;

    for (; t; t = t.Tnext)
    {
        type_debug(t);
        if (t == u)
            return 1;
        if (tyfunc(t.Tty))
        {
            for (p = t.Tparamtypes; p; p = p.Pnext)
                if (type_embed(p.Ptype,u))
                    return 1;
        }
    }
    return 0;
}


/***********************************
 * Determine if type is a VLA.
 */

int type_isvla(type *t)
{
    while (t)
    {
        if (tybasic(t.Tty) != TYarray)
            break;
        if (t.Tflags & TFvla)
            return 1;
        t = t.Tnext;
    }
    return 0;
}


/**********************************
 * Pretty-print a type.
 */

@trusted
void type_print(const type *t)
{
  type_debug(t);
  printf("Tty="); WRTYxx(t.Tty);
  printf(" Tmangle=%d",t.Tmangle);
  printf(" Tflags=x%x",t.Tflags);
  printf(" Tcount=%d",t.Tcount);
  if (!(t.Tflags & TFsizeunknown) &&
        tybasic(t.Tty) != TYvoid &&
        tybasic(t.Tty) != TYident &&
        tybasic(t.Tty) != TYtemplate &&
        tybasic(t.Tty) != TYmfunc &&
        tybasic(t.Tty) != TYarray)
      printf(" Tsize=%lld", cast(long)type_size(t));
  printf(" Tnext=%p",t.Tnext);
  switch (tybasic(t.Tty))
  {     case TYstruct:
        case TYmemptr:
            printf(" Ttag=%p,'%s'",t.Ttag,t.Ttag.Sident.ptr);
            //printf(" Sfldlst=%p",t.Ttag.Sstruct.Sfldlst);
            break;

        case TYarray:
            printf(" Tdim=%lld", cast(long)t.Tdim);
            break;

        case TYident:
            printf(" Tident='%s'",t.Tident);
            break;
        case TYtemplate:
            printf(" Tsym='%s'",(cast(typetemp_t *)t).Tsym.Sident.ptr);
            {
                int i;

                i = 1;
                for (const(param_t)* p = t.Tparamtypes; p; p = p.Pnext)
                {   printf("\nTP%d (%p): ",i++,p);
                    fflush(stdout);

printf("Pident=%p,Ptype=%p,Pelem=%p,Pnext=%p ",p.Pident,p.Ptype,p.Pelem,p.Pnext);
                    param_debug(p);
                    if (p.Pident)
                        printf("'%s' ", p.Pident);
                    if (p.Ptype)
                        type_print(p.Ptype);
                    if (p.Pelem)
                        elem_print(p.Pelem);
                }
            }
            break;

        default:
            if (tyfunc(t.Tty))
            {
                int i;

                i = 1;
                for (const(param_t)* p = t.Tparamtypes; p; p = p.Pnext)
                {   printf("\nP%d (%p): ",i++,p);
                    fflush(stdout);

printf("Pident=%p,Ptype=%p,Pelem=%p,Pnext=%p ",p.Pident,p.Ptype,p.Pelem,p.Pnext);
                    param_debug(p);
                    if (p.Pident)
                        printf("'%s' ", p.Pident);
                    type_print(p.Ptype);
                }
            }
            break;
  }
  printf("\n");
  if (t.Tnext) type_print(t.Tnext);
}

/*******************************
 * Pretty-print a param_t
 */

@trusted
void param_t_print(const param_t* p)
{
    printf("Pident=%p,Ptype=%p,Pelem=%p,Psym=%p,Pnext=%p\n",p.Pident,p.Ptype,p.Pelem,p.Psym,p.Pnext);
    if (p.Pident)
        printf("\tPident = '%s'\n", p.Pident);
    if (p.Ptype)
    {   printf("\tPtype =\n");
        type_print(p.Ptype);
    }
    if (p.Pelem)
    {   printf("\tPelem =\n");
        elem_print(p.Pelem);
    }
    if (p.Pdeftype)
    {   printf("\tPdeftype =\n");
        type_print(p.Pdeftype);
    }
    if (p.Psym)
    {   printf("\tPsym = '%s'\n", p.Psym.Sident.ptr);
    }
    if (p.Pptpl)
    {   printf("\tPptpl = %p\n", p.Pptpl);
    }
}

void param_t_print_list(param_t* p)
{
    for (; p; p = p.Pnext)
        p.print();
}


/**********************************
 * Hydrate a type.
 */

version (SCPP_HTOD)
{

static if (HYDRATE)
{
void type_hydrate(type **pt)
{
    type *t;

    assert(pt);
    while (isdehydrated(*pt))
    {
        t = cast(type *) ph_hydrate(cast(void**)pt);
        type_debug(t);
        switch (tybasic(t.Tty))
        {
            case TYstruct:
            case TYenum:
            case TYmemptr:
            case TYvtshape:
                // Cannot assume symbol is hydrated, because entire HX file
                // may not have been hydrated.
                Classsym_hydrate(&t.Ttag);
                symbol_debug(t.Ttag);
                break;
            case TYident:
                ph_hydrate(cast(void**)&t.Tident);
                break;
            case TYtemplate:
                symbol_hydrate(&(cast(typetemp_t *)t).Tsym);
                param_hydrate(&t.Tparamtypes);
                break;
            case TYarray:
                if (t.Tflags & TFvla)
                    el_hydrate(&t.Tel);
                break;
            default:
                if (tyfunc(t.Tty))
                {   param_hydrate(&t.Tparamtypes);
                    list_hydrate(&t.Texcspec, cast(list_free_fp)&type_hydrate);
                }
                else if (t.Talternate && typtr(t.Tty))
                    type_hydrate(&t.Talternate);
                else if (t.Tkey && typtr(t.Tty))
                    type_hydrate(&t.Tkey);
                break;
        }
        pt = &t.Tnext;
    }
}
}

/**********************************
 * Dehydrate a type.
 */

static if (DEHYDRATE)
{
void type_dehydrate(type **pt)
{
    type *t;

    while ((t = *pt) != null && !isdehydrated(t))
    {
        ph_dehydrate(pt);
version (DEBUG_XSYMGEN)
{
        /* don't dehydrate types in HEAD when creating XSYM */
        if (xsym_gen && (t.Tflags & TFhydrated))
            return;
}
        type_debug(t);
        switch (tybasic(t.Tty))
        {
            case TYstruct:
            case TYenum:
            case TYmemptr:
            case TYvtshape:
                Classsym_dehydrate(&t.Ttag);
                break;
            case TYident:
                ph_dehydrate(&t.Tident);
                break;
            case TYtemplate:
                symbol_dehydrate(&(cast(typetemp_t *)t).Tsym);
                param_dehydrate(&t.Tparamtypes);
                break;
            case TYarray:
                if (t.Tflags & TFvla)
                    el_dehydrate(&t.Tel);
                break;
            default:
                if (tyfunc(t.Tty))
                {   param_dehydrate(&t.Tparamtypes);
                    list_dehydrate(&t.Texcspec, cast(list_free_fp)&type_dehydrate);
                }
                else if (t.Talternate && typtr(t.Tty))
                    type_dehydrate(&t.Talternate);
                else if (t.Tkey && typtr(t.Tty))
                    type_dehydrate(&t.Tkey);
                break;
        }
        pt = &t.Tnext;
    }
}
}

}

/****************************
 * Allocate a param_t.
 */

@trusted
param_t *param_calloc()
{
    static param_t pzero;
    param_t *p;

    if (param_list)
    {
        p = param_list;
        param_list = p.Pnext;
    }
    else
    {
        p = cast(param_t *) mem_fmalloc(param_t.sizeof);
    }
    *p = pzero;

    debug p.id = param_t.IDparam;

    return p;
}

/***************************
 * Allocate a param_t of type t, and append it to parameter list.
 */

param_t *param_append_type(param_t **pp,type *t)
{   param_t *p;

    p = param_calloc();
    while (*pp)
    {   param_debug(*pp);
        pp = &((*pp).Pnext);   /* find end of list     */
    }
    *pp = p;                    /* append p to list     */
    type_debug(t);
    p.Ptype = t;
    t.Tcount++;
    return p;
}

/************************
 * Version of param_free() suitable for list_free().
 */

@trusted
void param_free_l(param_t *p)
{
    param_free(&p);
}

/***********************
 * Free parameter list.
 * Output:
 *      paramlst = null
 */

@trusted
void param_free(param_t **pparamlst)
{   param_t* p,pn;

    //debug_assert(PARSER);
    for (p = *pparamlst; p; p = pn)
    {   param_debug(p);
        pn = p.Pnext;
        type_free(p.Ptype);
        mem_free(p.Pident);
        el_free(p.Pelem);
        type_free(p.Pdeftype);
        if (p.Pptpl)
            param_free(&p.Pptpl);

        debug p.id = 0;

        p.Pnext = param_list;
        param_list = p;
    }
    *pparamlst = null;
}

/***********************************
 * Compute number of parameters
 */

uint param_t_length(param_t* p)
{
    uint nparams = 0;

    for (; p; p = p.Pnext)
        nparams++;
    return nparams;
}

/*************************************
 * Create template-argument-list blank from
 * template-parameter-list
 * Input:
 *      ptali   initial template-argument-list
 */

@trusted
param_t *param_t_createTal(param_t* p, param_t *ptali)
{
version (SCPP_HTOD)
{
    param_t *ptalistart = ptali;
    param_t *pstart = p;
}
    param_t *ptal = null;
    param_t **pp = &ptal;

    for (; p; p = p.Pnext)
    {
        *pp = param_calloc();
        if (p.Pident)
        {
            // Should find a way to just point rather than dup
            (*pp).Pident = cast(char *)MEM_PH_STRDUP(p.Pident);
        }
        if (ptali)
        {
            if (ptali.Ptype)
            {   (*pp).Ptype = ptali.Ptype;
                (*pp).Ptype.Tcount++;
            }
            if (ptali.Pelem)
            {
                elem *e = el_copytree(ptali.Pelem);
version (SCPP_HTOD)
{
                if (p.Ptype)
                {   type *t = p.Ptype;
                    t = template_tyident(t, ptalistart, pstart, 1);
                    e = poptelem3(typechk(e, t));
                    type_free(t);
                }
}
                (*pp).Pelem = e;
            }
            (*pp).Psym = ptali.Psym;
            (*pp).Pflags = ptali.Pflags;
            assert(!ptali.Pptpl);
            ptali = ptali.Pnext;
        }
        pp = &(*pp).Pnext;
    }
    return ptal;
}

/**********************************
 * Look for Pident matching id
 */

@trusted
param_t *param_t_search(param_t* p, char *id)
{
    for (; p; p = p.Pnext)
    {
        if (p.Pident && strcmp(p.Pident, id) == 0)
            break;
    }
    return p;
}

/**********************************
 * Look for Pident matching id
 */

@trusted
int param_t_searchn(param_t* p, char *id)
{
    int n = 0;

    for (; p; p = p.Pnext)
    {
        if (p.Pident && strcmp(p.Pident, id) == 0)
            return n;
        n++;
    }
    return -1;
}

/*************************************
 * Search for member, create symbol as needed.
 * Used for symbol tables for VLA's such as:
 *      void func(int n, int a[n]);
 */

@trusted
Symbol *param_search(const(char)* name, param_t **pp)
{   Symbol *s = null;
    param_t *p;

    p = (*pp).search(cast(char *)name);
    if (p)
    {
        s = p.Psym;
        if (!s)
        {
            s = symbol_calloc(p.Pident);
            s.Sclass = SCparameter;
            s.Stype = p.Ptype;
            s.Stype.Tcount++;
            p.Psym = s;
        }
    }
    return s;
}

/**********************************
 * Hydrate/dehydrate a type.
 */

version (SCPP_HTOD)
{
static if (HYDRATE)
{
void param_hydrate(param_t **pp)
{
    param_t *p;

    assert(pp);
    if (isdehydrated(*pp))
    {   while (*pp)
        {   assert(isdehydrated(*pp));
            p = cast(param_t *) ph_hydrate(cast(void**)pp);
            param_debug(p);

            type_hydrate(&p.Ptype);
            if (p.Ptype)
                type_debug(p.Ptype);
            ph_hydrate(cast(void**)&p.Pident);
            if (CPP)
            {
                el_hydrate(&p.Pelem);
                if (p.Pelem)
                    elem_debug(p.Pelem);
                type_hydrate(&p.Pdeftype);
                if (p.Pptpl)
                    param_hydrate(&p.Pptpl);
                if (p.Psym)
                    symbol_hydrate(&p.Psym);
                if (p.PelemToken)
                    token_hydrate(&p.PelemToken);
            }

            pp = &p.Pnext;
        }
    }
}
}

static if (DEHYDRATE)
{
void param_dehydrate(param_t **pp)
{
    param_t *p;

    assert(pp);
    while ((p = *pp) != null && !isdehydrated(p))
    {   param_debug(p);

        ph_dehydrate(pp);
        if (p.Ptype && !isdehydrated(p.Ptype))
            type_debug(p.Ptype);
        type_dehydrate(&p.Ptype);
        ph_dehydrate(&p.Pident);
        if (CPP)
        {
            el_dehydrate(&p.Pelem);
            type_dehydrate(&p.Pdeftype);
            if (p.Pptpl)
                param_dehydrate(&p.Pptpl);
            if (p.Psym)
                symbol_dehydrate(&p.Psym);
            if (p.PelemToken)
                token_dehydrate(&p.PelemToken);
        }
        pp = &p.Pnext;
    }
}
}
}

version (MARS)
{

// Return TRUE if type lists match.
private int paramlstmatch(param_t *p1,param_t *p2)
{
        return p1 == p2 ||
            p1 && p2 && typematch(p1.Ptype,p2.Ptype,0) &&
            paramlstmatch(p1.Pnext,p2.Pnext)
            ;
}

/*************************************************
 * A cheap version of exp2.typematch() and exp2.paramlstmatch(),
 * so that we can get cpp_mangle() to work for MARS.
 * It's less complex because it doesn't do templates and
 * can rely on strict typechecking.
 * Returns:
 *      !=0 if types match.
 */

@trusted
int typematch(type *t1,type *t2,int relax)
{ tym_t t1ty, t2ty;
  tym_t tym;

  tym = ~(mTYimport | mTYnaked);

  return t1 == t2 ||
            t1 && t2 &&

            (
                /* ignore name mangling */
                (t1ty = (t1.Tty & tym)) == (t2ty = (t2.Tty & tym))
            )
                 &&

            (tybasic(t1ty) != TYarray || t1.Tdim == t2.Tdim ||
             t1.Tflags & TFsizeunknown || t2.Tflags & TFsizeunknown)
                 &&

            (tybasic(t1ty) != TYstruct
                && tybasic(t1ty) != TYenum
                && tybasic(t1ty) != TYmemptr
             || t1.Ttag == t2.Ttag)
                 &&

            typematch(t1.Tnext,t2.Tnext, 0)
                 &&

            (!tyfunc(t1ty) ||
             ((t1.Tflags & TFfixed) == (t2.Tflags & TFfixed) &&
                 paramlstmatch(t1.Tparamtypes,t2.Tparamtypes) ))
         ;
}

}

}
