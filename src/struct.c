
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
#include "declaration.h"
#include "module.h"
#include "id.h"
#include "statement.h"
#include "template.h"

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
    structalign = 0;            // struct member alignment in effect
    hasUnions = 0;
    sizeok = SIZEOKnone;        // size not determined yet
    isdeprecated = 0;
    inv = NULL;
    aggNew = NULL;
    aggDelete = NULL;

    stag = NULL;
    sinit = NULL;
#if DMDV2
    ctor = NULL;
    defaultCtor = NULL;
    aliasthis = NULL;
    noDefaultCtor = FALSE;
#endif
    dtor = NULL;
}

enum PROT AggregateDeclaration::prot()
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
        sc = sc->push(this);
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->semantic3(sc);
        }
        sc->pop();
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
    if (!members)
        error(loc, "unknown size");
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
            static int func(Dsymbol *s, void *param)
            {   SV *psv = (SV *)param;
                VarDeclaration *v = s->isVarDeclaration();
                if (v)
                {
                    if (v->scope)
                        v->semantic(NULL);
                    if (v->storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCconst | STCimmutable | STCmanifest | STCctfe | STCtemplateparameter))
                        return 0;
                    if (v->storage_class & STCfield && v->sem >= SemanticDone)
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

    if (sizeok != SIZEOKdone)
    {   error(loc, "no size yet for forward reference");
        //*(char*)0=0;
    }
    return structsize;
}

Type *AggregateDeclaration::getType()
{
    return type;
}

int AggregateDeclaration::isDeprecated()
{
    return isdeprecated;
}

int AggregateDeclaration::isExport()
{
    return protection == PROTexport;
}

/****************************
 * Do byte or word alignment as necessary.
 * Align sizes of 0, as we may not know array sizes yet.
 */

void AggregateDeclaration::alignmember(
        structalign_t salign,   // struct alignment that is in effect
        unsigned size,          // alignment requirement of field
        unsigned *poffset)
{
    //printf("salign = %d, size = %d, offset = %d\n",salign,size,offset);
    if (salign == STRUCTALIGN_DEFAULT)
        salign = 8;
    if (salign > 1)
    {
        assert(size != 3);
        unsigned sa = size;
        if (sa == 0 || salign < sa)
            sa = salign;
        *poffset = (*poffset + sa - 1) & ~(sa - 1);
    }
    //printf("result = %d\n",offset);
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
        structalign_t memalign, // alignment in effect for this member
        unsigned *paggsize,     // size of aggregate (updated)
        unsigned *paggalignsize, // size of aggregate for alignment purposes (updated)
        bool isunion            // the aggregate is a union
        )
{
    unsigned ofs = *nextoffset;
    alignmember(memalign, memalignsize, &ofs);
    unsigned memoffset = ofs;
    ofs += memsize;
    if (ofs > *paggsize)
        *paggsize = ofs;
    if (!isunion)
        *nextoffset = ofs;
    if (global.params.is64bit && memalign == 8 && memalignsize == 16)
        /* Not sure how to handle this */
        ;
    else if (memalign == STRUCTALIGN_DEFAULT && 8 < memalignsize)
        memalignsize = 8;
    else if (memalign < memalignsize)
        memalignsize = memalign;
    if (*paggalignsize < memalignsize)
        *paggalignsize = memalignsize;

    return memoffset;
}


/****************************************
 * If field[indx] is not part of a union, return indx.
 * Otherwise, return the lowest field index of the union.
 */
int AggregateDeclaration::firstFieldInUnion(int indx)
{
    if (isUnionDeclaration())
        return 0;
    VarDeclaration * vd = fields[indx];
    int firstNonZero = indx; // first index in the union with non-zero size
    for (; ;)
    {
        if (indx == 0)
            return firstNonZero;
        VarDeclaration * v = fields[indx - 1];
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
    VarDeclaration * vd = fields[firstIndex];
    /* If it is a zero-length field, AND we can't find an earlier non-zero
     * sized field with the same offset, we assume it's not part of a union.
     */
    if (vd->size(loc) == 0 && !isUnionDeclaration() &&
        firstFieldInUnion(firstIndex) == firstIndex)
        return 1;
    int count = 1;
    for (size_t i = firstIndex+1; i < fields.dim; ++i)
    {
        VarDeclaration * v = fields[i];
        // If offsets are different, they are not in the same union
        if (v->offset != vd->offset)
            break;
        ++count;
    }
    return count;
}

/********************************* StructDeclaration ****************************/

StructDeclaration::StructDeclaration(Loc loc, Identifier *id)
    : AggregateDeclaration(loc, id)
{
    zeroInit = 0;       // assume false until we do semantic processing
#if DMDV2
    hasIdentityAssign = 0;
    hasIdentityEquals = 0;
    cpctor = NULL;
    postblit = NULL;

    xeq = NULL;
    alignment = 0;
#endif
    arg1type = NULL;
    arg2type = NULL;

    // For forward references
    type = new TypeStruct(this);
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
    if (!members)                       // if forward reference
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
    {   sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }

    unsigned dprogress_save = Module::dprogress;

    parent = sc->parent;
    type = type->semantic(loc, sc);
#if STRUCTTHISREF
    handle = type;
#else
    handle = type->pointerTo();
#endif
    structalign = sc->structalign;
    protection = sc->protection;
    if (sc->stc & STCdeprecated)
        isdeprecated = 1;
    assert(!isAnonymous());
    if (sc->stc & STCabstract)
        error("structs, unions cannot be abstract");

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
    sc2->stc = 0;
    sc2->parent = this;
    if (isUnionDeclaration())
        sc2->inunion = 1;
    sc2->protection = PROTpublic;
    sc2->explicitProtection = 0;

    size_t members_dim = members->dim;

    /* Set scope so if there are forward references, we still might be able to
     * resolve individual members like enums.
     */
    for (size_t i = 0; i < members_dim; i++)
    {   Dsymbol *s = (*members)[i];
        /* There are problems doing this in the general case because
         * Scope keeps track of things like 'offset'
         */
        if (s->isEnumDeclaration() || (s->isAggregateDeclaration() && s->ident))
        {
            //printf("setScope %s %s\n", s->kind(), s->toChars());
            s->setScope(sc2);
        }
    }

    for (size_t i = 0; i < members_dim; i++)
    {
        Dsymbol *s = (*members)[i];
        //printf("test1 [%d] %s %d\n", i, s->toChars(), fields.dim);
        // Ungag errors when not speculative
        unsigned oldgag = global.gag;
        if (global.isSpeculativeGagging() && !isSpeculative())
        {
            global.gag = 0;
        }
        s->semantic(sc2);
        global.gag = oldgag;
#if 0
        if (sizeok == 2)
        {   //printf("forward reference\n");
            break;
        }
#endif
    }
    finalizeSize(sc2);

#if DMDV1
    /* This doesn't work for DMDV2 because (ref S) and (S) parameter
     * lists will overload the same.
     */
    /* The TypeInfo_Struct is expecting an opEquals and opCmp with
     * a parameter that is a pointer to the struct. But if there
     * isn't one, but is an opEquals or opCmp with a value, write
     * another that is a shell around the value:
     *  int opCmp(struct *p) { return opCmp(*p); }
     */

    TypeFunction *tfeqptr;
    {
        Parameters *arguments = new Parameters;
        Parameter *arg = new Parameter(STCin, handle, Id::p, NULL);

        arguments->push(arg);
        tfeqptr = new TypeFunction(arguments, Type::tint32, 0, LINKd);
        tfeqptr = (TypeFunction *)tfeqptr->semantic(0, sc);
    }

    TypeFunction *tfeq;
    {
        Parameters *arguments = new Parameters;
        Parameter *arg = new Parameter(STCin, type, NULL, NULL);

        arguments->push(arg);
        tfeq = new TypeFunction(arguments, Type::tint32, 0, LINKd);
        tfeq = (TypeFunction *)tfeq->semantic(0, sc);
    }

    Identifier *id = Id::eq;
    for (int i = 0; i < 2; i++)
    {
        Dsymbol *s = search_function(this, id);
        FuncDeclaration *fdx = s ? s->isFuncDeclaration() : NULL;
        if (fdx)
        {   FuncDeclaration *fd = fdx->overloadExactMatch(tfeqptr);
            if (!fd)
            {   fd = fdx->overloadExactMatch(tfeq);
                if (fd)
                {   // Create the thunk, fdptr
                    FuncDeclaration *fdptr = new FuncDeclaration(loc, loc, fdx->ident, STCundefined, tfeqptr);
                    Expression *e = new IdentifierExp(loc, Id::p);
                    e = new PtrExp(loc, e);
                    Expressions *args = new Expressions();
                    args->push(e);
                    e = new IdentifierExp(loc, id);
                    e = new CallExp(loc, e, args);
                    fdptr->fbody = new ReturnStatement(loc, e);
                    ScopeDsymbol *s = fdx->parent->isScopeDsymbol();
                    assert(s);
                    s->members->push(fdptr);
                    fdptr->addMember(sc, s, 1);
                    fdptr->semantic(sc2);
                }
            }
        }

        id = Id::cmp;
    }

    {
        Dsymbol *fopequals = search_function(this, Id::eq);
        Dsymbol *fopcmp    = search_function(this, Id::cmp);
        if (fopcmp && (!fopequals))
            deprecation(loc, "has `opCmp` without matching `opEquals`");
    }
#endif
#if DMDV2
    dtor = buildDtor(sc2);
    postblit = buildPostBlit(sc2);
    cpctor = buildCpCtor(sc2);

    buildOpAssign(sc2);
    hasIdentityEquals = (buildOpEquals(sc2) != NULL);

    xeq = buildXopEquals(sc2);
#endif

    sc2->pop();

    if (sizeok == 2)
    {   // semantic() failed because of forward references.
        // Unwind what we did, and defer it for later
        for (size_t i = 0; i < fields.dim; i++)
        {   Dsymbol *s = fields[i];
            VarDeclaration *vd = s->isVarDeclaration();
            if (vd)
                vd->offset = 0;
        }
        fields.setDim(0);
        structsize = 0;
        alignsize = 0;
        structalign = 0;

        scope = scx ? scx : new Scope(*sc);
        scope->setNoFree();
        scope->module->addDeferredSemantic(this);

        Module::dprogress = dprogress_save;
        //printf("\tdeferring %s\n", toChars());
        return;
    }

    // 0 sized struct's are set to 1 byte
    if (structsize == 0)
    {
        structsize = 1;
        alignsize = 1;
    }

    // Round struct size up to next alignsize boundary.
    // This will ensure that arrays of structs will get their internals
    // aligned properly.
    structsize = (structsize + alignsize - 1) & ~(alignsize - 1);

    sizeok = SIZEOKdone;
    Module::dprogress++;

    //printf("-StructDeclaration::semantic(this=%p, '%s')\n", this, toChars());

    // Determine if struct is all zeros or not
    zeroInit = 1;
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = (Dsymbol *)fields.data[i];
        VarDeclaration *vd = s->isVarDeclaration();
        if (vd && !vd->isDataseg())
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

    /* Look for special member functions.
     */
#if DMDV2
    ctor = search(0, Id::ctor, 0);
#endif
    inv =    (InvariantDeclaration *)search(0, Id::classInvariant, 0);
    aggNew =       (NewDeclaration *)search(0, Id::classNew,       0);
    aggDelete = (DeleteDeclaration *)search(0, Id::classDelete,    0);

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
}

Dsymbol *StructDeclaration::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s.StructDeclaration::search('%s')\n", toChars(), ident->toChars());

    if (scope && !symtab)
        semantic(scope);

    if (!members || !symtab)
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
    structsize = (structsize + alignsize - 1) & ~(alignsize - 1);

    sizeok = SIZEOKdone;
}

/***************************************
 * Return true if struct is POD (Plain Old Data).
 * This is defined as:
 *      not nested
 *      no postblits, constructors, destructors, or assignment operators
 *      no fields with with any of those
 * The idea being these are compatible with C structs.
 *
 * Note that D struct constructors can mean POD, since there is always default
 * construction with no ctor, but that interferes with OPstrpar which wants it
 * on the stack in memory, not in registers.
 */
bool StructDeclaration::isPOD()
{
    return true;
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
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];

        buf->writestring("    ");
        s->toCBuffer(buf, hgs);
    }
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


