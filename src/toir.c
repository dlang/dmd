
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/* Code to help convert to the intermediate representation
 * of the compiler back end.
 */

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        <complex.h>

#include        "lexer.h"
#include        "expression.h"
#include        "mtype.h"
#include        "dsymbol.h"
#include        "declaration.h"
#include        "enum.h"
#include        "aggregate.h"
#include        "attrib.h"
#include        "module.h"
#include        "init.h"
#include        "template.h"
#include        "target.h"

#include        "mem.h" // for mem_malloc

#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "global.h"
#include        "code.h"
#include        "type.h"
#include        "dt.h"
#include        "irstate.h"
#include        "id.h"
#include        "type.h"
#include        "toir.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/*********************************************
 * Produce elem which increments the usage count for a particular line.
 * Used to implement -cov switch (coverage analysis).
 */

elem *incUsageElem(IRState *irs, Loc loc)
{
    unsigned linnum = loc.linnum;

    if (!irs->blx->module->cov || !linnum ||
        loc.filename != irs->blx->module->srcfile->toChars())
        return NULL;

    //printf("cov = %p, covb = %p, linnum = %u\n", irs->blx->module->cov, irs->blx->module->covb, p, linnum);

    linnum--;           // from 1-based to 0-based

    /* Set bit in covb[] indicating this is a valid code line number
     */
    unsigned *p = irs->blx->module->covb;
    if (p)      // covb can be NULL if it has already been written out to its .obj file
    {
        p += linnum / (sizeof(*p) * 8);
        *p |= 1 << (linnum & (sizeof(*p) * 8 - 1));
    }

    elem *e;
    e = el_ptr(irs->blx->module->cov);
    e = el_bin(OPadd, TYnptr, e, el_long(TYuint, linnum * 4));
    e = el_una(OPind, TYuint, e);
    e = el_bin(OPaddass, TYuint, e, el_long(TYuint, 1));
    return e;
}

/******************************************
 * Return elem that evaluates to the static frame pointer for function fd.
 * If fd is a member function, the returned expression will compute the value
 * of fd's 'this' variable.
 * This routine is critical for implementing nested functions.
 */

elem *getEthis(Loc loc, IRState *irs, Dsymbol *fd)
{
    elem *ethis;
    FuncDeclaration *thisfd = irs->getFunc();
    Dsymbol *fdparent = fd->toParent2();

    //printf("getEthis(thisfd = '%s', fd = '%s', fdparent = '%s')\n", thisfd->toPrettyChars(), fd->toPrettyChars(), fdparent->toPrettyChars());
    if (fdparent == thisfd ||
        /* These two are compiler generated functions for the in and out contracts,
         * and are called from an overriding function, not just the one they're
         * nested inside, so this hack is so they'll pass
         */
        fd->ident == Id::require || fd->ident == Id::ensure)
    {   /* Going down one nesting level, i.e. we're calling
         * a nested function from its enclosing function.
         */
#if DMDV2
        if (irs->sclosure)
            ethis = el_var(irs->sclosure);
        else
#endif
        if (irs->sthis)
        {   // We have a 'this' pointer for the current function
            ethis = el_var(irs->sthis);

            /* If no variables in the current function's frame are
             * referenced by nested functions, then we can 'skip'
             * adding this frame into the linked list of stack
             * frames.
             */
            if (thisfd->hasNestedFrameRefs())
            {   /* Local variables are referenced, can't skip.
                 * Address of 'this' gives the 'this' for the nested
                 * function
                 */
                ethis = el_una(OPaddr, TYnptr, ethis);
            }
        }
        else
        {   /* No 'this' pointer for current function,
             * use NULL if no references to the current function's frame
             */
            ethis = el_long(TYnptr, 0);
            if (thisfd->hasNestedFrameRefs())
            {   /* OPframeptr is an operator that gets the frame pointer
                 * for the current function, i.e. for the x86 it gets
                 * the value of EBP
                 */
                ethis->Eoper = OPframeptr;
            }
        }
//if (fdparent != thisfd) ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYint, 0x18));
    }
    else
    {
        if (!irs->sthis)                // if no frame pointer for this function
        {
            fd->error(loc, "is a nested function and cannot be accessed from %s", irs->getFunc()->toChars());
            ethis = el_long(TYnptr, 0); // error recovery
        }
        else
        {
            ethis = el_var(irs->sthis);
            Dsymbol *s = thisfd;
            while (fd != s)
            {   /* Go up a nesting level, i.e. we need to find the 'this'
                 * of an enclosing function.
                 * Our 'enclosing function' may also be an inner class.
                 */

                //printf("\ts = '%s'\n", s->toChars());
                thisfd = s->isFuncDeclaration();
                if (thisfd)
                {   /* Enclosing function is a function.
                     */
                    if (fdparent == s->toParent2())
                        break;
                    if (thisfd->isNested())
                    {
                        FuncDeclaration *p = s->toParent2()->isFuncDeclaration();
                        if (!p || p->hasNestedFrameRefs())
                            ethis = el_una(OPind, TYnptr, ethis);
                    }
                    else if (thisfd->vthis)
                    {
                    }
                    else
                        // Error should have been caught by front end
                        assert(0);
                }
                else
                {   /* Enclosed by an aggregate. That means the current
                     * function must be a member function of that aggregate.
                     */
                    ClassDeclaration *cd = s->isClassDeclaration();
                    if (!cd)
                        goto Lnoframe;
                    if (//cd->baseClass == fd ||
                        fd->isClassDeclaration() &&
                        fd->isClassDeclaration()->isBaseOf(cd, NULL))
                        break;
                    if (!cd->isNested() || !cd->vthis)
                    {
                      Lnoframe:
                        irs->getFunc()->error(loc, "cannot get frame pointer to %s", fd->toChars());
                        return el_long(TYnptr, 0);      // error recovery
                    }
                    ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYsize_t, cd->vthis->offset));
                    ethis = el_una(OPind, TYnptr, ethis);
                    if (fdparent == s->toParent2())
                        break;
                    if (fd == s->toParent2())
                    {
                        /* Remember that frames for functions that have no
                         * nested references are skipped in the linked list
                         * of frames.
                         */
                        if (s->toParent2()->isFuncDeclaration()->hasNestedFrameRefs())
                            ethis = el_una(OPind, TYnptr, ethis);
                        break;
                    }
                    if (s->toParent2()->isFuncDeclaration())
                    {
                        /* Remember that frames for functions that have no
                         * nested references are skipped in the linked list
                         * of frames.
                         */
                        if (s->toParent2()->isFuncDeclaration()->hasNestedFrameRefs())
                            ethis = el_una(OPind, TYnptr, ethis);
                    }
                }
                s = s->toParent2();
                assert(s);
            }
        }
    }
#if 0
    printf("ethis:\n");
    elem_print(ethis);
    printf("\n");
#endif
    return ethis;
}


/*************************
 * Initialize the hidden aggregate member, vthis, with
 * the context pointer.
 * Returns:
 *      *(ey + ad.vthis.offset) = this;
 */
#if DMDV2
elem *setEthis(Loc loc, IRState *irs, elem *ey, AggregateDeclaration *ad)
{
    elem *ethis;
    FuncDeclaration *thisfd = irs->getFunc();
    int offset = 0;
    Dsymbol *cdp = ad->toParent2();     // class/func we're nested in

    //printf("setEthis(ad = %s, cdp = %s, thisfd = %s)\n", ad->toChars(), cdp->toChars(), thisfd->toChars());

    if (cdp == thisfd)
    {   /* Class we're new'ing is a local class in this function:
         *      void thisfd() { class ad { } }
         */
        if (irs->sclosure)
            ethis = el_var(irs->sclosure);
        else if (irs->sthis)
        {
            if (thisfd->hasNestedFrameRefs())
            {
                ethis = el_ptr(irs->sthis);
            }
            else
                ethis = el_var(irs->sthis);
        }
        else
        {
            ethis = el_long(TYnptr, 0);
            if (thisfd->hasNestedFrameRefs())
            {
                ethis->Eoper = OPframeptr;
            }
        }
    }
    else if (thisfd->vthis &&
          (cdp == thisfd->toParent2() ||
           (cdp->isClassDeclaration() &&
            cdp->isClassDeclaration()->isBaseOf(thisfd->toParent2()->isClassDeclaration(), &offset)
           )
          )
        )
    {   /* Class we're new'ing is at the same level as thisfd
         */
        assert(offset == 0);    // BUG: should handle this case
        ethis = el_var(irs->sthis);
    }
    else
    {
        ethis = getEthis(loc, irs, ad->toParent2());
        ethis = el_una(OPaddr, TYnptr, ethis);
    }

    ey = el_bin(OPadd, TYnptr, ey, el_long(TYsize_t, ad->vthis->offset));
    ey = el_una(OPind, TYnptr, ey);
    ey = el_bin(OPeq, TYnptr, ey, ethis);
    return ey;
}
#endif

/*******************************************
 * Convert intrinsic function to operator.
 * Returns that operator, -1 if not an intrinsic function.
 */

int intrinsic_op(char *name)
{
#if TX86
    //printf("intrinsic_op(%s)\n", name);
    static const char *namearray[] =
    {
#if DMDV1
        "4math3cosFeZe",
        "4math3sinFeZe",
        "4math4fabsFeZe",
        "4math4rintFeZe",
        "4math4sqrtFdZd",
        "4math4sqrtFeZe",
        "4math4sqrtFfZf",
        "4math4yl2xFeeZe",
        "4math5ldexpFeiZe",
        "4math6rndtolFeZl",
        "4math6yl2xp1FeeZe",

        "9intrinsic2btFPkkZi",
        "9intrinsic3bsfFkZi",
        "9intrinsic3bsrFkZi",
        "9intrinsic3btcFPkkZi",
        "9intrinsic3btrFPkkZi",
        "9intrinsic3btsFPkkZi",
        "9intrinsic3inpFkZh",
        "9intrinsic4inplFkZk",
        "9intrinsic4inpwFkZt",
        "9intrinsic4outpFkhZh",
        "9intrinsic5bswapFkZk",
        "9intrinsic5outplFkkZk",
        "9intrinsic5outpwFktZt",
#elif DMDV2
        /* The names are mangled differently because of the pure and
         * nothrow attributes.
         */
        "4math3cosFNaNbNfeZe",
        "4math3sinFNaNbNfeZe",
        "4math4fabsFNaNbNfeZe",
        "4math4rintFNaNbNfeZe",
        "4math4sqrtFNaNbNfdZd",
        "4math4sqrtFNaNbNfeZe",
        "4math4sqrtFNaNbNffZf",
        "4math4yl2xFNaNbNfeeZe",
        "4math5ldexpFNaNbNfeiZe",
        "4math6rndtolFNaNbNfeZl",
        "4math6yl2xp1FNaNbNfeeZe",

        "9intrinsic2btFNaNbxPkkZi",
        "9intrinsic3bsfFNaNbkZi",
        "9intrinsic3bsrFNaNbkZi",
        "9intrinsic3btcFNbPkkZi",
        "9intrinsic3btrFNbPkkZi",
        "9intrinsic3btsFNbPkkZi",
        "9intrinsic3inpFNbkZh",
        "9intrinsic4inplFNbkZk",
        "9intrinsic4inpwFNbkZt",
        "9intrinsic4outpFNbkhZh",
        "9intrinsic5bswapFNaNbkZk",
        "9intrinsic5outplFNbkkZk",
        "9intrinsic5outpwFNbktZt",
#endif
    };
    static const char *namearray64[] =
    {
#if DMDV1
        "4math3cosFeZe",
        "4math3sinFeZe",
        "4math4fabsFeZe",
        "4math4rintFeZe",
        "4math4sqrtFdZd",
        "4math4sqrtFeZe",
        "4math4sqrtFfZf",
        "4math4yl2xFeeZe",
        "4math5ldexpFeiZe",
        "4math6rndtolFeZl",
        "4math6yl2xp1FeeZe",

        "9intrinsic2btFPmmZi",
        "9intrinsic3bsfFmZi",
        "9intrinsic3bsrFmZi",
        "9intrinsic3btcFPmmZi",
        "9intrinsic3btrFPmmZi",
        "9intrinsic3btsFPmmZi",
        "9intrinsic3inpFkZh",
        "9intrinsic4inplFkZk",
        "9intrinsic4inpwFkZt",
        "9intrinsic4outpFkhZh",
        "9intrinsic5bswapFkZk",
        "9intrinsic5outplFkkZk",
        "9intrinsic5outpwFktZt",
#elif DMDV2
        /* The names are mangled differently because of the pure and
         * nothrow attributes.
         */
        "4math3cosFNaNbNfeZe",
        "4math3sinFNaNbNfeZe",
        "4math4fabsFNaNbNfeZe",
        "4math4rintFNaNbNfeZe",
        "4math4sqrtFNaNbNfdZd",
        "4math4sqrtFNaNbNfeZe",
        "4math4sqrtFNaNbNffZf",
        "4math4yl2xFNaNbNfeeZe",
        "4math5ldexpFNaNbNfeiZe",
        "4math6rndtolFNaNbNfeZl",
        "4math6yl2xp1FNaNbNfeeZe",

        "9intrinsic2btFNaNbxPkkZi",
        "9intrinsic3bsfFNaNbkZi",
        "9intrinsic3bsrFNaNbkZi",
        "9intrinsic3btcFNbPmmZi",
        "9intrinsic3btrFNbPmmZi",
        "9intrinsic3btsFNbPmmZi",
        "9intrinsic3inpFNbkZh",
        "9intrinsic4inplFNbkZk",
        "9intrinsic4inpwFNbkZt",
        "9intrinsic4outpFNbkhZh",
        "9intrinsic5bswapFNaNbkZk",
        "9intrinsic5outplFNbkkZk",
        "9intrinsic5outpwFNbktZt",
#endif
    };
    static unsigned char ioptab[] =
    {
        OPcos,
        OPsin,
        OPabs,
        OPrint,
        OPsqrt,
        OPsqrt,
        OPsqrt,
        OPyl2x,
        OPscale,
        OPrndtol,
        OPyl2xp1,

        OPbt,
        OPbsf,
        OPbsr,
        OPbtc,
        OPbtr,
        OPbts,
        OPinp,
        OPinp,
        OPinp,
        OPoutp,
        OPbswap,
        OPoutp,
        OPoutp,
    };

#ifdef DEBUG
    assert(sizeof(namearray) == sizeof(namearray64));
    assert(sizeof(namearray) / sizeof(char *) == sizeof(ioptab));
    for (size_t i = 0; i < sizeof(namearray) / sizeof(char *) - 1; i++)
    {
        if (strcmp(namearray[i], namearray[i + 1]) >= 0)
        {
            printf("namearray[%ld] = '%s'\n", (long)i, namearray[i]);
            assert(0);
        }
    }
    assert(sizeof(namearray64) / sizeof(char *) == sizeof(ioptab));
    for (size_t i = 0; i < sizeof(namearray64) / sizeof(char *) - 1; i++)
    {
        if (strcmp(namearray64[i], namearray64[i + 1]) >= 0)
        {
            printf("namearray64[%ld] = '%s'\n", (long)i, namearray64[i]);
            assert(0);
        }
    }
#endif

    size_t length = strlen(name);
    if (length < 11 ||
        !(name[7] == 'm' || name[7] == 'i') ||
        memcmp(name, "_D3std", 6) != 0)
        return -1;

    int i = binary(name + 6, I64 ? namearray64 : namearray, sizeof(namearray) / sizeof(char *));
    return (i == -1) ? i : ioptab[i];
#endif

    return -1;
}


/**************************************
 * Given an expression e that is an array,
 * determine and set the 'length' variable.
 * Input:
 *      lengthVar       Symbol of 'length' variable
 *      &e      expression that is the array
 *      t1      Type of the array
 * Output:
 *      e       is rewritten to avoid side effects
 * Returns:
 *      expression that initializes 'length'
 */

elem *resolveLengthVar(VarDeclaration *lengthVar, elem **pe, Type *t1)
{
    //printf("resolveLengthVar()\n");
    elem *einit = NULL;

    if (lengthVar && !(lengthVar->storage_class & STCconst))
    {   elem *elength;
        Symbol *slength;

        if (t1->ty == Tsarray)
        {   TypeSArray *tsa = (TypeSArray *)t1;
            dinteger_t length = tsa->dim->toInteger();

            elength = el_long(TYsize_t, length);
            goto L3;
        }
        else if (t1->ty == Tarray)
        {
            elength = *pe;
            *pe = el_same(&elength);
            elength = el_una(I64 ? OP128_64 : OP64_32, TYsize_t, elength);

        L3:
            slength = lengthVar->toSymbol();
            //symbol_add(slength);

            einit = el_bin(OPeq, TYsize_t, el_var(slength), elength);
        }
    }
    return einit;
}

/*************************************
 * Closures are implemented by taking the local variables that
 * need to survive the scope of the function, and copying them
 * into a gc allocated chuck of memory. That chunk, called the
 * closure here, is inserted into the linked list of stack
 * frames instead of the usual stack frame.
 *
 * buildClosure() inserts code just after the function prolog
 * is complete. It allocates memory for the closure, allocates
 * a local variable (sclosure) to point to it, inserts into it
 * the link to the enclosing frame, and copies into it the parameters
 * that are referred to in nested functions.
 * In VarExp::toElem and SymOffExp::toElem, when referring to a
 * variable that is in a closure, takes the offset from sclosure rather
 * than from the frame pointer.
 *
 * getEthis() and NewExp::toElem need to use sclosure, if set, rather
 * than the current frame pointer.
 */

#if DMDV2

void FuncDeclaration::buildClosure(IRState *irs)
{
    if (needsClosure())
    {   // Generate closure on the heap
        // BUG: doesn't capture variadic arguments passed to this function

#if DMDV2
        /* BUG: doesn't handle destructors for the local variables.
         * The way to do it is to make the closure variables the fields
         * of a class object:
         *    class Closure
         *    {   vtbl[]
         *        monitor
         *        ptr to destructor
         *        sthis
         *        ... closure variables ...
         *        ~this() { call destructor }
         *    }
         */
#endif
        //printf("FuncDeclaration::buildClosure()\n");
        Symbol *sclosure;
        sclosure = symbol_name("__closptr",SCauto,Type::tvoidptr->toCtype());
        sclosure->Sflags |= SFLtrue | SFLfree;
        symbol_add(sclosure);
        irs->sclosure = sclosure;

        unsigned offset = Target::ptrsize;      // leave room for previous sthis
        for (size_t i = 0; i < closureVars.dim; i++)
        {   VarDeclaration *v = closureVars[i];
            assert(v->isVarDeclaration());

#if DMDV2
            if (v->needsAutoDtor())
                /* Because the value needs to survive the end of the scope!
                 */
                v->error("has scoped destruction, cannot build closure");
            if (v->isargptr)
                /* See Bugzilla 2479
                 * This is actually a bug, but better to produce a nice
                 * message at compile time rather than memory corruption at runtime
                 */
                v->error("cannot reference variadic arguments from closure");
#endif
            /* Align and allocate space for v in the closure
             * just like AggregateDeclaration::addField() does.
             */
            unsigned memsize;
            unsigned memalignsize;
            structalign_t xalign;
#if DMDV2
            if (v->storage_class & STClazy)
            {
                /* Lazy variables are really delegates,
                 * so give same answers that TypeDelegate would
                 */
                memsize = Target::ptrsize * 2;
                memalignsize = memsize;
                xalign = global.structalign;
            }
            else if (v->isRef() || v->isOut())
            {    // reference parameters are just pointers
                memsize = Target::ptrsize;
                memalignsize = memsize;
                xalign = global.structalign;
            }
            else
#endif
            {
                memsize = v->type->size();
                memalignsize = v->type->alignsize();
                xalign = v->type->memalign(global.structalign);
            }
            AggregateDeclaration::alignmember(xalign, memalignsize, &offset);
            v->offset = offset;
            offset += memsize;

            /* Can't do nrvo if the variable is put in a closure, since
             * what the shidden points to may no longer exist.
             */
            if (nrvo_can && nrvo_var == v)
            {
                nrvo_can = 0;
            }
        }
        // offset is now the size of the closure

        // Allocate memory for the closure
        elem *e;
        e = el_long(TYsize_t, offset);
        e = el_bin(OPcall, TYnptr, el_var(getRtlsym(RTLSYM_ALLOCMEMORY)), e);

        // Assign block of memory to sclosure
        //    sclosure = allocmemory(sz);
        e = el_bin(OPeq, TYvoid, el_var(sclosure), e);

        // Set the first element to sthis
        //    *(sclosure + 0) = sthis;
        elem *ethis;
        if (irs->sthis)
            ethis = el_var(irs->sthis);
        else
            ethis = el_long(TYnptr, 0);
        elem *ex = el_una(OPind, TYnptr, el_var(sclosure));
        ex = el_bin(OPeq, TYnptr, ex, ethis);
        e = el_combine(e, ex);

        // Copy function parameters into closure
        for (size_t i = 0; i < closureVars.dim; i++)
        {   VarDeclaration *v = closureVars[i];

            if (!v->isParameter())
                continue;
            tym_t tym = v->type->totym();
            if (v->type->toBasetype()->ty == Tsarray || v->isOut() || v->isRef())
                tym = TYnptr;   // reference parameters are just pointers
#if DMDV2
            else if (v->storage_class & STClazy)
                tym = TYdelegate;
#endif
            ex = el_bin(OPadd, TYnptr, el_var(sclosure), el_long(TYsize_t, v->offset));
            ex = el_una(OPind, tym, ex);
            if (tybasic(ex->Ety) == TYstruct)
            {
                ::type *t = v->type->toCtype();
                ex->ET = t;
                ex = el_bin(OPstreq, tym, ex, el_var(v->toSymbol()));
                ex->ET = t;
            }
            else
                ex = el_bin(OPeq, tym, ex, el_var(v->toSymbol()));

            e = el_combine(e, ex);
        }

        block_appendexp(irs->blx->curblock, e);
    }
}

#endif

/***************************
 * Determine return style of function - whether in registers or
 * through a hidden pointer to the caller's stack.
 */

enum RET TypeFunction::retStyle()
{
    //printf("TypeFunction::retStyle() %s\n", toChars());
#if DMDV2
    if (isref)
    {
        //printf("  ref RETregs\n");
        return RETregs;                 // returns a pointer
    }
#endif

    Type *tn = next->toBasetype();
    //printf("tn = %s\n", tn->toChars());
    d_uns64 sz = tn->size();
    Type *tns = tn;

    if (global.params.isWindows && global.params.is64bit)
    {   // http://msdn.microsoft.com/en-us/library/7572ztz4(v=vs.80)
        if (tns->isscalar())
            return RETregs;
#if SARRAYVALUE
        if (tns->ty == Tsarray)
        {
            do
            {
                tns = tns->nextOf()->toBasetype();
            } while (tns->ty == Tsarray);
        }
#endif
        if (tns->ty == Tstruct)
        {   StructDeclaration *sd = ((TypeStruct *)tns)->sym;
            if (!sd->isPOD() || sz >= 8)
                return RETstack;
        }
        if (sz <= 16 && !(sz & (sz - 1)))
            return RETregs;
        return RETstack;
    }

Lagain:
#if SARRAYVALUE
    if (tns->ty == Tsarray)
    {
        do
        {
            tns = tns->nextOf()->toBasetype();
        } while (tns->ty == Tsarray);

        if (tns->ty != Tstruct)
        {
L2:
            if (global.params.isLinux && linkage != LINKd && !global.params.is64bit)
                ;                               // 32 bit C/C++ structs always on stack
            else
            {
                switch (sz)
                {   case 1:
                    case 2:
                    case 4:
                    case 8:
                        //printf("  sarray RETregs\n");
                        return RETregs; // return small structs in regs
                                            // (not 3 byte structs!)
                    default:
                        break;
                }
            }
            //printf("  sarray RETstack\n");
            return RETstack;
        }
    }
#endif

    if (tns->ty == Tstruct)
    {   StructDeclaration *sd = ((TypeStruct *)tns)->sym;
        if (global.params.isLinux && linkage != LINKd && !global.params.is64bit)
        {
            //printf("  2 RETstack\n");
            return RETstack;            // 32 bit C/C++ structs always on stack
        }
        if (sd->arg1type && !sd->arg2type)
        {
            tns = sd->arg1type;
#if SARRAYVALUE
            if (tns->ty != Tstruct)
                goto L2;
#endif
            goto Lagain;
        }
        else if (global.params.is64bit && !sd->arg1type && !sd->arg2type)
            return RETstack;
        else if (sd->isPOD())
        {
            switch (sz)
            {   case 1:
                case 2:
                case 4:
                case 8:
                    //printf("  3 RETregs\n");
                    return RETregs;     // return small structs in regs
                                        // (not 3 byte structs!)
                case 16:
                    if (!global.params.isWindows && global.params.is64bit)
                       return RETregs;

                default:
                    break;
            }
        }
        //printf("  3 RETstack\n");
        return RETstack;
    }
    else if ((global.params.isLinux || global.params.isOSX || global.params.isFreeBSD || global.params.isSolaris) &&
             linkage == LINKc &&
             tns->iscomplex())
    {
        if (tns->ty == Tcomplex32)
            return RETregs;     // in EDX:EAX, not ST1:ST0
        else
            return RETstack;
    }
    else
    {
        //assert(sz <= 16);
        //printf("  4 RETregs\n");
        return RETregs;
    }
}


