
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "aggregate.h"
#include "scope.h"
#include "mtype.h"
#include "init.h"
#include "declaration.h"
#include "module.h"
#include "id.h"
#include "statement.h"
#include "template.h"

FuncDeclaration *StructDeclaration::xerreq;     // object.xopEquals
FuncDeclaration *StructDeclaration::xerrcmp;    // object.xopCmp

bool inNonRoot(Dsymbol *s)
{
    if (!s || !s->parent)
        return false;
    s = s->parent;
    for (; s; s = s->parent)
    {
        if (TemplateInstance *ti = s->isTemplateInstance())
        {
            if (ti->isTemplateMixin())
                continue;
            if (!ti->instantiatingModule || !ti->instantiatingModule->isRoot())
                return true;
            return false;
        }
        else if (Module *m = s->isModule())
        {
            if (!m->isRoot())
                return true;
            break;
        }
    }
    return false;
}

/***************************************
 * Search toHash member function for TypeInfo_Struct.
 *      const hash_t toHash();
 */
FuncDeclaration *search_toHash(StructDeclaration *sd)
{
    Dsymbol *s = search_function(sd, Id::tohash);
    FuncDeclaration *fd = s ? s->isFuncDeclaration() : NULL;
    if (fd)
    {
        static TypeFunction *tftohash;
        if (!tftohash)
        {
            tftohash = new TypeFunction(NULL, Type::thash_t, 0, LINKd);
            tftohash->mod = MODconst;
            tftohash = (TypeFunction *)tftohash->merge();
        }

        fd = fd->overloadExactMatch(tftohash);
    }
    return fd;
}

/***************************************
 * Search toString member function for TypeInfo_Struct.
 *      string toString();
 */
FuncDeclaration *search_toString(StructDeclaration *sd)
{
    Dsymbol *s = search_function(sd, Id::tostring);
    FuncDeclaration *fd = s ? s->isFuncDeclaration() : NULL;
    if (fd)
    {
        static TypeFunction *tftostring;
        if (!tftostring)
        {
            tftostring = new TypeFunction(NULL, Type::tstring, 0, LINKd);
            tftostring = (TypeFunction *)tftostring->merge();
        }

        fd = fd->overloadExactMatch(tftostring);
    }
    return fd;
}

/********************************* AggregateDeclaration ****************************/

AggregateDeclaration::AggregateDeclaration(Loc loc, Identifier *id)
    : ScopeDsymbol(id)
{
    this->loc = loc;

    storage_class = 0;
    protection = PROTpublic;
    type = NULL;
    handle = NULL;
    structsize = 0;             // size of struct
    alignsize = 0;              // size of struct for alignment purposes
    sizeok = SIZEOKnone;        // size not determined yet
    deferred = NULL;
    isdeprecated = false;
    inv = NULL;
    aggNew = NULL;
    aggDelete = NULL;

    stag = NULL;
    sinit = NULL;
    enclosing = NULL;
    vthis = NULL;

    ctor = NULL;
    defaultCtor = NULL;
    aliasthis = NULL;
    noDefaultCtor = false;
    dtor = NULL;
    getRTInfo = NULL;
}

PROT AggregateDeclaration::prot()
{
    return protection;
}

void AggregateDeclaration::setScope(Scope *sc)
{
    if (sizeok == SIZEOKdone)
        return;
    ScopeDsymbol::setScope(sc);
}

void AggregateDeclaration::semantic2(Scope *sc)
{
    //printf("AggregateDeclaration::semantic2(%s)\n", toChars());
    if (scope && members)
    {   error("has forward references");
        return;
    }
    if (members)
    {
        sc = sc->push(this);
        sc->parent = this;
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf("\t[%d] %s\n", i, s->toChars());
            s->semantic2(sc);
        }
        sc->pop();
    }
}

void AggregateDeclaration::semantic3(Scope *sc)
{
    //printf("AggregateDeclaration::semantic3(%s)\n", toChars());
    if (members)
    {
        StructDeclaration *sd = isStructDeclaration();
        if (!sc)    // from runDeferredSemantic3 for TypeInfo generation
            goto Lxop;

        sc = sc->push(this);
        sc->parent = this;
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->semantic3(sc);
        }
        sc = sc->pop();

        if (!getRTInfo && Type::rtinfo &&
            (!isDeprecated() || global.params.useDeprecated) && // don't do it for unused deprecated types
            (type && type->ty != Terror)) // or error types
        {
            // Evaluate: RTinfo!type
            Objects *tiargs = new Objects();
            tiargs->push(type);
            TemplateInstance *ti = new TemplateInstance(loc, Type::rtinfo, tiargs);
            ti->semantic(sc);
            ti->semantic2(sc);
            ti->semantic3(sc);
            Dsymbol *s = ti->toAlias();
            Expression *e = new DsymbolExp(Loc(), s, 0);

            Scope *sc2 = ti->tempdecl->scope->startCTFE();
            sc2->instantiatingModule = sc->instantiatingModule ? sc->instantiatingModule : sc->module;
            e = e->semantic(sc2);
            sc2->endCTFE();

            e = e->ctfeInterpret();
            getRTInfo = e;
        }

        if (sd)
        {
        Lxop:
            if (sd->xeq &&
                sd->xeq->scope &&
                sd->xeq->semanticRun < PASSsemantic3done)
            {
                unsigned errors = global.startGagging();
                sd->xeq->semantic3(sd->xeq->scope);
                if (global.endGagging(errors))
                    sd->xeq = sd->xerreq;
            }

            if (sd->xcmp &&
                sd->xcmp->scope &&
                sd->xcmp->semanticRun < PASSsemantic3done)
            {
                unsigned errors = global.startGagging();
                sd->xcmp->semantic3(sd->xcmp->scope);
                if (global.endGagging(errors))
                    sd->xcmp = sd->xerrcmp;
            }

            FuncDeclaration *ftostr = search_toString(sd);
            if (ftostr &&
                ftostr->scope &&
                ftostr->semanticRun < PASSsemantic3done)
            {
                ftostr->semantic3(ftostr->scope);
            }

            FuncDeclaration *ftohash = search_toHash(sd);
            if (ftohash &&
                ftohash->scope &&
                ftohash->semanticRun < PASSsemantic3done)
            {
                ftohash->semantic3(ftohash->scope);
            }
        }
    }
}

void AggregateDeclaration::inlineScan()
{
    //printf("AggregateDeclaration::inlineScan(%s)\n", toChars());
    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf("inline scan aggregate symbol '%s'\n", s->toChars());
            s->inlineScan();
        }
    }
}

unsigned AggregateDeclaration::size(Loc loc)
{
    //printf("AggregateDeclaration::size() %s, scope = %p\n", toChars(), scope);
    if (loc.linnum == 0)
        loc = this->loc;
    if (sizeok != SIZEOKdone && scope)
        semantic(NULL);

    StructDeclaration *sd = isStructDeclaration();
    if (sizeok != SIZEOKdone && sd && sd->members)
    {
        /* See if enough is done to determine the size,
         * meaning all the fields are done.
         */
        struct SV
        {
            /* Returns:
             *  0       this member doesn't need further processing to determine struct size
             *  1       this member does
             */
            static int func(Dsymbol *s, void *param)
            {   SV *psv = (SV *)param;
                VarDeclaration *v = s->isVarDeclaration();
                if (v)
                {
                    if (v->scope)
                        v->semantic(NULL);
                    if (v->storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCmanifest | STCctfe | STCtemplateparameter))
                        return 0;
                    if (v->isField() && v->sem >= SemanticDone)
                        return 0;
                    return 1;
                }
                return 0;
            }
        };
        SV sv;

        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            if (s->apply(&SV::func, &sv))
                goto L1;
        }
        sd->finalizeSize(NULL);

      L1: ;
    }

    if (!members)
    {
        error(loc, "unknown size");
    }
    else if (sizeok != SIZEOKdone)
    {
        error(loc, "no size yet for forward reference");
        //*(char*)0=0;
    }
    return structsize;
}

Type *AggregateDeclaration::getType()
{
    return type;
}

bool AggregateDeclaration::isDeprecated()
{
    return isdeprecated;
}

bool AggregateDeclaration::isExport()
{
    return protection == PROTexport;
}

/****************************
 * Do byte or word alignment as necessary.
 * Align sizes of 0, as we may not know array sizes yet.
 */

void AggregateDeclaration::alignmember(
        structalign_t alignment,   // struct alignment that is in effect
        unsigned size,             // alignment requirement of field
        unsigned *poffset)
{
    //printf("alignment = %d, size = %d, offset = %d\n",alignment,size,offset);
    switch (alignment)
    {
        case (structalign_t) 1:
            // No alignment
            break;

        case (structalign_t) STRUCTALIGN_DEFAULT:
        {   /* Must match what the corresponding C compiler's default
             * alignment behavior is.
             */
            assert(size != 3);
            unsigned sa = (size == 0 || 8 < size) ? 8 : size;
            *poffset = (*poffset + sa - 1) & ~(sa - 1);
            break;
        }

        default:
            // Align on alignment boundary, which must be a positive power of 2
            assert(alignment > 0 && !(alignment & (alignment - 1)));
            *poffset = (*poffset + alignment - 1) & ~(alignment - 1);
            break;
    }
}

/****************************************
 * Place a member (mem) into an aggregate (agg), which can be a struct, union or class
 * Returns:
 *      offset to place field at
 */
unsigned AggregateDeclaration::placeField(
        unsigned *nextoffset,   // next location in aggregate
        unsigned memsize,       // size of member
        unsigned memalignsize,  // size of member for alignment purposes
        structalign_t alignment, // alignment in effect for this member
        unsigned *paggsize,     // size of aggregate (updated)
        unsigned *paggalignsize, // size of aggregate for alignment purposes (updated)
        bool isunion            // the aggregate is a union
        )
{
    unsigned ofs = *nextoffset;
    alignmember(alignment, memalignsize, &ofs);
    unsigned memoffset = ofs;
    ofs += memsize;
    if (ofs > *paggsize)
        *paggsize = ofs;
    if (!isunion)
        *nextoffset = ofs;

    if (alignment == STRUCTALIGN_DEFAULT)
    {
        if (global.params.is64bit && memalignsize == 16)
            ;
        else if (8 < memalignsize)
            memalignsize = 8;
    }
    else
    {
        if (memalignsize < alignment)
            memalignsize = alignment;
    }

    if (*paggalignsize < memalignsize)
        *paggalignsize = memalignsize;

    return memoffset;
}


/****************************************
 * Returns true if there's an extra member which is the 'this'
 * pointer to the enclosing context (enclosing aggregate or function)
 */

bool AggregateDeclaration::isNested()
{
    return enclosing != NULL;
}

void AggregateDeclaration::makeNested()
{
    if (!enclosing && sizeok != SIZEOKdone && !isUnionDeclaration() && !isInterfaceDeclaration())
    {
        // If nested struct, add in hidden 'this' pointer to outer scope
        if (!(storage_class & STCstatic))
        {
            Dsymbol *s = toParent2();
            if (s)
            {
                AggregateDeclaration *ad = s->isAggregateDeclaration();
                FuncDeclaration *fd = s->isFuncDeclaration();

                if (fd)
                {
                    enclosing = fd;
                }
                else if (isClassDeclaration() && ad && ad->isClassDeclaration())
                {
                    enclosing = ad;
                }
                else if (isStructDeclaration() && ad)
                {
                    if (TemplateInstance *ti = ad->parent->isTemplateInstance())
                    {
                        enclosing = ti->enclosing;
                    }
                }
                if (enclosing)
                {
                    //printf("makeNested %s, enclosing = %s\n", toChars(), enclosing->toChars());
                    Type *t;
                    if (ad)
                        t = ad->handle;
                    else if (fd)
                    {   AggregateDeclaration *ad2 = fd->isMember2();
                        if (ad2)
                            t = ad2->handle;
                        else
                            t = Type::tvoidptr;
                    }
                    else
                        assert(0);
                    if (t->ty == Tstruct)
                        t = Type::tvoidptr;     // t should not be a ref type
                    assert(!vthis);
                    vthis = new ThisDeclaration(loc, t);
                    //vthis->storage_class |= STCref;
                    members->push(vthis);
                }
            }
        }
    }
}

/****************************************
 * If field[indx] is not part of a union, return indx.
 * Otherwise, return the lowest field index of the union.
 */
int AggregateDeclaration::firstFieldInUnion(int indx)
{
    if (isUnionDeclaration())
        return 0;
    VarDeclaration *vd = fields[indx];
    int firstNonZero = indx; // first index in the union with non-zero size
    for (; ;)
    {
        if (indx == 0)
            return firstNonZero;
        VarDeclaration *v = fields[indx - 1];
        if (v->offset != vd->offset)
            return firstNonZero;
        --indx;
        /* If it is a zero-length field, it's ambiguous: we don't know if it is
         * in the union unless we find an earlier non-zero sized field with the
         * same offset.
         */
        if (v->size(loc) != 0)
            firstNonZero = indx;
    }
}

/****************************************
 * Count the number of fields starting at firstIndex which are part of the
 * same union as field[firstIndex]. If not a union, return 1.
 */
int AggregateDeclaration::numFieldsInUnion(int firstIndex)
{
    VarDeclaration *vd = fields[firstIndex];
    /* If it is a zero-length field, AND we can't find an earlier non-zero
     * sized field with the same offset, we assume it's not part of a union.
     */
    if (vd->size(loc) == 0 && !isUnionDeclaration() &&
        firstFieldInUnion(firstIndex) == firstIndex)
        return 1;
    int count = 1;
    for (size_t i = firstIndex+1; i < fields.dim; ++i)
    {
        VarDeclaration *v = fields[i];
        // If offsets are different, they are not in the same union
        if (v->offset != vd->offset)
            break;
        ++count;
    }
    return count;
}

/*******************************************
 * Look for constructor declaration.
 */
void AggregateDeclaration::searchCtor()
{
    ctor = search(Loc(), Id::ctor);
    if (ctor)
    {
        if (!(ctor->isCtorDeclaration() ||
              ctor->isTemplateDeclaration() ||
              ctor->isOverloadSet()))
        {
            error("%s %s is not a constructor; identifiers starting with __ are reserved for the implementation", ctor->kind(), ctor->toChars());
            errors = true;
            ctor = NULL;
        }
    }
}

/********************************* StructDeclaration ****************************/

StructDeclaration::StructDeclaration(Loc loc, Identifier *id)
    : AggregateDeclaration(loc, id)
{
    zeroInit = 0;       // assume false until we do semantic processing
    hasIdentityAssign = 0;
    hasIdentityEquals = 0;
    cpctor = NULL;
    postblit = NULL;

    xeq = NULL;
    xcmp = NULL;
    alignment = 0;
    ispod = ISPODfwd;
    arg1type = NULL;
    arg2type = NULL;
#if DMD_OBJC
    selectortarget = 0;
    isselector = 0;
#endif

    // For forward references
    type = new TypeStruct(this);

    if (id == Id::ModuleInfo && !Module::moduleinfo)
        Module::moduleinfo = this;
}

Dsymbol *StructDeclaration::syntaxCopy(Dsymbol *s)
{
    StructDeclaration *sd;

    if (s)
        sd = (StructDeclaration *)s;
    else
        sd = new StructDeclaration(loc, ident);
    ScopeDsymbol::syntaxCopy(sd);
    return sd;
}

void StructDeclaration::semantic(Scope *sc)
{
    Scope *sc2;

    //printf("+StructDeclaration::semantic(this=%p, %s '%s', sizeok = %d)\n", this, parent->toChars(), toChars(), sizeok);

    //static int count; if (++count == 20) halt();

    assert(type);
    if (!members)               // if opaque declaration
    {
        return;
    }

    if (symtab)
    {   if (sizeok == SIZEOKdone || !scope)
        {   //printf("already completed\n");
            scope = NULL;
            return;             // semantic() already completed
        }
    }
    else
        symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {
        sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }
    unsigned dprogress_save = Module::dprogress;
    int errors = global.errors;

    parent = sc->parent;
    type = type->semantic(loc, sc);
    handle = type;
    protection = sc->protection;
    alignment = sc->structalign;
    storage_class |= sc->stc;
    if (sc->stc & STCdeprecated)
        isdeprecated = true;
    assert(!isAnonymous());
    if (sc->stc & STCabstract)
        error("structs, unions cannot be abstract");
    userAttributes = sc->userAttributes;

    if (sizeok == SIZEOKnone)            // if not already done the addMember step
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf("adding member '%s' to '%s'\n", s->toChars(), this->toChars());
            s->addMember(sc, this, 1);
        }
    }

    sizeok = SIZEOKnone;
    sc2 = sc->push(this);
    sc2->stc &= STCsafe | STCtrusted | STCsystem;
    sc2->parent = this;
    if (isUnionDeclaration())
        sc2->inunion = 1;
    sc2->protection = PROTpublic;
    sc2->explicitProtection = 0;
    sc2->structalign = STRUCTALIGN_DEFAULT;
    sc2->userAttributes = NULL;

    /* Set scope so if there are forward references, we still might be able to
     * resolve individual members like enums.
     */
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        //printf("struct: setScope %s %s\n", s->kind(), s->toChars());
        s->setScope(sc2);
    }

    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];

        /* If this is the last member, see if we can finish setting the size.
         * This could be much better - finish setting the size after the last
         * field was processed. The problem is the chicken-and-egg determination
         * of when that is. See Bugzilla 7426 for more info.
         */
        if (i + 1 == members->dim)
        {
            if (sizeok == SIZEOKnone && s->isAliasDeclaration())
                finalizeSize(sc2);
        }

        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();
        s->semantic(sc2);
    }
    finalizeSize(sc2);

    if (sizeok == SIZEOKfwd)
    {
        // semantic() failed because of forward references.
        // Unwind what we did, and defer it for later
        for (size_t i = 0; i < fields.dim; i++)
        {
            VarDeclaration *vd = fields[i];
            vd->offset = 0;
        }
        fields.setDim(0);
        structsize = 0;
        alignsize = 0;
//        structalign = 0;

        scope = scx ? scx : new Scope(*sc);
        scope->setNoFree();
        scope->module->addDeferredSemantic(this);

        Module::dprogress = dprogress_save;
        //printf("\tdeferring %s\n", toChars());
        return;
    }

    Module::dprogress++;

    //printf("-StructDeclaration::semantic(this=%p, '%s')\n", this, toChars());

    // Determine if struct is all zeros or not
    zeroInit = 1;
    for (size_t i = 0; i < fields.dim; i++)
    {
        VarDeclaration *vd = fields[i];
        if (!vd->isDataseg())
        {
            if (vd->init)
            {
                // Should examine init to see if it is really all 0's
                zeroInit = 0;
                break;
            }
            else
            {
                if (!vd->type->isZeroInit(loc))
                {
                    zeroInit = 0;
                    break;
                }
            }
        }
    }

    dtor = buildDtor(sc2);
    postblit = buildPostBlit(sc2);
    cpctor = buildCpCtor(sc2);

    buildOpAssign(sc2);
    buildOpEquals(sc2);

    xeq = buildXopEquals(sc2);
    xcmp = buildXopCmp(sc2);

    /* Even if the struct is merely imported and its semantic3 is not run,
     * the TypeInfo object would be speculatively stored in each object
     * files. To set correct function pointer, run semantic3 for xeq and xcmp.
     */
    //if ((xeq && xeq != xerreq || xcmp && xcmp != xerrcmp) && isImportedSym(this))
    //    Module::addDeferredSemantic3(this);
    /* Defer requesting semantic3 until TypeInfo generation is actually invoked.
     * See Type::getTypeInfo().
     */
    inv = buildInv(sc2);

    sc2->pop();

    /* Look for special member functions.
     */
    searchCtor();
    aggNew =       (NewDeclaration *)search(Loc(), Id::classNew);
    aggDelete = (DeleteDeclaration *)search(Loc(), Id::classDelete);

    TypeTuple *tup = type->toArgTypes();
    size_t dim = tup->arguments->dim;
    if (dim >= 1)
    {   assert(dim <= 2);
        arg1type = (*tup->arguments)[0]->type;
        if (dim == 2)
            arg2type = (*tup->arguments)[1]->type;
    }

    if (sc->func)
    {
        semantic2(sc);
        semantic3(sc);
    }

    if (global.errors != errors)
    {   // The type is no good.
        type = Type::terror;
        this->errors = true;
    }

    if (deferred && !global.gag)
    {
        deferred->semantic2(sc);
        deferred->semantic3(sc);
    }

    if (type->ty == Tstruct && ((TypeStruct *)type)->sym != this)
    {
        error("failed semantic analysis");
        this->errors = true;
        type = Type::terror;
    }
}

Dsymbol *StructDeclaration::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s.StructDeclaration::search('%s')\n", toChars(), ident->toChars());

    if (scope && !symtab)
        semantic(scope);

    if (!members || !symtab)    // opaque or semantic() is not yet called
    {
        error("is forward referenced when looking for '%s'", ident->toChars());
        return NULL;
    }

    return ScopeDsymbol::search(loc, ident, flags);
}

void StructDeclaration::finalizeSize(Scope *sc)
{
    //printf("StructDeclaration::finalizeSize() %s\n", toChars());
    if (sizeok != SIZEOKnone)
        return;

    // Set the offsets of the fields and determine the size of the struct
    unsigned offset = 0;
    bool isunion = isUnionDeclaration() != NULL;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->setFieldOffset(this, &offset, isunion);
    }
    if (sizeok == SIZEOKfwd)
        return;

    // 0 sized struct's are set to 1 byte
    if (structsize == 0)
    {
        structsize = 1;
        alignsize = 1;
    }

    // Round struct size up to next alignsize boundary.
    // This will ensure that arrays of structs will get their internals
    // aligned properly.
    if (alignment == STRUCTALIGN_DEFAULT)
        structsize = (structsize + alignsize - 1) & ~(alignsize - 1);
    else
        structsize = (structsize + alignment - 1) & ~(alignment - 1);

    sizeok = SIZEOKdone;

    // Calculate fields[i]->overlapped
    fill(loc, NULL, true);
}

bool StructDeclaration::fill(Loc loc, Expressions *elements, bool ctorinit)
{
    assert(sizeok == SIZEOKdone);
    size_t nfields = fields.dim - isNested();

    if (elements)
    {
        size_t dim = elements->dim;
        elements->setDim(nfields);
        for (size_t i = dim; i < nfields; i++)
            (*elements)[i] = NULL;
    }

    // Fill in missing any elements with default initializers
    for (size_t i = 0; i < nfields; i++)
    {
        if (elements && (*elements)[i])
            continue;
        VarDeclaration *vd = fields[i];
        VarDeclaration *vx = vd;
        if (vd->init && vd->init->isVoidInitializer())
            vx = NULL;
        // Find overlapped fields with the hole [vd->offset .. vd->offset->size()].
        size_t fieldi = i;
        for (size_t j = 0; j < nfields; j++)
        {
            if (i == j)
                continue;
            VarDeclaration *v2 = fields[j];
            bool overlap = (vd->offset < v2->offset + v2->type->size() &&
                            v2->offset < vd->offset + vd->type->size());
            if (!overlap)
                continue;

            if (elements)
            {
                if ((*elements)[j])
                {
                    vx = NULL;
                    break;
                }
            }
            else
            {
                vd->overlapped = true;
            }
            if (v2->init && v2->init->isVoidInitializer())
                continue;

            if (elements)
            {
                /* Prefer first found non-void-initialized field
                 * union U { int a; int b = 2; }
                 * U u;    // Error: overlapping initialization for field a and b
                 */
                if (!vx)
                    vx = v2, fieldi = j;
                else if (v2->init)
                {
                    ::error(loc, "overlapping initialization for field %s and %s",
                        v2->toChars(), vd->toChars());
                }
            }
            else
            {
                // Will fix Bugzilla 1432 by enabling this path always

                /* Prefer explicitly initialized field
                 * union U { int a; int b = 2; }
                 * U u;    // OK (u.b == 2)
                 */
                if (!vx || !vx->init && v2->init)
                    vx = v2, fieldi = j;
                else if (vx != vd &&
                    !(vx->offset < v2->offset + v2->type->size() &&
                      v2->offset < vx->offset + vx->type->size()))
                {
                    // Both vx and v2 fills vd, but vx and v2 does not overlap
                }
                else if (vx->init && v2->init)
                {
                    ::error(loc, "overlapping default initialization for field %s and %s",
                        v2->toChars(), vd->toChars());
                }
                else
                    assert(vx->init || !vx->init && !v2->init);
            }
        }
        if (elements && vx)
        {
            Expression *e;
            if (vx->init)
            {
                assert(!vx->init->isVoidInitializer());
                e = vx->getConstInitializer(false);
            }
            else
            {
                if ((vx->storage_class & STCnodefaultctor) && !ctorinit)
                {
                    ::error(loc, "field %s.%s must be initialized because it has no default constructor",
                            type->toChars(), vx->toChars());
                }
                if (vx->type->needsNested() && ctorinit)
                    e = vx->type->defaultInit(loc);
                else
                    e = vx->type->defaultInitLiteral(loc);
            }
            (*elements)[fieldi] = e;
        }
    }

    if (elements)
    {
        for (size_t i = 0; i < elements->dim; i++)
        {
            Expression *e = (*elements)[i];
            if (e && e->op == TOKerror)
                return false;
        }
    }
    return true;
}

/***************************************
 * Return true if struct is POD (Plain Old Data).
 * This is defined as:
 *      not nested
 *      no postblits, constructors, destructors, or assignment operators
 *      no fields that are themselves non-POD
 * The idea being these are compatible with C structs.
 *
 * Note that D struct constructors can mean POD, since there is always default
 * construction with no ctor, but that interferes with OPstrpar which wants it
 * on the stack in memory, not in registers.
 */
bool StructDeclaration::isPOD()
{
    // If we've already determined whether this struct is POD.
    if (ispod != ISPODfwd)
        return (ispod == ISPODyes);

    ispod = ISPODyes;

    if (enclosing || cpctor || postblit || ctor || dtor)
        ispod = ISPODno;

    // Recursively check all fields are POD.
    for (size_t i = 0; i < fields.dim; i++)
    {
        VarDeclaration *v = fields[i];
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->baseElemOf();
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (!sd->isPOD())
            {
                ispod = ISPODno;
                break;
            }
        }
    }

    return (ispod == ISPODyes);
}

void StructDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("%s ", kind());
    if (!isAnonymous())
        buf->writestring(toChars());
    if (!members)
    {
        buf->writeByte(';');
        buf->writenl();
        return;
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    buf->level++;
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        s->toCBuffer(buf, hgs);
    }
    buf->level--;
    buf->writeByte('}');
    buf->writenl();
}


const char *StructDeclaration::kind()
{
    return "struct";
}

/********************************* UnionDeclaration ****************************/

UnionDeclaration::UnionDeclaration(Loc loc, Identifier *id)
    : StructDeclaration(loc, id)
{
}

Dsymbol *UnionDeclaration::syntaxCopy(Dsymbol *s)
{
    UnionDeclaration *ud;

    if (s)
        ud = (UnionDeclaration *)s;
    else
        ud = new UnionDeclaration(loc, ident);
    StructDeclaration::syntaxCopy(ud);
    return ud;
}


const char *UnionDeclaration::kind()
{
    return "union";
}


