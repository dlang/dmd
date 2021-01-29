/**
 * Define `enum` declarations and `enum` members.
 *
 * Specification: $(LINK2 https://dlang.org/spec/enum.html, Enums)
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/denum.d, _denum.d)
 * Documentation:  https://dlang.org/phobos/dmd_denum.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/denum.d
 * References:  https://dlang.org/spec/enum.html
 */

module dmd.denum;

import core.stdc.stdio;

import dmd.attrib;
import dmd.gluelayer;
import dmd.declaration;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.expression;
import dmd.expressionsem;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.mtype;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

/***********************************************************
 * AST node for `EnumDeclaration`
 * https://dlang.org/spec/enum.html#EnumDeclaration
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

    Visibility visibility;
    Expression maxval;
    Expression minval;
    Expression defaultval;  // default initializer
    bool isdeprecated;
    bool added;
    int inuse;

    extern (D) this(const ref Loc loc, Identifier ident, Type memtype)
    {
        super(loc, ident);
        //printf("EnumDeclaration() %s\n", toChars());
        type = new TypeEnum(this);
        this.memtype = memtype;
        visibility = Visibility(Visibility.Kind.undefined);
    }

    override EnumDeclaration syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto ed = new EnumDeclaration(loc, ident, memtype ? memtype.syntaxCopy() : null);
        ScopeDsymbol.syntaxCopy(ed);
        return ed;
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

        /* Anonymous enum members get added to enclosing scope.
         */
        ScopeDsymbol scopesym = isAnonymous() ? sds : this;

        if (!isAnonymous())
        {
            ScopeDsymbol.addMember(sc, sds);
            if (!symtab)
                symtab = new DsymbolTable();
        }

        if (members)
        {
            for (size_t i = 0; i < members.dim; i++)
            {
                EnumMember em = (*members)[i].isEnumMember();
                em.ed = this;
                //printf("add %s to scope %s\n", em.toChars(), scopesym.toChars());
                em.addMember(sc, isAnonymous() ? scopesym : this);
            }
        }
        added = true;
    }

    override void setScope(Scope* sc)
    {
        if (semanticRun > PASS.init)
            return;
        ScopeDsymbol.setScope(sc);
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

    override Dsymbol search(const ref Loc loc, Identifier ident, int flags = SearchLocalsOnly)
    {
        //printf("%s.EnumDeclaration::search('%s')\n", toChars(), ident.toChars());
        if (_scope)
        {
            // Try one last time to resolve this enum
            dsymbolSemantic(this, _scope);
        }

        if (!members || !symtab || _scope)
        {
            error("is forward referenced when looking for `%s`", ident.toChars());
            //*(char*)0=0;
            return null;
        }

        Dsymbol s = ScopeDsymbol.search(loc, ident, flags);
        return s;
    }

    // is Dsymbol deprecated?
    override bool isDeprecated() const
    {
        return isdeprecated;
    }

    override Visibility visible() pure nothrow @nogc @safe
    {
        return visibility;
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
    Expression getMaxMinValue(const ref Loc loc, Identifier id)
    {
        //printf("EnumDeclaration::getMaxValue()\n");

        static Expression pvalToResult(Expression e, const ref Loc loc)
        {
            if (e.op != TOK.error)
            {
                e = e.copy();
                e.loc = loc;
            }
            return e;
        }

        Expression* pval = (id == Id.max) ? &maxval : &minval;

        Expression errorReturn()
        {
            *pval = ErrorExp.get();
            return *pval;
        }

        if (inuse)
        {
            error(loc, "recursive definition of `.%s` property", id.toChars());
            return errorReturn();
        }
        if (*pval)
            return pvalToResult(*pval, loc);

        if (_scope)
            dsymbolSemantic(this, _scope);
        if (errors)
            return errorReturn();
        if (semanticRun == PASS.init || !members)
        {
            if (isSpecial())
            {
                /* Allow these special enums to not need a member list
                 */
                return memtype.getProperty(_scope, loc, id, 0);
            }

            error("is forward referenced looking for `.%s`", id.toChars());
            return errorReturn();
        }
        if (!(memtype && memtype.isintegral()))
        {
            error(loc, "has no `.%s` property because base type `%s` is not an integral type", id.toChars(), memtype ? memtype.toChars() : "");
            return errorReturn();
        }

        bool first = true;
        for (size_t i = 0; i < members.dim; i++)
        {
            EnumMember em = (*members)[i].isEnumMember();
            if (!em)
                continue;
            if (em.errors)
            {
                errors = true;
                continue;
            }

            if (first)
            {
                *pval = em.value;
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
                Expression e = em.value;
                Expression ec = new CmpExp(id == Id.max ? TOK.greaterThan : TOK.lessThan, em.loc, e, *pval);
                inuse++;
                ec = ec.expressionSemantic(em._scope);
                inuse--;
                ec = ec.ctfeInterpret();
                if (ec.op == TOK.error)
                {
                    errors = true;
                    continue;
                }
                if (ec.toInteger())
                    *pval = e;
            }
        }
        return errors ? errorReturn() : pvalToResult(*pval, loc);
    }

    /****************
     * Determine if enum is a special one.
     * Returns:
     *  `true` if special
     */
    bool isSpecial() const nothrow @nogc
    {
        return isSpecialEnumIdent(ident) && memtype;
    }

    Expression getDefaultValue(const ref Loc loc)
    {
        Expression handleErrors(){
            defaultval = ErrorExp.get();
            return defaultval;
        }
        //printf("EnumDeclaration::getDefaultValue() %p %s\n", this, toChars());
        if (defaultval)
            return defaultval;

        if (_scope)
            dsymbolSemantic(this, _scope);
        if (errors)
            return handleErrors();
        if (semanticRun == PASS.init || !members)
        {
            if (isSpecial())
            {
                /* Allow these special enums to not need a member list
                 */
                return memtype.defaultInit(loc);
            }

            error(loc, "forward reference of `%s.init`", toChars());
            return handleErrors();
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
        return handleErrors();
    }

    Type getMemtype(const ref Loc loc)
    {
        if (_scope)
        {
            /* Enum is forward referenced. We don't need to resolve the whole thing,
             * just the base type
             */
            if (memtype)
            {
                Loc locx = loc.isValid() ? loc : this.loc;
                memtype = memtype.typeSemantic(locx, _scope);
            }
            else
            {
                if (!isAnonymous() && members)
                    memtype = Type.tint32;
            }
        }
        if (!memtype)
        {
            if (!isAnonymous() && members)
                memtype = Type.tint32;
            else
            {
                Loc locx = loc.isValid() ? loc : this.loc;
                error(locx, "is forward referenced looking for base type");
                return Type.terror;
            }
        }
        return memtype;
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
 * AST node representing a member of an enum.
 * https://dlang.org/spec/enum.html#EnumMember
 * https://dlang.org/spec/enum.html#AnonymousEnumMember
 */
extern (C++) final class EnumMember : VarDeclaration
{
    /* Can take the following forms:
     *  1. id
     *  2. id = value
     *  3. type id = value
     */
    @property ref value() { return (cast(ExpInitializer)_init).exp; }

    // A cast() is injected to 'value' after dsymbolSemantic(),
    // but 'origValue' will preserve the original value,
    // or previous value + 1 if none was specified.
    Expression origValue;

    Type origType;

    EnumDeclaration ed;

    extern (D) this(const ref Loc loc, Identifier id, Expression value, Type origType)
    {
        super(loc, null, id ? id : Id.empty, new ExpInitializer(loc, value));
        this.origValue = value;
        this.origType = origType;
    }

    extern(D) this(Loc loc, Identifier id, Expression value, Type memtype,
        StorageClass stc, UserAttributeDeclaration uad, DeprecatedDeclaration dd)
    {
        this(loc, id, value, memtype);
        storage_class = stc;
        userAttribDecl = uad;
        depdecl = dd;
    }

    override EnumMember syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new EnumMember(
            loc, ident,
            value ? value.syntaxCopy() : null,
            origType ? origType.syntaxCopy() : null,
            storage_class,
            userAttribDecl ? userAttribDecl.syntaxCopy(s) : null,
            depdecl ? depdecl.syntaxCopy(s) : null);
    }

    override const(char)* kind() const
    {
        return "enum member";
    }

    Expression getVarExp(const ref Loc loc, Scope* sc)
    {
        dsymbolSemantic(this, sc);
        if (errors)
            return ErrorExp.get();
        checkDisabled(loc, sc);

        if (depdecl && !depdecl._scope)
            depdecl._scope = sc;
        checkDeprecated(loc, sc);

        if (errors)
            return ErrorExp.get();
        Expression e = new VarExp(loc, this);
        return e.expressionSemantic(sc);
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

/******************************************
 * Check for special enum names.
 *
 * Special enum names are used by the C++ name mangler to represent
 * C++ types that are not basic D types.
 * Params:
 *      ident = identifier to check for specialness
 * Returns:
 *      `true` if it is special
 */
bool isSpecialEnumIdent(const Identifier ident) @nogc nothrow
{
    return  ident == Id.__c_long ||
            ident == Id.__c_ulong ||
            ident == Id.__c_longlong ||
            ident == Id.__c_ulonglong ||
            ident == Id.__c_long_double ||
            ident == Id.__c_wchar_t ||
            ident == Id.__c_complex_float ||
            ident == Id.__c_complex_double ||
            ident == Id.__c_complex_real;
}
