/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _aggregate.d)
 */

module ddmd.aggregate;

import core.stdc.stdio;
import core.checkedint;

import ddmd.arraytypes;
import ddmd.gluelayer;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.tokens;
import ddmd.visitor;

enum Sizeok : int
{
    SIZEOKnone,             // size of aggregate is not yet able to compute
    SIZEOKfwd,              // size of aggregate is ready to compute
    SIZEOKdone,             // size of aggregate is set correctly
}

alias SIZEOKnone = Sizeok.SIZEOKnone;
alias SIZEOKdone = Sizeok.SIZEOKdone;
alias SIZEOKfwd = Sizeok.SIZEOKfwd;

enum Baseok : int
{
    BASEOKnone,             // base classes not computed yet
    BASEOKin,               // in process of resolving base classes
    BASEOKdone,             // all base classes are resolved
    BASEOKsemanticdone,     // all base classes semantic done
}

alias BASEOKnone = Baseok.BASEOKnone;
alias BASEOKin = Baseok.BASEOKin;
alias BASEOKdone = Baseok.BASEOKdone;
alias BASEOKsemanticdone = Baseok.BASEOKsemanticdone;

/***********************************************************
 */
extern (C++) abstract class AggregateDeclaration : ScopeDsymbol
{
    Type type;
    StorageClass storage_class;
    Prot protection;
    uint structsize;        // size of struct
    uint alignsize;         // size of struct for alignment purposes
    VarDeclarations fields; // VarDeclaration fields
    Sizeok sizeok;          // set when structsize contains valid data
    Dsymbol deferred;       // any deferred semantic2() or semantic3() symbol
    bool isdeprecated;      // true if deprecated

    /* !=null if is nested
     * pointing to the dsymbol that directly enclosing it.
     * 1. The function that enclosing it (nested struct and class)
     * 2. The class that enclosing it (nested class only)
     * 3. If enclosing aggregate is template, its enclosing dsymbol.
     * See AggregateDeclaraton::makeNested for the details.
     */
    Dsymbol enclosing;

    VarDeclaration vthis;   // 'this' parameter if this aggregate is nested

    // Special member functions
    FuncDeclarations invs;          // Array of invariants
    FuncDeclaration inv;            // invariant
    NewDeclaration aggNew;          // allocator
    DeleteDeclaration aggDelete;    // deallocator

    // CtorDeclaration or TemplateDeclaration
    Dsymbol ctor;

    // default constructor - should have no arguments, because
    // it would be stored in TypeInfo_Class.defaultConstructor
    CtorDeclaration defaultCtor;

    Dsymbol aliasthis;      // forward unresolved lookups to aliasthis
    bool noDefaultCtor;     // no default construction

    FuncDeclarations dtors; // Array of destructors
    FuncDeclaration dtor;   // aggregate destructor

    Expression getRTInfo;   // pointer to GC info generated by object.RTInfo(this)

    final extern (D) this(Loc loc, Identifier id)
    {
        super(id);
        this.loc = loc;
        protection = Prot(PROTpublic);
        sizeok = SIZEOKnone; // size not determined yet
    }

    /***************************************
     * Create a new scope from sc.
     * semantic, semantic2 and semantic3 will use this for aggregate members.
     */
    Scope* newScope(Scope* sc)
    {
        auto sc2 = sc.push(this);
        sc2.stc &= STCsafe | STCtrusted | STCsystem;
        sc2.parent = this;
        if (isUnionDeclaration())
            sc2.inunion = 1;
        sc2.protection = Prot(PROTpublic);
        sc2.explicitProtection = 0;
        sc2.aligndecl = null;
        sc2.userAttribDecl = null;
        return sc2;
    }

    override final void setScope(Scope* sc)
    {
        // Might need a scope to resolve forward references. The check for
        // semanticRun prevents unnecessary setting of _scope during deferred
        // setScope phases for aggregates which already finished semantic().
        // See https://issues.dlang.org/show_bug.cgi?id=16607
        if (semanticRun < PASSsemanticdone)
            ScopeDsymbol.setScope(sc);
    }

    override final void semantic2(Scope* sc)
    {
        //printf("AggregateDeclaration::semantic2(%s) type = %s, errors = %d\n", toChars(), type.toChars(), errors);
        if (!members)
            return;

        if (_scope)
        {
            error("has forward references");
            return;
        }

        auto sc2 = newScope(sc);

        determineSize(loc);

        for (size_t i = 0; i < members.dim; i++)
        {
            Dsymbol s = (*members)[i];
            //printf("\t[%d] %s\n", i, s.toChars());
            s.semantic2(sc2);
        }

        sc2.pop();
    }

    override final void semantic3(Scope* sc)
    {
        //printf("AggregateDeclaration::semantic3(sc=%p, %s) type = %s, errors = %d\n", sc, toChars(), type.toChars(), errors);
        if (!members)
            return;

        StructDeclaration sd = isStructDeclaration();
        if (!sc) // from runDeferredSemantic3 for TypeInfo generation
        {
            assert(sd);
            sd.semanticTypeInfoMembers();
            return;
        }

        auto sc2 = newScope(sc);

        for (size_t i = 0; i < members.dim; i++)
        {
            Dsymbol s = (*members)[i];
            s.semantic3(sc2);
        }

        sc2.pop();

        // don't do it for unused deprecated types
        // or error types
        if (!getRTInfo && Type.rtinfo && (!isDeprecated() || global.params.useDeprecated) && (type && type.ty != Terror))
        {
            // Evaluate: RTinfo!type
            auto tiargs = new Objects();
            tiargs.push(type);
            auto ti = new TemplateInstance(loc, Type.rtinfo, tiargs);

            Scope* sc3 = ti.tempdecl._scope.startCTFE();
            sc3.tinst = sc.tinst;
            sc3.minst = sc.minst;
            if (isDeprecated())
                sc3.stc |= STCdeprecated;

            ti.semantic(sc3);
            ti.semantic2(sc3);
            ti.semantic3(sc3);
            auto e = DsymbolExp.resolve(Loc(), sc3, ti.toAlias(), false);

            sc3.endCTFE();

            e = e.ctfeInterpret();
            getRTInfo = e;
        }
        if (sd)
            sd.semanticTypeInfoMembers();
        semanticRun = PASSsemantic3done;
    }

    /***************************************
     * Find all instance fields, then push them into `fields`.
     *
     * Runs semantic() for all instance field variables, but also
     * the field types can reamin yet not resolved forward references,
     * except direct recursive definitions.
     * After the process sizeok is set to SIZEOKfwd.
     *
     * Returns:
     *      false if any errors occur.
     */
    final bool determineFields()
    {
        if (sizeok != SIZEOKnone)
            return true;

        //printf("determineFields() %s, fields.dim = %d\n", toChars(), fields.dim);
        // determineFields can be called recursively from one of the fields's v.semantic
        fields.setDim(0);

        extern (C++) static int func(Dsymbol s, void* param)
        {
            auto v = s.isVarDeclaration();
            if (!v)
                return 0;
            if (v.storage_class & STCmanifest)
                return 0;

            auto ad = cast(AggregateDeclaration)param;

            if (v.semanticRun < PASSsemanticdone)
                v.semantic(null);
            // Return in case a recursive determineFields triggered by v.semantic already finished
            if (ad.sizeok != SIZEOKnone)
                return 1;

            if (v.aliassym)
                return 0;   // If this variable was really a tuple, skip it.

            if (v.storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCmanifest | STCctfe | STCtemplateparameter)) // FWDREF FIXME: we should skip static variables, but part of semantic should have run to know that
                return 0;
            if (!v.isField() || v.semanticRun < PASSsemanticdone)
                return 1;   // unresolvable forward reference

            ad.fields.push(v);

            if (v.storage_class & STCref)
                return 0;
            auto tv = v.type.baseElemOf();
            if (tv.ty != Tstruct)
                return 0;
            if (ad == (cast(TypeStruct)tv).sym)
            {
                const(char)* psz = (v.type.toBasetype().ty == Tsarray) ? "static array of " : "";
                ad.error("cannot have field `%s` with %ssame struct type", v.toChars(), psz);
                ad.type = Type.terror;
                ad.errors = true;
                return 1;
            }
            return 0;
        }

        for (size_t i = 0; i < members.dim; i++)
        {
            auto s = (*members)[i];
            if (s.apply(&func, cast(void*)this))
            {
                if (sizeok != SIZEOKnone)
                {
                    // recursive determineFields already finished
                    return true;
                }
                return false;
            }
        }

        if (sizeok != SIZEOKdone)
            sizeok = SIZEOKfwd;

        return true;
    }

    /***************************************
     * Collect all instance fields, then determine instance size.
     * Returns:
     *      false if failed to determine the size.
     */
    final bool determineSize(Loc loc)
    {
        //printf("AggregateDeclaration::determineSize() %s, sizeok = %d\n", toChars(), sizeok);

        // The previous instance size finalizing had:
        if (type.ty == Terror)
            return false;   // failed already
        if (sizeok == SIZEOKdone)
            return true;    // succeeded

        if (!members)
        {
            error(loc, "unknown size");
            return false;
        }

        if (_scope)
            importAll(_scope);

        // Determine the instance size of base class first.
        if (auto cd = isClassDeclaration())
        {
            cd = cd.baseClass;
            if (cd && !cd.determineSize(loc))
                goto Lfail;
        }

        // Determine instance fields when sizeok == SIZEOKnone
        if (!determineFields())
            goto Lfail;
        if (sizeok != SIZEOKdone)
            finalizeSize();

        // this aggregate type has:
        if (type.ty == Terror)
            return false;   // marked as invalid during the finalizing.
        if (sizeok == SIZEOKdone)
            return true;    // succeeded to calculate instance size.

    Lfail:
        // There's unresolvable forward reference.
        if (type != Type.terror)
            error(loc, "no size because of forward reference");
        // Don't cache errors from speculative semantic, might be resolvable later.
        // https://issues.dlang.org/show_bug.cgi?id=16574
        if (!global.gag)
        {
            type = Type.terror;
            errors = true;
        }
        return false;
    }

    abstract void finalizeSize();

    override final d_uns64 size(Loc loc)
    {
        //printf("+AggregateDeclaration::size() %s, scope = %p, sizeok = %d\n", toChars(), _scope, sizeok);
        bool ok = determineSize(loc);
        //printf("-AggregateDeclaration::size() %s, scope = %p, sizeok = %d\n", toChars(), _scope, sizeok);
        return ok ? structsize : SIZE_INVALID;
    }

    /***************************************
     * Calculate field[i].overlapped and overlapUnsafe, and check that all of explicit
     * field initializers have unique memory space on instance.
     * Returns:
     *      true if any errors happen.
     */
    final bool checkOverlappedFields()
    {
        //printf("AggregateDeclaration::checkOverlappedFields() %s\n", toChars());
        assert(sizeok == SIZEOKdone);
        size_t nfields = fields.dim;
        if (isNested())
        {
            auto cd = isClassDeclaration();
            if (!cd || !cd.baseClass || !cd.baseClass.isNested())
                nfields--;
        }
        bool errors = false;

        // Fill in missing any elements with default initializers
        foreach (i; 0 .. nfields)
        {
            auto vd = fields[i];
            if (vd.errors)
            {
                errors = true;
                continue;
            }

            auto vx = vd;
            if (vd._init && vd._init.isVoidInitializer())
                vx = null;

            // Find overlapped fields with the hole [vd.offset .. vd.offset.size()].
            foreach (j; 0 .. nfields)
            {
                if (i == j)
                    continue;
                auto v2 = fields[j];
                if (v2.errors)
                {
                    errors = true;
                    continue;
                }
                if (!vd.isOverlappedWith(v2))
                    continue;

                // vd and v2 are overlapping.
                vd.overlapped = true;
                v2.overlapped = true;

                if (!MODimplicitConv(vd.type.mod, v2.type.mod))
                    v2.overlapUnsafe = true;
                if (!MODimplicitConv(v2.type.mod, vd.type.mod))
                    vd.overlapUnsafe = true;

                if (!vx)
                    continue;
                if (v2._init && v2._init.isVoidInitializer())
                    continue;

                if (vx._init && v2._init)
                {
                    .error(loc, "overlapping default initialization for field `%s` and `%s`", v2.toChars(), vd.toChars());
                    errors = true;
                }
            }
        }
        return errors;
    }

    /***************************************
     * Fill out remainder of elements[] with default initializers for fields[].
     * Params:
     *      loc         = location
     *      elements    = explicit arguments which given to construct object.
     *      ctorinit    = true if the elements will be used for default initialization.
     * Returns:
     *      false if any errors occur.
     *      Otherwise, returns true and the missing arguments will be pushed in elements[].
     */
    final bool fill(Loc loc, Expressions* elements, bool ctorinit)
    {
        //printf("AggregateDeclaration::fill() %s\n", toChars());
        assert(sizeok == SIZEOKdone);
        assert(elements);
        size_t nfields = fields.dim - isNested();
        bool errors = false;

        size_t dim = elements.dim;
        elements.setDim(nfields);
        foreach (size_t i; dim .. nfields)
            (*elements)[i] = null;

        // Fill in missing any elements with default initializers
        foreach (i; 0 .. nfields)
        {
            if ((*elements)[i])
                continue;

            auto vd = fields[i];
            auto vx = vd;
            if (vd._init && vd._init.isVoidInitializer())
                vx = null;

            // Find overlapped fields with the hole [vd.offset .. vd.offset.size()].
            size_t fieldi = i;
            foreach (j; 0 .. nfields)
            {
                if (i == j)
                    continue;
                auto v2 = fields[j];
                if (!vd.isOverlappedWith(v2))
                    continue;

                if ((*elements)[j])
                {
                    vx = null;
                    break;
                }
                if (v2._init && v2._init.isVoidInitializer())
                    continue;

                version (all)
                {
                    /* Prefer first found non-void-initialized field
                     * union U { int a; int b = 2; }
                     * U u;    // Error: overlapping initialization for field a and b
                     */
                    if (!vx)
                    {
                        vx = v2;
                        fieldi = j;
                    }
                    else if (v2._init)
                    {
                        .error(loc, "overlapping initialization for field `%s` and `%s`", v2.toChars(), vd.toChars());
                        errors = true;
                    }
                }
                else
                {
                    // fixes https://issues.dlang.org/show_bug.cgi?id=1432 by enabling this path always

                    /* Prefer explicitly initialized field
                     * union U { int a; int b = 2; }
                     * U u;    // OK (u.b == 2)
                     */
                    if (!vx || !vx._init && v2._init)
                    {
                        vx = v2;
                        fieldi = j;
                    }
                    else if (vx != vd && !vx.isOverlappedWith(v2))
                    {
                        // Both vx and v2 fills vd, but vx and v2 does not overlap
                    }
                    else if (vx._init && v2._init)
                    {
                        .error(loc, "overlapping default initialization for field `%s` and `%s`",
                            v2.toChars(), vd.toChars());
                        errors = true;
                    }
                    else
                        assert(vx._init || !vx._init && !v2._init);
                }
            }
            if (vx)
            {
                Expression e;
                if (vx.type.size() == 0)
                {
                    e = null;
                }
                else if (vx._init)
                {
                    assert(!vx._init.isVoidInitializer());
                    e = vx.getConstInitializer(false);
                }
                else
                {
                    if ((vx.storage_class & STCnodefaultctor) && !ctorinit)
                    {
                        .error(loc, "field `%s.%s` must be initialized because it has no default constructor",
                            type.toChars(), vx.toChars());
                        errors = true;
                    }
                    /* https://issues.dlang.org/show_bug.cgi?id=12509
                     * Get the element of static array type.
                     */
                    Type telem = vx.type;
                    if (telem.ty == Tsarray)
                    {
                        /* We cannot use Type::baseElemOf() here.
                         * If the bottom of the Tsarray is an enum type, baseElemOf()
                         * will return the base of the enum, and its default initializer
                         * would be different from the enum's.
                         */
                        while (telem.toBasetype().ty == Tsarray)
                            telem = (cast(TypeSArray)telem.toBasetype()).next;
                        if (telem.ty == Tvoid)
                            telem = Type.tuns8.addMod(telem.mod);
                    }
                    if (telem.needsNested() && ctorinit)
                        e = telem.defaultInit(loc);
                    else
                        e = telem.defaultInitLiteral(loc);
                }
                (*elements)[fieldi] = e;
            }
        }
        foreach (e; *elements)
        {
            if (e && e.op == TOKerror)
                return false;
        }

        return !errors;
    }

    /****************************
     * Do byte or word alignment as necessary.
     * Align sizes of 0, as we may not know array sizes yet.
     *
     * alignment: struct alignment that is in effect
     * size: alignment requirement of field
     */
    static void alignmember(structalign_t alignment, uint size, uint* poffset)
    {
        //printf("alignment = %d, size = %d, offset = %d\n",alignment,size,offset);
        switch (alignment)
        {
        case cast(structalign_t)1:
            // No alignment
            break;

        case cast(structalign_t)STRUCTALIGN_DEFAULT:
            // Alignment in Target::fieldalignsize must match what the
            // corresponding C compiler's default alignment behavior is.
            assert(size > 0 && !(size & (size - 1)));
            *poffset = (*poffset + size - 1) & ~(size - 1);
            break;

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
     *
     * nextoffset:    next location in aggregate
     * memsize:       size of member
     * memalignsize:  natural alignment of member
     * alignment:     alignment in effect for this member
     * paggsize:      size of aggregate (updated)
     * paggalignsize: alignment of aggregate (updated)
     * isunion:       the aggregate is a union
     */
    static uint placeField(uint* nextoffset, uint memsize, uint memalignsize,
        structalign_t alignment, uint* paggsize, uint* paggalignsize, bool isunion)
    {
        uint ofs = *nextoffset;

        const uint actualAlignment =
            alignment == STRUCTALIGN_DEFAULT ? memalignsize : alignment;

        // Ensure no overflow
        bool overflow;
        const sz = addu(memsize, actualAlignment, overflow);
        const sum = addu(ofs, sz, overflow);
        if (overflow) assert(0);

        alignmember(alignment, memalignsize, &ofs);
        uint memoffset = ofs;
        ofs += memsize;
        if (ofs > *paggsize)
            *paggsize = ofs;
        if (!isunion)
            *nextoffset = ofs;

        if (*paggalignsize < actualAlignment)
            *paggalignsize = actualAlignment;

        return memoffset;
    }

    override final Type getType()
    {
        return type;
    }

    // is aggregate deprecated?
    override final bool isDeprecated()
    {
        return isdeprecated;
    }

    /****************************************
     * Returns true if there's an extra member which is the 'this'
     * pointer to the enclosing context (enclosing aggregate or function)
     */
    final bool isNested()
    {
        return enclosing !is null;
    }

    /* Append vthis field (this.tupleof[$-1]) to make this aggregate type nested.
     */
    final void makeNested()
    {
        if (enclosing) // if already nested
            return;
        if (sizeok == SIZEOKdone)
            return;
        if (isUnionDeclaration() || isInterfaceDeclaration())
            return;
        if (storage_class & STCstatic)
            return;

        // If nested struct, add in hidden 'this' pointer to outer scope
        auto s = toParent2();
        if (!s)
            return;
        Type t = null;
        if (auto fd = s.isFuncDeclaration())
        {
            enclosing = fd;

            /* https://issues.dlang.org/show_bug.cgi?id=14422
             * If a nested class parent is a function, its
             * context pointer (== `outer`) should be void* always.
             */
            t = Type.tvoidptr;
        }
        else if (auto ad = s.isAggregateDeclaration())
        {
            if (isClassDeclaration() && ad.isClassDeclaration())
            {
                enclosing = ad;
            }
            else if (isStructDeclaration())
            {
                if (auto ti = ad.parent.isTemplateInstance())
                {
                    enclosing = ti.enclosing;
                }
            }
            t = ad.handleType();
        }
        if (enclosing)
        {
            //printf("makeNested %s, enclosing = %s\n", toChars(), enclosing.toChars());
            assert(t);
            if (t.ty == Tstruct)
                t = Type.tvoidptr; // t should not be a ref type

            assert(!vthis);
            vthis = new ThisDeclaration(loc, t);
            //vthis.storage_class |= STCref;

            // Emulate vthis.addMember()
            members.push(vthis);

            // Emulate vthis.semantic()
            vthis.storage_class |= STCfield;
            vthis.parent = this;
            vthis.protection = Prot(PROTpublic);
            vthis.alignment = t.alignment();
            vthis.semanticRun = PASSsemanticdone;

            if (sizeok == SIZEOKfwd)
                fields.push(vthis);
        }
    }

    override final bool isExport()
    {
        return protection.kind == PROTexport;
    }

    /*******************************************
     * Look for constructor declaration.
     */
    final Dsymbol searchCtor()
    {
        auto s = search(Loc(), Id.ctor);
        if (s)
        {
            if (!(s.isCtorDeclaration() ||
                  s.isTemplateDeclaration() ||
                  s.isOverloadSet()))
            {
                s.error("is not a constructor; identifiers starting with __ are reserved for the implementation");
                errors = true;
                s = null;
            }
        }
        if (s && s.toParent() != this)
            s = null; // search() looks through ancestor classes
        if (s)
        {
            // Finish all constructors semantics to determine this.noDefaultCtor.
            struct SearchCtor
            {
                extern (C++) static int fp(Dsymbol s, void* ctxt)
                {
                    auto f = s.isCtorDeclaration();
                    if (f && f.semanticRun == PASSinit)
                        f.semantic(null);
                    return 0;
                }
            }

            for (size_t i = 0; i < members.dim; i++)
            {
                auto sm = (*members)[i];
                sm.apply(&SearchCtor.fp, null);
            }
        }
        return s;
    }

    override final Prot prot()
    {
        return protection;
    }

    // 'this' type
    final Type handleType()
    {
        return type;
    }

    // Back end
    Symbol* stag; // tag symbol for debug data
    Symbol* sinit;

    override final inout(AggregateDeclaration) isAggregateDeclaration() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
