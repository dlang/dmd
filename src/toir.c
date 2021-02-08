
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/toir.c
 */

/* Code to help convert to the intermediate representation
 * of the compiler back end.
 */

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#ifdef _MSC_VER
#include        <stdarg.h>
#undef va_start // mapped to _crt_va_start
#endif

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
#include        "mangle.h"

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

bool ISREF(Declaration *var, Type *tb);
bool ISWIN64REF(Declaration *var);

type *Type_toCtype(Type *t);
unsigned totym(Type *tx);
Symbol *toSymbol(Dsymbol *s);
void toTraceGC(IRState *irs, elem *e, Loc *loc);

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
        assert(linnum < irs->blx->module->numlines);
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
    Dsymbol *fdp = fdparent;

    /* These two are compiler generated functions for the in and out contracts,
     * and are called from an overriding function, not just the one they're
     * nested inside, so this hack is so they'll pass
     */
    if (fdparent != thisfd && (fd->ident == Id::require || fd->ident == Id::ensure))
    {
        FuncDeclaration *fdthis = thisfd;
        for (size_t i = 0; ; )
        {
            if (i == fdthis->foverrides.length)
            {
                if (i == 0)
                    break;
                fdthis = fdthis->foverrides[0];
                i = 0;
                continue;
            }
            if (fdthis->foverrides[i] == fdp)
            {
                fdparent = thisfd;
                break;
            }
            i++;
        }
    }

    //printf("[%s] getEthis(thisfd = '%s', fd = '%s', fdparent = '%s')\n", loc.toChars(), thisfd->toPrettyChars(), fd->toPrettyChars(), fdparent->toPrettyChars());
    if (fdparent == thisfd)
    {
        /* Going down one nesting level, i.e. we're calling
         * a nested function from its enclosing function.
         */
        if (irs->sclosure && !(fd->ident == Id::require || fd->ident == Id::ensure))
        {
            ethis = el_var(irs->sclosure);
        }
        else if (irs->sthis)
        {
            // We have a 'this' pointer for the current function

            if (fdp != thisfd)
            {
                /* fdparent (== thisfd) is a derived member function,
                 * fdp is the overridden member function in base class, and
                 * fd is the nested function '__require' or '__ensure'.
                 * Even if there's a closure environment, we should give
                 * original stack data as the nested function frame.
                 * See also: SymbolExp::toElem() in e2ir.c (Bugzilla 9383 fix)
                 */
                /* Address of 'sthis' gives the 'this' for the nested
                 * function.
                 */
                //printf("L%d fd = %s, fdparent = %s, fd->toParent2() = %s\n",
                //    __LINE__, fd->toPrettyChars(), fdparent->toPrettyChars(), fdp->toPrettyChars());
                assert(fd->ident == Id::require || fd->ident == Id::ensure);
                assert(thisfd->hasNestedFrameRefs());

                ClassDeclaration *cdp = fdp->isThis()->isClassDeclaration();
                ClassDeclaration *cd = thisfd->isThis()->isClassDeclaration();
                assert(cdp && cd);

                int offset;
                cdp->isBaseOf(cd, &offset);
                assert(offset != OFFSET_RUNTIME);
                //printf("%s to %s, offset = %d\n", cd->toChars(), cdp->toChars(), offset);
                if (offset)
                {
                    /* Bugzilla 7517: If fdp is declared in interface, offset the
                     * 'this' pointer to get correct interface type reference.
                     */
                    Symbol *stmp = symbol_genauto(TYnptr);
                    ethis = el_bin(OPadd, TYnptr, el_var(irs->sthis), el_long(TYsize_t, offset));
                    ethis = el_bin(OPeq, TYnptr, el_var(stmp), ethis);
                    ethis = el_combine(ethis, el_ptr(stmp));
                    //elem_print(ethis);
                }
                else
                    ethis = el_ptr(irs->sthis);
            }
            else if (thisfd->hasNestedFrameRefs())
            {
                /* Local variables are referenced, can't skip.
                 * Address of 'sthis' gives the 'this' for the nested
                 * function.
                 */
                ethis = el_ptr(irs->sthis);
            }
            else
            {
                /* If no variables in the current function's frame are
                 * referenced by nested functions, then we can 'skip'
                 * adding this frame into the linked list of stack
                 * frames.
                 */
                ethis = el_var(irs->sthis);
            }
        }
        else
        {
            /* No 'this' pointer for current function,
             */
            if (thisfd->hasNestedFrameRefs())
            {
                /* OPframeptr is an operator that gets the frame pointer
                 * for the current function, i.e. for the x86 it gets
                 * the value of EBP
                 */
                ethis = el_long(TYnptr, 0);
                ethis->Eoper = OPframeptr;
            }
            else
            {
                /* Use NULL if no references to the current function's frame
                 */
                ethis = el_long(TYnptr, 0);
            }
        }
    }
    else
    {
        if (!irs->sthis)                // if no frame pointer for this function
        {
            fd->error(loc, "is a nested function and cannot be accessed from %s", irs->getFunc()->toPrettyChars());
            return el_long(TYnptr, 0); // error recovery
        }

        /* Go up a nesting level, i.e. we need to find the 'this'
         * of an enclosing function.
         * Our 'enclosing function' may also be an inner class.
         */
        ethis = el_var(irs->sthis);
        Dsymbol *s = thisfd;
        while (fd != s)
        {
            FuncDeclaration *fdp = s->toParent2()->isFuncDeclaration();

            //printf("\ts = '%s'\n", s->toChars());
            thisfd = s->isFuncDeclaration();
            if (thisfd)
            {
                /* Enclosing function is a function.
                 */
                // Error should have been caught by front end
                assert(thisfd->isNested() || thisfd->vthis);
            }
            else
            {
                /* Enclosed by an aggregate. That means the current
                 * function must be a member function of that aggregate.
                 */
                AggregateDeclaration *ad = s->isAggregateDeclaration();
                if (!ad)
                {
                  Lnoframe:
                    irs->getFunc()->error(loc, "cannot get frame pointer to %s", fd->toPrettyChars());
                    return el_long(TYnptr, 0);      // error recovery
                }
                ClassDeclaration *cd = ad->isClassDeclaration();
                ClassDeclaration *cdx = fd->isClassDeclaration();
                if (cd && cdx && cdx->isBaseOf(cd, NULL))
                    break;
                StructDeclaration *sd = ad->isStructDeclaration();
                if (fd == sd)
                    break;
                if (!ad->isNested() || !ad->vthis)
                    goto Lnoframe;

                ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYsize_t, ad->vthis->offset));
                ethis = el_una(OPind, TYnptr, ethis);
            }
            if (fdparent == s->toParent2())
                break;

            /* Remember that frames for functions that have no
             * nested references are skipped in the linked list
             * of frames.
             */
            if (fdp && fdp->hasNestedFrameRefs())
                ethis = el_una(OPind, TYnptr, ethis);

            s = s->toParent2();
            assert(s);
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
elem *setEthis(Loc loc, IRState *irs, elem *ey, AggregateDeclaration *ad)
{
    elem *ethis;
    FuncDeclaration *thisfd = irs->getFunc();
    int offset = 0;
    Dsymbol *adp = ad->toParent2();     // class/func we're nested in

    //printf("[%s] setEthis(ad = %s, adp = %s, thisfd = %s)\n", loc.toChars(), ad->toChars(), adp->toChars(), thisfd->toChars());

    if (adp == thisfd)
    {
        ethis = getEthis(loc, irs, ad);
    }
    else if (thisfd->vthis &&
          (adp == thisfd->toParent2() ||
           (adp->isClassDeclaration() &&
            adp->isClassDeclaration()->isBaseOf(thisfd->toParent2()->isClassDeclaration(), &offset)
           )
          )
        )
    {
        /* Class we're new'ing is at the same level as thisfd
         */
        assert(offset == 0);    // BUG: should handle this case
        ethis = el_var(irs->sthis);
    }
    else
    {
        ethis = getEthis(loc, irs, adp);
        FuncDeclaration *fdp = adp->isFuncDeclaration();
        if (fdp && fdp->hasNestedFrameRefs())
            ethis = el_una(OPaddr, TYnptr, ethis);
    }

    ey = el_bin(OPadd, TYnptr, ey, el_long(TYsize_t, ad->vthis->offset));
    ey = el_una(OPind, TYnptr, ey);
    ey = el_bin(OPeq, TYnptr, ey, ethis);
    return ey;
}

/*******************************************
 * Convert intrinsic function to operator.
 * Returns that operator, -1 if not an intrinsic function.
 */
int intrinsic_op(FuncDeclaration *fd)
{
    int op = NotIntrinsic;
    fd = fd->toAliasFunc();
    if (fd->isDeprecated())
        return op;
    //printf("intrinsic_op(%s)\n", name);

    // Look for [core|std].module.function as id3.id2.id1 ...
    const Identifier *id3 = fd->ident;
    Module *m = fd->getModule();
    if (!m || !m->md)
        return op;

    const ModuleDeclaration *md = m->md;
    const Identifier *id2 = md->id;

    if (!md->packages || md->packages->length == 0)
        return op;

    // get type of first argument
    TypeFunction *tf = fd->type ? fd->type->isTypeFunction() : NULL;
    Parameter *param1 = tf && tf->parameterList.length() > 0 ? tf->parameterList[0] : NULL;
    Type *argtype1 = param1 ? param1->type : NULL;

    const Identifier *id1 = (*md->packages)[0];
    // ... except core.stdc.stdarg.va_start.
    if (md->packages->length == 2)
    {
        goto Lva_start;
    }

    if (id1 == Id::std && id2 == Id::math)
    {
        if (argtype1 == Type::tfloat80 || id3 == Id::_sqrt)
            goto Lmath;
        if (id3 == Id::fabs &&
            (argtype1 == Type::tfloat32 || argtype1 == Type::tfloat64))
        {
            op = OPabs;
        }
    }
    else if (id1 == Id::core)
    {
        if (id2 == Id::math)
        {
        Lmath:
            if (argtype1 == Type::tfloat80 || argtype1 == Type::tfloat32 || argtype1 == Type::tfloat64)
            {
                     if (id3 == Id::cos)    op = OPcos;
                else if (id3 == Id::sin)    op = OPsin;
                else if (id3 == Id::fabs)   op = OPabs;
                else if (id3 == Id::rint)   op = OPrint;
                else if (id3 == Id::_sqrt)  op = OPsqrt;
                else if (id3 == Id::yl2x)   op = OPyl2x;
                else if (id3 == Id::ldexp)  op = OPscale;
                else if (id3 == Id::rndtol) op = OPrndtol;
                else if (id3 == Id::yl2xp1) op = OPyl2xp1;
                else if (id3 == Id::toPrec) op = OPtoPrec;
            }
        }
        else if (id2 == Id::simd)
        {
                 if (id3 == Id::__simd_sto) op = OPvector;
            else if (id3 == Id::__simd)     op = OPvector;
            else if (id3 == Id::__simd_ib)  op = OPvector;
        }
        else if (id2 == Id::bitop)
        {
                 if (id3 == Id::volatileLoad)  op = OPind;
            else if (id3 == Id::volatileStore) op = OPeq;

            else if (id3 == Id::bsf) op = OPbsf;
            else if (id3 == Id::bsr) op = OPbsr;
            else if (id3 == Id::btc) op = OPbtc;
            else if (id3 == Id::btr) op = OPbtr;
            else if (id3 == Id::bts) op = OPbts;

            else if (id3 == Id::inp)  op = OPinp;
            else if (id3 == Id::inpl) op = OPinp;
            else if (id3 == Id::inpw) op = OPinp;

            else if (id3 == Id::outp)  op = OPoutp;
            else if (id3 == Id::outpl) op = OPoutp;
            else if (id3 == Id::outpw) op = OPoutp;

            else if (id3 == Id::bswap)   op = OPbswap;
            else if (id3 == Id::_popcnt) op = OPpopcnt;
        }
        else if (id2 == Id::_volatile)
        {
                 if (id3 == Id::volatileLoad)  op = OPind;
            else if (id3 == Id::volatileStore) op = OPeq;
        }
    }

    if (!global.params.is64bit)
    // No 64-bit bsf bsr in 32bit mode
    {
        if ((op == OPbsf || op == OPbsr) && argtype1 == Type::tuns64)
            return NotIntrinsic;
    }
    return op;

Lva_start:
    if (global.params.is64bit &&
        fd->toParent()->isTemplateInstance() &&
        id3 == Id::va_start &&
        id2 == Id::stdarg &&
        (*md->packages)[1] == Id::stdc &&
        id1 == Id::core)
    {
        return OPva_start;
    }
    return op;
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
    {
        elem *elength;
        Symbol *slength;

        if (t1->ty == Tsarray)
        {
            TypeSArray *tsa = (TypeSArray *)t1;
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
            slength = toSymbol(lengthVar);
            //symbol_add(slength);

            einit = el_bin(OPeq, TYsize_t, el_var(slength), elength);
        }
    }
    return einit;
}

void setClosureVarOffset(FuncDeclaration *fd)
{
    if (fd->needsClosure())
    {
        unsigned offset = target.ptrsize;      // leave room for previous sthis

        for (size_t i = 0; i < fd->closureVars.length; i++)
        {
            VarDeclaration *v = fd->closureVars[i];

            /* Align and allocate space for v in the closure
             * just like AggregateDeclaration::addField() does.
             */
            unsigned memsize;
            unsigned memalignsize;
            structalign_t xalign;
            if (v->storage_class & STClazy)
            {
                /* Lazy variables are really delegates,
                 * so give same answers that TypeDelegate would
                 */
                memsize = target.ptrsize * 2;
                memalignsize = memsize;
                xalign = STRUCTALIGN_DEFAULT;
            }
            else if (v->storage_class & (STCout | STCref))
            {
                // reference parameters are just pointers
                memsize = target.ptrsize;
                memalignsize = memsize;
                xalign = STRUCTALIGN_DEFAULT;
            }
            else
            {
                memsize = v->type->size();
                memalignsize = v->type->alignsize();
                xalign = v->alignment;
            }
            AggregateDeclaration::alignmember(xalign, memalignsize, &offset);
            v->offset = offset;
            //printf("closure var %s, offset = %d\n", v->toChars(), v->offset);

            offset += memsize;

            /* Can't do nrvo if the variable is put in a closure, since
             * what the shidden points to may no longer exist.
             */
            if (fd->nrvo_can && fd->nrvo_var == v)
            {
                fd->nrvo_can = 0;
            }
        }
    }
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
void buildClosure(FuncDeclaration *fd, IRState *irs)
{
    if (fd->needsClosure())
    {
        setClosureVarOffset(fd);

        // Generate closure on the heap
        // BUG: doesn't capture variadic arguments passed to this function

        /* BUG: doesn't handle destructors for the local variables.
         * The way to do it is to make the closure variables the fields
         * of a class object:
         *    class Closure {
         *        vtbl[]
         *        monitor
         *        ptr to destructor
         *        sthis
         *        ... closure variables ...
         *        ~this() { call destructor }
         *    }
         */
        //printf("FuncDeclaration::buildClosure() %s\n", fd->toChars());

        /* Generate type name for closure struct */
        const char *name1 = "CLOSURE.";
        const char *name2 = fd->toPrettyChars();
        size_t namesize = strlen(name1)+strlen(name2)+1;
        char *closname = (char *) calloc(namesize, sizeof(char));
        strcat(strcat(closname, name1), name2);

        /* Build type for closure */
        type *Closstru = type_struct_class(closname, target.ptrsize, 0, NULL, NULL, false, false, true);
        free(closname);
        symbol_struct_addField(Closstru->Ttag, "__chain", Type_toCtype(Type::tvoidptr), 0);

        Symbol *sclosure;
        sclosure = symbol_name("__closptr", SCauto, type_pointer(Closstru));
        sclosure->Sflags |= SFLtrue | SFLfree;
        symbol_add(sclosure);
        irs->sclosure = sclosure;

        assert(fd->closureVars.length);
        assert(fd->closureVars[0]->offset >= target.ptrsize);
        for (size_t i = 0; i < fd->closureVars.length; i++)
        {
            VarDeclaration *v = fd->closureVars[i];
            //printf("closure var %s\n", v->toChars());

            // Hack for the case fail_compilation/fail10666.d,
            // until proper issue 5730 fix will come.
            bool isScopeDtorParam = v->edtor && (v->storage_class & STCparameter);
            if (v->needsScopeDtor() || isScopeDtorParam)
            {
                /* Because the value needs to survive the end of the scope!
                 */
                v->error("has scoped destruction, cannot build closure");
            }
            if (v->isargptr)
            {
                /* See Bugzilla 2479
                 * This is actually a bug, but better to produce a nice
                 * message at compile time rather than memory corruption at runtime
                 */
                v->error("cannot reference variadic arguments from closure");
            }

            /* Set Sscope to closure */
            Symbol *vsym = toSymbol(v);
            assert(vsym->Sscope == NULL);
            vsym->Sscope = sclosure;

            /* Add variable as closure type member */
            symbol_struct_addField(Closstru->Ttag, vsym->Sident, vsym->Stype, v->offset);
            //printf("closure field %s: memalignsize: %i, offset: %i\n", vsym->Sident, memalignsize, v->offset);
        }

        // Calculate the size of the closure
        VarDeclaration *vlast = fd->closureVars[fd->closureVars.length - 1];
        unsigned structsize;
        if (vlast->storage_class & STClazy)
            structsize = vlast->offset + target.ptrsize * 2;
        else if (vlast->isRef() || vlast->isOut())
            structsize = vlast->offset + target.ptrsize;
        else
            structsize = vlast->offset + vlast->type->size();
        //printf("structsize = %d\n", structsize);

        Closstru->Ttag->Sstruct->Sstructsize = structsize;

        // Allocate memory for the closure
        elem *e = el_long(TYsize_t, structsize);
        e = el_bin(OPcall, TYnptr, el_var(getRtlsym(RTLSYM_ALLOCMEMORY)), e);
        toTraceGC(irs, e, &fd->loc);

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
        for (size_t i = 0; i < fd->closureVars.length; i++)
        {
            VarDeclaration *v = fd->closureVars[i];

            if (!v->isParameter())
                continue;
            tym_t tym = totym(v->type);
            bool win64ref = ISWIN64REF(v);
            if (win64ref)
            {
                if (v->storage_class & STClazy)
                    tym = TYdelegate;
            }
            else if (ISREF(v, NULL))
                tym = TYnptr;   // reference parameters are just pointers
            else if (v->storage_class & STClazy)
                tym = TYdelegate;
            ex = el_bin(OPadd, TYnptr, el_var(sclosure), el_long(TYsize_t, v->offset));
            ex = el_una(OPind, tym, ex);
            elem *ev = el_var(toSymbol(v));
            if (win64ref)
            {
                ev->Ety = TYnptr;
                ev = el_una(OPind, tym, ev);
                if (tybasic(ev->Ety) == TYstruct || tybasic(ev->Ety) == TYarray)
                    ev->ET = Type_toCtype(v->type);
            }
            if (tybasic(ex->Ety) == TYstruct || tybasic(ex->Ety) == TYarray)
            {
                ::type *t = Type_toCtype(v->type);
                ex->ET = t;
                ex = el_bin(OPstreq, tym, ex, ev);
                ex->ET = t;
            }
            else
                ex = el_bin(OPeq, tym, ex, ev);

            e = el_combine(e, ex);
        }

        block_appendexp(irs->blx->curblock, e);
    }
}

/***************************
 * Determine return style of function - whether in registers or
 * through a hidden pointer to the caller's stack.
 */
RET retStyle(TypeFunction *tf, bool needsThis)
{
    //printf("TypeFunction::retStyle() %s\n", toChars());
    return target.isReturnOnStack(tf, needsThis) ? RETstack : RETregs;
}
