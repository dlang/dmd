/**
 * Utility functions for Expressions
 *
 * Specification: ($LINK2 https://dlang.org/spec/expression.html, Expressions)
 *
 * Copyright:   Copyright (C) 1999-2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/expressionutil.d, _expressionutil.d)
 * Documentation:  https://dlang.org/phobos/dmd_expressionutil.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/expressionutil.d
 */

module dmd.expressionutil;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.string;

import dmd.aggregate;
import dmd.aliasthis;
import dmd.arrayop;
import dmd.arraytypes;
import dmd.astenums;
import dmd.ast_node;
import dmd.gluelayer;
import dmd.constfold;
import dmd.ctfeexpr;
import dmd.ctorflow;
import dmd.dcast;
import dmd.dclass;
import dmd.declaration;
import dmd.delegatize;
import dmd.dimport;
import dmd.dinterpret;
import dmd.dmodule;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.errors;
import dmd.errorsink;
import dmd.escape;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.inline;
import dmd.location;
import dmd.mtype;
import dmd.nspace;
import dmd.objc;
import dmd.opover;
import dmd.optimize;
import dmd.postordervisitor;
import dmd.root.complex;
import dmd.root.ctfloat;
import dmd.root.filename;
import dmd.common.outbuffer;
import dmd.root.optional;
import dmd.root.rmem;
import dmd.root.rootobject;
import dmd.root.string;
import dmd.root.utf;
import dmd.safe;
import dmd.sideeffect;
import dmd.target;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

enum LOGSEMANTIC = false;

/// Return value for `checkModifiable`
enum Modifiable
{
    /// Not modifiable
    no,
    /// Modifiable (the type is mutable)
    yes,
    /// Modifiable because it is initialization
    initialization,
}
/**
 * Specifies how the checkModify deals with certain situations
 */
enum ModifyFlags
{
    /// Issue error messages on invalid modifications of the variable
    none,
    /// No errors are emitted for invalid modifications
    noError = 0x1,
    /// The modification occurs for a subfield of the current variable
    fieldAssign = 0x2,
}

/****************************************
 * Find the first non-comma expression.
 * Params:
 *      e = Expressions connected by commas
 * Returns:
 *      left-most non-comma expression
 */
inout(Expression) firstComma(inout Expression e)
{
    Expression ex = cast()e;
    while (ex.op == EXP.comma)
        ex = (cast(CommaExp)ex).e1;
    return cast(inout)ex;

}

/****************************************
 * Find the last non-comma expression.
 * Params:
 *      e = Expressions connected by commas
 * Returns:
 *      right-most non-comma expression
 */

inout(Expression) lastComma(inout Expression e)
{
    Expression ex = cast()e;
    while (ex.op == EXP.comma)
        ex = (cast(CommaExp)ex).e2;
    return cast(inout)ex;

}

/*****************************************
 * Determine if `this` is available by walking up the enclosing
 * scopes until a function is found.
 *
 * Params:
 *      sc = where to start looking for the enclosing function
 * Returns:
 *      Found function if it satisfies `isThis()`, otherwise `null`
 */
FuncDeclaration hasThis(Scope* sc)
{
    //printf("hasThis()\n");
    Dsymbol p = sc.parent;
    while (p && p.isTemplateMixin())
        p = p.parent;
    FuncDeclaration fdthis = p ? p.isFuncDeclaration() : null;
    //printf("fdthis = %p, '%s'\n", fdthis, fdthis ? fdthis.toChars() : "");

    // Go upwards until we find the enclosing member function
    FuncDeclaration fd = fdthis;
    while (1)
    {
        if (!fd)
        {
            return null;
        }
        if (!fd.isNested() || fd.isThis() || (fd.hasDualContext() && fd.isMember2()))
            break;

        Dsymbol parent = fd.parent;
        while (1)
        {
            if (!parent)
                return null;
            TemplateInstance ti = parent.isTemplateInstance();
            if (ti)
                parent = ti.parent;
            else
                break;
        }
        fd = parent.isFuncDeclaration();
    }

    if (!fd.isThis() && !(fd.hasDualContext() && fd.isMember2()))
    {
        return null;
    }

    assert(fd.vthis);
    return fd;

}

/***********************************
 * Determine if a `this` is needed to access `d`.
 * Params:
 *      sc = context
 *      d = declaration to check
 * Returns:
 *      true means a `this` is needed
 */
bool isNeedThisScope(Scope* sc, Declaration d)
{
    if (sc.intypeof == 1)
        return false;

    AggregateDeclaration ad = d.isThis();
    if (!ad)
        return false;
    //printf("d = %s, ad = %s\n", d.toChars(), ad.toChars());

    for (Dsymbol s = sc.parent; s; s = s.toParentLocal())
    {
        //printf("\ts = %s %s, toParent2() = %p\n", s.kind(), s.toChars(), s.toParent2());
        if (AggregateDeclaration ad2 = s.isAggregateDeclaration())
        {
            if (ad2 == ad)
                return false;
            else if (ad2.isNested())
                continue;
            else
                return true;
        }
        if (FuncDeclaration f = s.isFuncDeclaration())
        {
            if (f.isMemberLocal())
                break;
        }
    }
    return true;
}

/******************************
 * check e is exp.opDispatch!(tiargs) or not
 * It's used to switch to UFCS the semantic analysis path
 */
bool isDotOpDispatch(Expression e)
{
    if (auto dtie = e.isDotTemplateInstanceExp())
        return dtie.ti.name == Id.opDispatch;
    return false;
}

/****************************************
 * Expand tuples in-place.
 *
 * Example:
 *     When there's a call `f(10, pair: AliasSeq!(20, 30), single: 40)`, the input is:
 *         `exps =  [10, (20, 30), 40]`
 *         `names = [null, "pair", "single"]`
 *     The arrays will be modified to:
 *         `exps =  [10, 20, 30, 40]`
 *         `names = [null, "pair", null, "single"]`
 *
 * Params:
 *     exps  = array of Expressions
 *     names = optional array of names corresponding to Expressions
 */
extern (C++) void expandTuples(Expressions* exps, Identifiers* names = null)
{
    //printf("expandTuples()\n");
    if (exps is null)
        return;

    if (names)
    {
        if (exps.length != names.length)
        {
            printf("exps.length = %d, names.length = %d\n", cast(int) exps.length, cast(int) names.length);
            printf("exps = %s, names = %s\n", exps.toChars(), names.toChars());
            if (exps.length > 0)
                printf("%s\n", (*exps)[0].loc.toChars());
            assert(0);
        }
    }

    // At `index`, a tuple of length `length` is expanded. Insert corresponding nulls in `names`.
    void expandNames(size_t index, size_t length)
    {
        if (names)
        {
            if (length == 0)
            {
                names.remove(index);
                return;
            }
            foreach (i; 1 .. length)
            {
                names.insert(index + i, cast(Identifier) null);
            }
        }
    }

    for (size_t i = 0; i < exps.length; i++)
    {
        Expression arg = (*exps)[i];
        if (!arg)
            continue;

        // Look for tuple with 0 members
        if (auto e = arg.isTypeExp())
        {
            if (auto tt = e.type.toBasetype().isTypeTuple())
            {
                if (!tt.arguments || tt.arguments.length == 0)
                {
                    exps.remove(i);
                    expandNames(i, 0);
                    if (i == exps.length)
                        return;
                }
                else // Expand a TypeTuple
                {
                    exps.remove(i);
                    auto texps = new Expressions(tt.arguments.length);
                    foreach (j, a; *tt.arguments)
                        (*texps)[j] = new TypeExp(e.loc, a.type);
                    exps.insert(i, texps);
                    expandNames(i, texps.length);
                }
                i--;
                continue;
            }
        }

        // Inline expand all the tuples
        while (arg.op == EXP.tuple)
        {
            TupleExp te = cast(TupleExp)arg;
            exps.remove(i); // remove arg
            exps.insert(i, te.exps); // replace with tuple contents
            expandNames(i, te.exps.length);
            if (i == exps.length)
                return; // empty tuple, no more arguments
            (*exps)[i] = Expression.combine(te.e0, (*exps)[i]);
            arg = (*exps)[i];
        }
    }
}

/****************************************
 * Expand alias this tuples.
 */
TupleDeclaration isAliasThisTuple(Expression e)
{
    if (!e.type)
        return null;

    Type t = e.type.toBasetype();
    while (true)
    {
        if (Dsymbol s = t.toDsymbol(null))
        {
            if (auto ad = s.isAggregateDeclaration())
            {
                s = ad.aliasthis ? ad.aliasthis.sym : null;
                if (s && s.isVarDeclaration())
                {
                    TupleDeclaration td = s.isVarDeclaration().toAlias().isTupleDeclaration();
                    if (td && td.isexp)
                        return td;
                }
                if (Type att = t.aliasthisOf())
                {
                    t = att;
                    continue;
                }
            }
        }
        return null;
    }
}

int expandAliasThisTuples(Expressions* exps, size_t starti = 0)
{
    if (!exps || exps.length == 0)
        return -1;

    for (size_t u = starti; u < exps.length; u++)
    {
        Expression exp = (*exps)[u];
        if (TupleDeclaration td = exp.isAliasThisTuple)
        {
            exps.remove(u);
            size_t i;
            td.foreachVar((s)
            {
                auto d = s.isDeclaration();
                auto e = new DotVarExp(exp.loc, exp, d);
                assert(d.type);
                e.type = d.type;
                exps.insert(u + i, e);
                ++i;
            });
            version (none)
            {
                printf("expansion ->\n");
                foreach (e; exps)
                {
                    printf("\texps[%d] e = %s %s\n", i, EXPtoString(e.op), e.toChars());
                }
            }
            return cast(int)u;
        }
    }
    return -1;
}

/****************************************
 * If `s` is a function template, i.e. the only member of a template
 * and that member is a function, return that template.
 * Params:
 *      s = symbol that might be a function template
 * Returns:
 *      template for that function, otherwise null
 */
TemplateDeclaration getFuncTemplateDecl(Dsymbol s) @safe
{
    FuncDeclaration f = s.isFuncDeclaration();
    if (f && f.parent)
    {
        if (auto ti = f.parent.isTemplateInstance())
        {
            if (!ti.isTemplateMixin() && ti.tempdecl)
            {
                auto td = ti.tempdecl.isTemplateDeclaration();
                if (td.onemember && td.ident == f.ident)
                {
                    return td;
                }
            }
        }
    }
    return null;
}

/************************************************
 * If we want the value of this expression, but do not want to call
 * the destructor on it.
 */
Expression valueNoDtor(Expression e)
{
    auto ex = lastComma(e);

    if (auto ce = ex.isCallExp())
    {
        /* The struct value returned from the function is transferred
         * so do not call the destructor on it.
         * Recognize:
         *       ((S _ctmp = S.init), _ctmp).this(...)
         * and make sure the destructor is not called on _ctmp
         * BUG: if ex is a CommaExp, we should go down the right side.
         */
        if (auto dve = ce.e1.isDotVarExp())
        {
            if (dve.var.isCtorDeclaration())
            {
                // It's a constructor call
                if (auto comma = dve.e1.isCommaExp())
                {
                    if (auto ve = comma.e2.isVarExp())
                    {
                        VarDeclaration ctmp = ve.var.isVarDeclaration();
                        if (ctmp)
                        {
                            ctmp.storage_class |= STC.nodtor;
                            assert(!ce.isLvalue());
                        }
                    }
                }
            }
        }
    }
    else if (auto ve = ex.isVarExp())
    {
        auto vtmp = ve.var.isVarDeclaration();
        if (vtmp && (vtmp.storage_class & STC.rvalue))
        {
            vtmp.storage_class |= STC.nodtor;
        }
    }
    return e;
}

/*********************************************
 * If e is an instance of a struct, and that struct has a copy constructor,
 * rewrite e as:
 *    (tmp = e),tmp
 * Input:
 *      sc = just used to specify the scope of created temporary variable
 *      destinationType = the type of the object on which the copy constructor is called;
 *                        may be null if the struct defines a postblit
 */
private Expression callCpCtor(Scope* sc, Expression e, Type destinationType)
{
    if (auto ts = e.type.baseElemOf().isTypeStruct())
    {
        StructDeclaration sd = ts.sym;
        if (sd.postblit || sd.hasCopyCtor)
        {
            /* Create a variable tmp, and replace the argument e with:
             *      (tmp = e),tmp
             * and let AssignExp() handle the construction.
             * This is not the most efficient, ideally tmp would be constructed
             * directly onto the stack.
             */
            auto tmp = copyToTemp(STC.rvalue, "__copytmp", e);
            if (sd.hasCopyCtor && destinationType)
            {
                // https://issues.dlang.org/show_bug.cgi?id=22619
                // If the destination type is inout we can preserve it
                // only if inside an inout function; if we are not inside
                // an inout function, then we will preserve the type of
                // the source
                if (destinationType.hasWild && !(sc.func.storage_class & STC.wild))
                    tmp.type = e.type;
                else
                    tmp.type = destinationType;
            }
            tmp.storage_class |= STC.nodtor;
            tmp.dsymbolSemantic(sc);
            Expression de = new DeclarationExp(e.loc, tmp);
            Expression ve = new VarExp(e.loc, tmp);
            de.type = Type.tvoid;
            ve.type = e.type;
            return Expression.combine(de, ve);
        }
    }
    return e;
}

/************************************************
 * Handle the postblit call on lvalue, or the move of rvalue.
 *
 * Params:
 *   sc = the scope where the expression is encountered
 *   e = the expression the needs to be moved or copied (source)
 *   t = if the struct defines a copy constructor, the type of the destination
 *
 * Returns:
 *  The expression that copy constructs or moves the value.
 */
extern (D) Expression doCopyOrMove(Scope *sc, Expression e, Type t = null)
{
    if (auto ce = e.isCondExp())
    {
        ce.e1 = doCopyOrMove(sc, ce.e1);
        ce.e2 = doCopyOrMove(sc, ce.e2);
    }
    else
    {
        e = e.isLvalue() ? callCpCtor(sc, e, t) : valueNoDtor(e);
    }
    return e;
}

/********************************
 * Test to see if two reals are the same.
 * Regard NaN's as equivalent.
 * Regard +0 and -0 as different.
 * Params:
 *      x1 = first operand
 *      x2 = second operand
 * Returns:
 *      true if x1 is x2
 *      else false
 */
bool RealIdentical(real_t x1, real_t x2) @safe
{
    return (CTFloat.isNaN(x1) && CTFloat.isNaN(x2)) || CTFloat.isIdentical(x1, x2);
}

/************************ TypeDotIdExp ************************************/
/* Things like:
 *      int.size
 *      foo.size
 *      (foo).size
 *      cast(foo).size
 */
DotIdExp typeDotIdExp(const ref Loc loc, Type type, Identifier ident) @safe
{
    return new DotIdExp(loc, new TypeExp(loc, type), ident);
}

/***************************************************
 * Given an Expression, find the variable it really is.
 *
 * For example, `a[index]` is really `a`, and `s.f` is really `s`.
 * Params:
 *      e = Expression to look at
 * Returns:
 *      variable if there is one, null if not
 */
VarDeclaration expToVariable(Expression e)
{
    while (1)
    {
        switch (e.op)
        {
            case EXP.variable:
                return (cast(VarExp)e).var.isVarDeclaration();

            case EXP.dotVariable:
                e = (cast(DotVarExp)e).e1;
                continue;

            case EXP.index:
            {
                IndexExp ei = cast(IndexExp)e;
                e = ei.e1;
                Type ti = e.type.toBasetype();
                if (ti.ty == Tsarray)
                    continue;
                return null;
            }

            case EXP.slice:
            {
                SliceExp ei = cast(SliceExp)e;
                e = ei.e1;
                Type ti = e.type.toBasetype();
                if (ti.ty == Tsarray)
                    continue;
                return null;
            }

            case EXP.this_:
            case EXP.super_:
                return (cast(ThisExp)e).var.isVarDeclaration();

            // Temporaries for rvalues that need destruction
            // are of form: (T s = rvalue, s). For these cases
            // we can just return var declaration of `s`. However,
            // this is intentionally not calling `Expression.extractLast`
            // because at this point we cannot infer the var declaration
            // of more complex generated comma expressions such as the
            // one for the array append hook.
            case EXP.comma:
            {
                if (auto ve = e.isCommaExp().e2.isVarExp())
                    return ve.var.isVarDeclaration();

                return null;
            }
            default:
                return null;
        }
    }
}

enum OwnedBy : ubyte
{
    code,          // normal code expression in AST
    ctfe,          // value expression for CTFE
    cache,         // constant value cached for CTFE
}

alias fp_t = UnionExp function(const ref Loc loc, Type, Expression, Expression);
alias fp2_t = bool function(const ref Loc loc, EXP, Expression, Expression);


/**
 * Get the called function type from a call expression
 * Params:
 *   ce = function call expression. Must have had semantic analysis done.
 * Returns: called function type, or `null` if error / no semantic analysis done
 */
TypeFunction calledFunctionType(CallExp ce)
{
    Type t = ce.e1.type;
    if (!t)
        return null;
    t = t.toBasetype();
    if (auto tf = t.isTypeFunction())
        return tf;
    else if (auto td = t.isTypeDelegate())
        return td.nextOf().isTypeFunction();
    else
        return null;
}

FuncDeclaration isFuncAddress(Expression e, bool* hasOverloads = null) @safe
{
    if (auto ae = e.isAddrExp())
    {
        auto ae1 = ae.e1;
        if (auto ve = ae1.isVarExp())
        {
            if (hasOverloads)
                *hasOverloads = ve.hasOverloads;
            return ve.var.isFuncDeclaration();
        }
        if (auto dve = ae1.isDotVarExp())
        {
            if (hasOverloads)
                *hasOverloads = dve.hasOverloads;
            return dve.var.isFuncDeclaration();
        }
    }
    else
    {
        if (auto soe = e.isSymOffExp())
        {
            if (hasOverloads)
                *hasOverloads = soe.hasOverloads;
            return soe.var.isFuncDeclaration();
        }
        if (auto dge = e.isDelegateExp())
        {
            if (hasOverloads)
                *hasOverloads = dge.hasOverloads;
            return dge.func.isFuncDeclaration();
        }
    }
    return null;
}

/***************************************
 * Parameters:
 *      sc:     scope
 *      flag:   1: do not issue error message for invalid modification
                2: the exp is a DotVarExp and a subfield of the leftmost
                   variable is modified
 * Returns:
 *      Whether the type is modifiable
 */
extern(D) Modifiable checkModifiable(Expression exp, Scope* sc, ModifyFlags flag = ModifyFlags.none)
{
    switch(exp.op)
    {
        case EXP.variable:
            auto varExp = cast(VarExp)exp;

            //printf("VarExp::checkModifiable %s", varExp.toChars());
            assert(varExp.type);
            return varExp.var.checkModify(varExp.loc, sc, null, flag);

        case EXP.dotVariable:
            auto dotVarExp = cast(DotVarExp)exp;

            //printf("DotVarExp::checkModifiable %s %s\n", dotVarExp.toChars(), dotVarExp.type.toChars());
            if (dotVarExp.e1.op == EXP.this_)
                return dotVarExp.var.checkModify(dotVarExp.loc, sc, dotVarExp.e1, flag);

            /* https://issues.dlang.org/show_bug.cgi?id=12764
             * If inside a constructor and an expression of type `this.field.var`
             * is encountered, where `field` is a struct declaration with
             * default construction disabled, we must make sure that
             * assigning to `var` does not imply that `field` was initialized
             */
            if (sc.func && sc.func.isCtorDeclaration())
            {
                // if inside a constructor scope and e1 of this DotVarExp
                // is another DotVarExp, then check if the leftmost expression is a `this` identifier
                if (auto dve = dotVarExp.e1.isDotVarExp())
                {
                    // Iterate the chain of DotVarExp to find `this`
                    // Keep track whether access to fields was limited to union members
                    // s.t. one can initialize an entire struct inside nested unions
                    // (but not its members)
                    bool onlyUnion = true;
                    while (true)
                    {
                        auto v = dve.var.isVarDeclaration();
                        assert(v);

                        // Accessing union member?
                        auto t = v.type.isTypeStruct();
                        if (!t || !t.sym.isUnionDeclaration())
                            onlyUnion = false;

                        // Another DotVarExp left?
                        if (!dve.e1 || dve.e1.op != EXP.dotVariable)
                            break;

                        dve = cast(DotVarExp) dve.e1;
                    }

                    if (dve.e1.op == EXP.this_)
                    {
                        scope v = dve.var.isVarDeclaration();
                        /* if v is a struct member field with no initializer, no default construction
                         * and v wasn't intialized before
                         */
                        if (v && v.isField() && !v._init && !v.ctorinit)
                        {
                            if (auto ts = v.type.isTypeStruct())
                            {
                                if (ts.sym.noDefaultCtor)
                                {
                                    /* checkModify will consider that this is an initialization
                                     * of v while it is actually an assignment of a field of v
                                     */
                                    scope modifyLevel = v.checkModify(dotVarExp.loc, sc, dve.e1, !onlyUnion ? (flag | ModifyFlags.fieldAssign) : flag);
                                    if (modifyLevel == Modifiable.initialization)
                                    {
                                        // https://issues.dlang.org/show_bug.cgi?id=22118
                                        // v is a union type field that was assigned
                                        // a variable, therefore it counts as initialization
                                        if (v.ctorinit)
                                            return Modifiable.initialization;

                                        return Modifiable.yes;
                                    }
                                    return modifyLevel;
                                }
                            }
                        }
                    }
                }
            }

            //printf("\te1 = %s\n", e1.toChars());
            return dotVarExp.e1.checkModifiable(sc, flag);

        case EXP.star:
            auto ptrExp = cast(PtrExp)exp;
            if (auto se = ptrExp.e1.isSymOffExp())
            {
                return se.var.checkModify(ptrExp.loc, sc, null, flag);
            }
            else if (auto ae = ptrExp.e1.isAddrExp())
            {
                return ae.e1.checkModifiable(sc, flag);
            }
            return Modifiable.yes;

        case EXP.slice:
            auto sliceExp = cast(SliceExp)exp;

            //printf("SliceExp::checkModifiable %s\n", sliceExp.toChars());
            auto e1 = sliceExp.e1;
            if (e1.type.ty == Tsarray || (e1.op == EXP.index && e1.type.ty != Tarray) || e1.op == EXP.slice)
            {
                return e1.checkModifiable(sc, flag);
            }
            return Modifiable.yes;

        case EXP.comma:
            return (cast(CommaExp)exp).e2.checkModifiable(sc, flag);

        case EXP.index:
            auto indexExp = cast(IndexExp)exp;
            auto e1 = indexExp.e1;
            if (e1.type.ty == Tsarray ||
                e1.type.ty == Taarray ||
                (e1.op == EXP.index && e1.type.ty != Tarray) ||
                e1.op == EXP.slice)
            {
                return e1.checkModifiable(sc, flag);
            }
            return Modifiable.yes;

        case EXP.question:
            auto condExp = cast(CondExp)exp;
            if (condExp.e1.checkModifiable(sc, flag) != Modifiable.no
                && condExp.e2.checkModifiable(sc, flag) != Modifiable.no)
                return Modifiable.yes;
            return Modifiable.no;

        default:
            return exp.type ? Modifiable.yes : Modifiable.no; // default modifiable
    }
}

/**
 * Verify if the given identifier is _d_array{,set}ctor.
 *
 * Params:
 *  id = the identifier to verify
 *
 * Returns:
 *  `true` if the identifier corresponds to a construction runtime hook,
 *  `false` otherwise.
 */
bool isArrayConstruction(const Identifier id)
{
    import dmd.id : Id;

    return id == Id._d_arrayctor || id == Id._d_arraysetctor;
}

/******************************
 * Provide efficient way to implement isUnaExp(), isBinExp(), isBinAssignExp()
 */
private immutable ubyte[EXP.max + 1] exptab =
() {
    ubyte[EXP.max + 1] tab;
    with (EXPFLAGS)
    {
        foreach (i; Eunary)  { tab[i] |= unary;  }
        foreach (i; Ebinary) { tab[i] |= unary | binary; }
        foreach (i; EbinaryAssign) { tab[i] |= unary | binary | binaryAssign; }
    }
    return tab;
} ();

private enum EXPFLAGS : ubyte
{
    unary = 1,
    binary = 2,
    binaryAssign = 4,
}

private enum Eunary =
    [
        EXP.import_, EXP.assert_, EXP.throw_, EXP.dotIdentifier, EXP.dotTemplateDeclaration,
        EXP.dotVariable, EXP.dotTemplateInstance, EXP.delegate_, EXP.dotType, EXP.call,
        EXP.address, EXP.star, EXP.negate, EXP.uadd, EXP.tilde, EXP.not, EXP.delete_, EXP.cast_,
        EXP.vector, EXP.vectorArray, EXP.slice, EXP.arrayLength, EXP.array, EXP.delegatePointer,
        EXP.delegateFunctionPointer, EXP.preMinusMinus, EXP.prePlusPlus,
    ];

private enum Ebinary =
    [
        EXP.dot, EXP.comma, EXP.index, EXP.minusMinus, EXP.plusPlus, EXP.assign,
        EXP.add, EXP.min, EXP.concatenate, EXP.mul, EXP.div, EXP.mod, EXP.pow, EXP.leftShift,
        EXP.rightShift, EXP.unsignedRightShift, EXP.and, EXP.or, EXP.xor, EXP.andAnd, EXP.orOr,
        EXP.lessThan, EXP.lessOrEqual, EXP.greaterThan, EXP.greaterOrEqual,
        EXP.in_, EXP.remove, EXP.equal, EXP.notEqual, EXP.identity, EXP.notIdentity,
        EXP.question,
        EXP.construct, EXP.blit,
    ];

private enum EbinaryAssign =
    [
        EXP.addAssign, EXP.minAssign, EXP.mulAssign, EXP.divAssign, EXP.modAssign,
        EXP.andAssign, EXP.orAssign, EXP.xorAssign, EXP.powAssign,
        EXP.leftShiftAssign, EXP.rightShiftAssign, EXP.unsignedRightShiftAssign,
        EXP.concatenateAssign, EXP.concatenateElemAssign, EXP.concatenateDcharAssign,
    ];

/// Given a member of the EXP enum, get the class instance size of the corresponding Expression class.
/// Needed because the classes are `extern(C++)`
private immutable ubyte[EXP.max+1] expSize = [
    EXP.reserved: 0,
    EXP.negate: __traits(classInstanceSize, NegExp),
    EXP.cast_: __traits(classInstanceSize, CastExp),
    EXP.null_: __traits(classInstanceSize, NullExp),
    EXP.assert_: __traits(classInstanceSize, AssertExp),
    EXP.array: __traits(classInstanceSize, ArrayExp),
    EXP.call: __traits(classInstanceSize, CallExp),
    EXP.address: __traits(classInstanceSize, AddrExp),
    EXP.type: __traits(classInstanceSize, TypeExp),
    EXP.throw_: __traits(classInstanceSize, ThrowExp),
    EXP.new_: __traits(classInstanceSize, NewExp),
    EXP.delete_: __traits(classInstanceSize, DeleteExp),
    EXP.star: __traits(classInstanceSize, PtrExp),
    EXP.symbolOffset: __traits(classInstanceSize, SymOffExp),
    EXP.variable: __traits(classInstanceSize, VarExp),
    EXP.dotVariable: __traits(classInstanceSize, DotVarExp),
    EXP.dotIdentifier: __traits(classInstanceSize, DotIdExp),
    EXP.dotTemplateInstance: __traits(classInstanceSize, DotTemplateInstanceExp),
    EXP.dotType: __traits(classInstanceSize, DotTypeExp),
    EXP.slice: __traits(classInstanceSize, SliceExp),
    EXP.arrayLength: __traits(classInstanceSize, ArrayLengthExp),
    EXP.dollar: __traits(classInstanceSize, DollarExp),
    EXP.template_: __traits(classInstanceSize, TemplateExp),
    EXP.dotTemplateDeclaration: __traits(classInstanceSize, DotTemplateExp),
    EXP.declaration: __traits(classInstanceSize, DeclarationExp),
    EXP.dSymbol: __traits(classInstanceSize, DsymbolExp),
    EXP.typeid_: __traits(classInstanceSize, TypeidExp),
    EXP.uadd: __traits(classInstanceSize, UAddExp),
    EXP.remove: __traits(classInstanceSize, RemoveExp),
    EXP.newAnonymousClass: __traits(classInstanceSize, NewAnonClassExp),
    EXP.arrayLiteral: __traits(classInstanceSize, ArrayLiteralExp),
    EXP.assocArrayLiteral: __traits(classInstanceSize, AssocArrayLiteralExp),
    EXP.structLiteral: __traits(classInstanceSize, StructLiteralExp),
    EXP.classReference: __traits(classInstanceSize, ClassReferenceExp),
    EXP.thrownException: __traits(classInstanceSize, ThrownExceptionExp),
    EXP.delegatePointer: __traits(classInstanceSize, DelegatePtrExp),
    EXP.delegateFunctionPointer: __traits(classInstanceSize, DelegateFuncptrExp),
    EXP.lessThan: __traits(classInstanceSize, CmpExp),
    EXP.greaterThan: __traits(classInstanceSize, CmpExp),
    EXP.lessOrEqual: __traits(classInstanceSize, CmpExp),
    EXP.greaterOrEqual: __traits(classInstanceSize, CmpExp),
    EXP.equal: __traits(classInstanceSize, EqualExp),
    EXP.notEqual: __traits(classInstanceSize, EqualExp),
    EXP.identity: __traits(classInstanceSize, IdentityExp),
    EXP.notIdentity: __traits(classInstanceSize, IdentityExp),
    EXP.index: __traits(classInstanceSize, IndexExp),
    EXP.is_: __traits(classInstanceSize, IsExp),
    EXP.leftShift: __traits(classInstanceSize, ShlExp),
    EXP.rightShift: __traits(classInstanceSize, ShrExp),
    EXP.leftShiftAssign: __traits(classInstanceSize, ShlAssignExp),
    EXP.rightShiftAssign: __traits(classInstanceSize, ShrAssignExp),
    EXP.unsignedRightShift: __traits(classInstanceSize, UshrExp),
    EXP.unsignedRightShiftAssign: __traits(classInstanceSize, UshrAssignExp),
    EXP.concatenate: __traits(classInstanceSize, CatExp),
    EXP.concatenateAssign: __traits(classInstanceSize, CatAssignExp),
    EXP.concatenateElemAssign: __traits(classInstanceSize, CatElemAssignExp),
    EXP.concatenateDcharAssign: __traits(classInstanceSize, CatDcharAssignExp),
    EXP.add: __traits(classInstanceSize, AddExp),
    EXP.min: __traits(classInstanceSize, MinExp),
    EXP.addAssign: __traits(classInstanceSize, AddAssignExp),
    EXP.minAssign: __traits(classInstanceSize, MinAssignExp),
    EXP.mul: __traits(classInstanceSize, MulExp),
    EXP.div: __traits(classInstanceSize, DivExp),
    EXP.mod: __traits(classInstanceSize, ModExp),
    EXP.mulAssign: __traits(classInstanceSize, MulAssignExp),
    EXP.divAssign: __traits(classInstanceSize, DivAssignExp),
    EXP.modAssign: __traits(classInstanceSize, ModAssignExp),
    EXP.and: __traits(classInstanceSize, AndExp),
    EXP.or: __traits(classInstanceSize, OrExp),
    EXP.xor: __traits(classInstanceSize, XorExp),
    EXP.andAssign: __traits(classInstanceSize, AndAssignExp),
    EXP.orAssign: __traits(classInstanceSize, OrAssignExp),
    EXP.xorAssign: __traits(classInstanceSize, XorAssignExp),
    EXP.assign: __traits(classInstanceSize, AssignExp),
    EXP.not: __traits(classInstanceSize, NotExp),
    EXP.tilde: __traits(classInstanceSize, ComExp),
    EXP.plusPlus: __traits(classInstanceSize, PostExp),
    EXP.minusMinus: __traits(classInstanceSize, PostExp),
    EXP.construct: __traits(classInstanceSize, ConstructExp),
    EXP.blit: __traits(classInstanceSize, BlitExp),
    EXP.dot: __traits(classInstanceSize, DotExp),
    EXP.comma: __traits(classInstanceSize, CommaExp),
    EXP.question: __traits(classInstanceSize, CondExp),
    EXP.andAnd: __traits(classInstanceSize, LogicalExp),
    EXP.orOr: __traits(classInstanceSize, LogicalExp),
    EXP.prePlusPlus: __traits(classInstanceSize, PreExp),
    EXP.preMinusMinus: __traits(classInstanceSize, PreExp),
    EXP.identifier: __traits(classInstanceSize, IdentifierExp),
    EXP.string_: __traits(classInstanceSize, StringExp),
    EXP.this_: __traits(classInstanceSize, ThisExp),
    EXP.super_: __traits(classInstanceSize, SuperExp),
    EXP.halt: __traits(classInstanceSize, HaltExp),
    EXP.tuple: __traits(classInstanceSize, TupleExp),
    EXP.error: __traits(classInstanceSize, ErrorExp),
    EXP.void_: __traits(classInstanceSize, VoidInitExp),
    EXP.int64: __traits(classInstanceSize, IntegerExp),
    EXP.float64: __traits(classInstanceSize, RealExp),
    EXP.complex80: __traits(classInstanceSize, ComplexExp),
    EXP.import_: __traits(classInstanceSize, ImportExp),
    EXP.delegate_: __traits(classInstanceSize, DelegateExp),
    EXP.function_: __traits(classInstanceSize, FuncExp),
    EXP.mixin_: __traits(classInstanceSize, MixinExp),
    EXP.in_: __traits(classInstanceSize, InExp),
    EXP.break_: __traits(classInstanceSize, CTFEExp),
    EXP.continue_: __traits(classInstanceSize, CTFEExp),
    EXP.goto_: __traits(classInstanceSize, CTFEExp),
    EXP.scope_: __traits(classInstanceSize, ScopeExp),
    EXP.traits: __traits(classInstanceSize, TraitsExp),
    EXP.overloadSet: __traits(classInstanceSize, OverExp),
    EXP.line: __traits(classInstanceSize, LineInitExp),
    EXP.file: __traits(classInstanceSize, FileInitExp),
    EXP.fileFullPath: __traits(classInstanceSize, FileInitExp),
    EXP.moduleString: __traits(classInstanceSize, ModuleInitExp),
    EXP.functionString: __traits(classInstanceSize, FuncInitExp),
    EXP.prettyFunction: __traits(classInstanceSize, PrettyFuncInitExp),
    EXP.pow: __traits(classInstanceSize, PowExp),
    EXP.powAssign: __traits(classInstanceSize, PowAssignExp),
    EXP.vector: __traits(classInstanceSize, VectorExp),
    EXP.voidExpression: __traits(classInstanceSize, CTFEExp),
    EXP.cantExpression: __traits(classInstanceSize, CTFEExp),
    EXP.showCtfeContext: __traits(classInstanceSize, CTFEExp),
    EXP.objcClassReference: __traits(classInstanceSize, ObjcClassReferenceExp),
    EXP.vectorArray: __traits(classInstanceSize, VectorArrayExp),
    EXP.compoundLiteral: __traits(classInstanceSize, CompoundLiteralExp),
    EXP._Generic: __traits(classInstanceSize, GenericExp),
    EXP.interval: __traits(classInstanceSize, IntervalExp),
    EXP.loweredAssignExp : __traits(classInstanceSize, LoweredAssignExp),
];
