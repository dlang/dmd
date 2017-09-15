/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _denum.d)
 */

module ddmd.denum;

import core.stdc.stdio;
import ddmd.root.rootobject;
import ddmd.gluelayer;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.mtype;
import ddmd.tokens;
import ddmd.visitor;

/***********************************************************
 */
extern (C++) final class EnumDeclaration : ScopeDsymbol
{
    /* The separate, and distinct, cases are:
     *  1. enum { ... }
     *  2. enum : memtype { ... }
     *  3. enum id { ... }
     *  4. enum id : memtype { ... }
     *  5. enum id : memtype;
     *  6. enum id;
     */
    Type type;              // the TypeEnum
    Type memtype;           // type of the members
    Prot protection;
    Expression maxval;
    Expression minval;
    Expression defaultval;  // default initializer
    bool isdeprecated;

    extern (D) this(Loc loc, Identifier id, Type memtype)
    {
        super(id);
        //printf("EnumDeclaration() %s\n", toChars());
        this.loc = loc;
        type = new TypeEnum(this);
        this.memtype = memtype;
        protection = Prot(PROTundefined);
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto ed = new EnumDeclaration(loc, ident, memtype ? memtype.syntaxCopy() : null);
        return ScopeDsymbol.syntaxCopy(ed);
    }

    // Anonymous enums -> add members to the enclosing scope during addMember()
    // Named enums -> add members during determineMembers()
    final void addEnumMembers(ScopeDsymbol sds)
    {
        /* Anonymous enum members get added to enclosing scope.
         */
        if (members)
        {
            for (size_t i = 0; i < members.dim; i++)
            {
                EnumMember em = (*members)[i].isEnumMember(); // FWDREF NOTE: why can't we have others Dsymbol (e.g attribs) in enums?
                em.ed = this;
                //printf("add %s to scope %s\n", em.toChars(), scopesym.toChars());
                em.addMember(_scope, sds);
            }
        }
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        version (none)
        {
            printf("EnumDeclaration::addMember() %s\n", toChars());
            for (size_t i = 0; i < members.dim; i++)
            {
                EnumMember em = (*members)[i].isEnumMember();
                printf("    member %s\n", em.toChars());
            }
        }

        if (addMemberState == SemState.Done)
            return;
        addMemberState = SemState.In;

        if (!isAnonymous())
            super.addMember(sc, sds);
        else
        {
            setScope(sc);
            addEnumMembers(sds);
        }

        addMemberState = SemState.Done;
    }

    override void setScope(Scope* sc)
    {
        super.setScope(sc);

        parent = sc.parent;

        protection = sc.protection;
        if (sc.stc & STCdeprecated)
            isdeprecated = true;
        userAttribDecl = sc.userAttribDecl;
    }

    override Scope* newScope()
    {
        Scope* sce = _scope.push(this);
        sce.parent = this;
        sce = sce.startCTFE();
        sce.setNoFree(); // needed for getMaxMinValue()
        return sce;
    }

    override void determineMembers()
    {
        if (isAnonymous())
        {
            // already added during addMember
            membersState = SemState.Done;
            return;
        }
        super.determineMembers();
    }

    override void semanticType()
    {
        if (typeState == SemState.Done)
            return;
        typeState = SemState.In;
        void defer() { typeState = SemState.Defer; }
        void errorReturn() { errors = true; typeState = SemState.Done; }

        type = type.semantic(loc, _scope);

        if (!memtype)
        {
            if (!members) // enum ident;
            {
                typeState = SemState.Done;
                return;
            }

            // FIXME BUG: this is incorrect if the first member has a small value but there's another member that doesn't fit in the first inferred type (the bug existed before FWDREF)
            if (members.dim)
            {
                auto em = (*members)[0].isEnumMember();
                em.semanticType();
                if (em.typeState == SemState.Defer)
                    return defer(); // memtype is forward referenced, so try again later
                memtype = em.type;
            }
            else
                memtype = Type.tint32;
        }

        memtype = memtype.semantic(loc, _scope);

        /* Check to see if memtype is forward referenced
            */
        if (memtype.ty == Tenum)
        {
            EnumDeclaration sym = cast(EnumDeclaration)memtype.toDsymbol(_scope);
            sym.semanticType();
            if (sym.typeState != SemState.Done)
                return defer(); // memtype is forward referenced, so try again later
        }
        if (memtype.ty == Tvoid)
        {
            error("base type must not be void");
            memtype = Type.terror;
        }
        if (memtype.ty == Terror)
        {
            if (members)
            {
                for (size_t i = 0; i < members.dim; i++)
                {
                    Dsymbol s = (*members)[i];
                    s.errors = true; // poison all the members
                }
            }
            return errorReturn();
        }

        typeState = SemState.Done;
    }

    override void semantic()
    {
        //printf("EnumDeclaration::semantic(sd = %p, '%s') %s\n", sc.scopesym, sc.scopesym.toChars(), toChars());
        //printf("EnumDeclaration::semantic() %p %s\n", this, toChars());
        uint dprogress_save = Module.dprogress;

        if (semanticState == SemState.Done)
            return;
        semanticState = SemState.In;
        void defer() { semanticState = SemState.Defer; }
        void errorReturn() { errors = true; semanticState = SemState.Done; }

        semanticType();
        determineMembers();
        if (membersState != SemState.Done)
            return defer();

        /* The separate, and distinct, cases are:
         *  1. enum { ... }
         *  2. enum : memtype { ... }
         *  3. enum ident { ... }
         *  4. enum ident : memtype { ... }
         *  5. enum ident : memtype;
         *  6. enum ident;
         */

        if (!members) // enum ident : memtype;
        {
            semanticState = SemState.Done;
            return;
        }

        if (members.dim == 0)
        {
            error("enum `%s` must have at least one member", toChars());
            return errorReturn();
        }

        Module.dprogress++;

        super.semantic();
        //printf("defaultval = %lld\n", defaultval);

        //if (defaultval) printf("defaultval: %s %s\n", defaultval.toChars(), defaultval.type.toChars());
        //printf("members = %s\n", members.toChars());
    }

    override bool oneMember(Dsymbol* ps, Identifier ident)
    {
        if (isAnonymous())
            return Dsymbol.oneMembers(members, ps, ident);
        return Dsymbol.oneMember(ps, ident);
    }

    override Type getType()
    {
        return type;
    }

    override const(char)* kind() const
    {
        return "enum";
    }

    // is Dsymbol deprecated?
    override bool isDeprecated()
    {
        return isdeprecated;
    }

    override Prot prot()
    {
        return protection;
    }

    /******************************
     * Get the value of the .max/.min property as an Expression.
     * Lazily computes the value and caches it in maxval/minval.
     * Reports any errors.
     * Params:
     *      loc = location to use for error messages
     *      id = Id::max or Id::min
     * Returns:
     *      corresponding value of .max/.min
     */
    Expression getMaxMinValue(Loc loc, Identifier id)
    {
        //printf("EnumDeclaration::getMaxValue()\n");
        bool first = true;

        Expression* pval = (id == Id.max) ? &maxval : &minval;

        Expression errorReturn()
        {
            *pval = new ErrorExp();
            return *pval;
        }

        if (semanticState == SemState.In) // FWDREF FIXME: this is half the story
        {
            error(loc, "recursive definition of `.%s` property", id.toChars());
            return errorReturn();
        }
        if (*pval)
            goto Ldone;

        semantic();
        if (semanticState == SemState.Defer)
            return new DeferExp();
        if (errors)
            return errorReturn();
        if (semanticState != SemState.Done)
        {
            error("is forward referenced looking for `.%s`", id.toChars());
            return errorReturn();
        }
        if (!(memtype && memtype.isintegral()))
        {
            error(loc, "has no `.%s` property because base type `%s` is not an integral type", id.toChars(), memtype ? memtype.toChars() : "");
            return errorReturn();
        }

        for (size_t i = 0; i < members.dim; i++)
        {
            EnumMember em = (*members)[i].isEnumMember();
            if (!em)
                continue;
            if (em.errors)
                return errorReturn();

            Expression e = em.value;
            if (first)
            {
                *pval = e;
                first = false;
            }
            else
            {
                /* In order to work successfully with UDTs,
                 * build expressions to do the comparisons,
                 * and let the semantic analyzer and constant
                 * folder give us the result.
                 */

                /* Compute:
                 *   if (e > maxval)
                 *      maxval = e;
                 */
                Expression ec = new CmpExp(id == Id.max ? TOKgt : TOKlt, em.loc, e, *pval);
//                 inuse++;
                ec = ec.semantic(em._scope);
//                 inuse--;
                ec = ec.ctfeInterpret();
                if (ec.toInteger())
                    *pval = e;
            }
        }
    Ldone:
        Expression e = *pval;
        if (e.op != TOKerror)
        {
            e = e.copy();
            e.loc = loc;
        }
        return e;
    }

    Expression getDefaultValue(Loc loc)
    {
        //printf("EnumDeclaration::getDefaultValue() %p %s\n", this, toChars());
        if (defaultval)
            return defaultval;

        semantic();
        if (semanticState == SemState.Defer)
            return new DeferExp();
        if (errors)
            goto Lerrors;
        if (semanticState != SemState.Done)
        {
            error(loc, "forward reference of `%s.init`", toChars());
            goto Lerrors;
        }

        foreach (const i; 0 .. members.dim)
        {
            EnumMember em = (*members)[i].isEnumMember();
            if (em)
            {
                defaultval = em.value;
                return defaultval;
            }
        }

    Lerrors:
        defaultval = new ErrorExp();
        return defaultval;
    }

    override inout(EnumDeclaration) isEnumDeclaration() inout
    {
        return this;
    }

    Symbol* sinit;

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class EnumMember : VarDeclaration
{
    /* Can take the following forms:
     *  1. id
     *  2. id = value
     *  3. type id = value
     */
    @property ref value() { return (cast(ExpInitializer)_init).exp; }

    // A cast() is injected to 'value' after semantic(),
    // but 'origValue' will preserve the original value,
    // or previous value + 1 if none was specified.
    Expression origValue;

    Type origType;

    EnumDeclaration ed;

    extern (D) this(Loc loc, Identifier id, Expression value, Type origType)
    {
        super(loc, null, id ? id : Id.empty, new ExpInitializer(loc, value));
        this.origValue = value;
        this.origType = origType;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new EnumMember(loc, ident, value ? value.syntaxCopy() : null, origType ? origType.syntaxCopy() : null);
    }

    override const(char)* kind() const
    {
        return "enum member";
    }

    override void setScope(Scope* sc)
    {
        super.setScope(sc);

        assert(sc.parent.isEnumDeclaration());
        if (!ed)
            ed = cast(EnumDeclaration)sc.parent;

        protection = ed.isAnonymous() ? ed.protection : Prot(PROTpublic);
        linkage = LINKd;
        storage_class = STCmanifest;
        userAttribDecl = ed.isAnonymous() ? ed.userAttribDecl : null;
    }

    override void semanticType()
    {
        if (typeState == SemState.Done)
            return;
        typeState = SemState.In;

        void defer() { typeState = SemState.Defer; }

        if (origType)
        {
            origType = origType.semantic(loc, _scope);
                if (origType.ty == Tdefer)
                    return defer();
            type = origType;
            assert(value); // "type id;" is not a valid enum member declaration
        }
        else
        {
            semanticInitializer();
            if (initializerState == SemState.Defer)
                return defer();
            type = value.type;
        }

        typeState = SemState.Done;
    }

    override void semanticInitializer()
    {
        if (initializerState == SemState.Done)
            return;
        initializerState = SemState.In;

        void defer() { initializerState = SemState.Defer; }
        void errorReturn() { errors = true;  initializerState = SemState.Done; }

        assert(ed);
        if (ed.errors)
            return errorReturn();


        // The first enum member is special
        bool first = (this == (*ed.members)[0]);

        if (value)
        {
            Expression e = value;
            assert(e.dyncast() == DYNCAST.expression);
            e = e.semantic(_scope);
            e = resolveProperties(_scope, e);
            e = e.ctfeInterpret();
            if (e.op == TOKdefer)
                return defer();
            if (e.op == TOKerror)
                return errorReturn();
            if (first && !ed.memtype && !ed.isAnonymous())
            {
                ed.memtype = e.type;
                if (ed.memtype.ty == Terror)
                {
                    ed.errors = true;
                    return errorReturn();
                }
                if (ed.memtype.ty != Terror)
                {
                    /* https://issues.dlang.org/show_bug.cgi?id=11746
                     * All of named enum members should have same type
                     * with the first member. If the following members were referenced
                     * during the first member semantic, their types should be unified.
                     */
                    for (size_t i = 0; i < ed.members.dim; i++)
                    {
                        EnumMember em = (*ed.members)[i].isEnumMember();
                        if (!em || em == this || em.initializerState != SemState.Done || em.origType)
                            continue;

                        //printf("[%d] em = %s, em.semanticRun = %d\n", i, toChars(), em.semanticRun);
                        Expression ev = em.value;
                        ev = ev.implicitCastTo(_scope, ed.memtype);
                        ev = ev.ctfeInterpret();
                        ev = ev.castTo(_scope, ed.type);
                        if (ev.op == TOKerror)
                            ed.errors = true;
                        em.value = ev;
                    }
                    if (ed.errors)
                    {
                        ed.memtype = Type.terror;
                        return errorReturn();
                    }
                }
            }

            if (ed.memtype && !origType)
            {
                e = e.implicitCastTo(_scope, ed.memtype);
                e = e.ctfeInterpret();

                // save origValue for better json output
                origValue = e;

                if (!ed.isAnonymous())
                {
                    e = e.castTo(_scope, ed.type);
                    e = e.ctfeInterpret();
                }
            }
            else if (origType)
            {
                e = e.implicitCastTo(_scope, origType);
                e = e.ctfeInterpret();
                assert(ed.isAnonymous());

                // save origValue for better json output
                origValue = e;
            }
            value = e;
        }
        else if (first)
        {
            Type t;
            if (ed.memtype)
                t = ed.memtype;
            else
            {
                t = Type.tint32;
                if (!ed.isAnonymous())
                    ed.memtype = t;
            }
            Expression e = new IntegerExp(loc, 0, Type.tint32);
            e = e.implicitCastTo(_scope, t);
            e = e.ctfeInterpret();

            // save origValue for better json output
            origValue = e;

            if (!ed.isAnonymous())
            {
                e = e.castTo(_scope, ed.type);
                e = e.ctfeInterpret();
            }
            value = e;
        }
        else
        {
            /* Find the previous enum member,
             * and set this to be the previous value + 1
             */
            EnumMember emprev = null;
            for (size_t i = 0; i < ed.members.dim; i++)
            {
                EnumMember em = (*ed.members)[i].isEnumMember();
                if (em)
                {
                    if (em == this)
                        break;
                    emprev = em;
                }
            }
            assert(emprev);
            if (emprev.initializerState != SemState.Done) // if forward reference
                emprev.semanticInitializer(); // resolve it
            if (emprev.errors)
                return errorReturn();
            if (emprev.initializerState != SemState.Done)
                return defer();

            Expression eprev = emprev.value;
            Type tprev = eprev.type.equals(ed.type) ? ed.memtype : eprev.type;

            Expression emax = tprev.getProperty(ed.loc, Id.max, 0);
            emax = emax.semantic(_scope);
            emax = emax.ctfeInterpret();

            // Set value to (eprev + 1).
            // But first check that (eprev != emax)
            assert(eprev);
            Expression e = new EqualExp(TOKequal, loc, eprev, emax);
            e = e.semantic(_scope);
            e = e.ctfeInterpret();
            if (e.toInteger())
            {
                error("initialization with `%s.%s+1` causes overflow for type `%s`",
                    emprev.ed.toChars(), emprev.toChars(), ed.memtype.toChars());
                return errorReturn();
            }

            // Now set e to (eprev + 1)
            e = new AddExp(loc, eprev, new IntegerExp(loc, 1, Type.tint32));
            e = e.semantic(_scope);
            e = e.castTo(_scope, eprev.type);
            e = e.ctfeInterpret();

            // save origValue (without cast) for better json output
            if (e.op != TOKerror) // avoid duplicate diagnostics
            {
                assert(emprev.origValue);
                origValue = new AddExp(loc, emprev.origValue, new IntegerExp(loc, 1, Type.tint32));
                origValue = origValue.semantic(_scope);
                origValue = origValue.ctfeInterpret();
            }

            if (e.op == TOKerror)
                return errorReturn();
            if (e.type.isfloating())
            {
                // Check that e != eprev (not always true for floats)
                Expression etest = new EqualExp(TOKequal, loc, e, eprev);
                etest = etest.semantic(_scope);
                etest = etest.ctfeInterpret();
                if (etest.toInteger())
                {
                    error("has inexact value due to loss of precision");
                    return errorReturn();
                }
            }
            value = e;
        }

        assert(origValue);

        initializerState = SemState.Done;
    }

    override void semantic()
    {
        //printf("EnumMember::semantic() %s\n", toChars());

        semanticType();
        semanticInitializer();
    }

    Expression getVarExp(Loc loc, Scope* sc)
    {
        semantic();
        if (errors)
            return new ErrorExp();
        if (initializerState != SemState.Done)
            return new DeferExp();
        Expression e = new VarExp(loc, this);
        return e.semantic(sc);
    }

    override inout(EnumMember) isEnumMember() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
