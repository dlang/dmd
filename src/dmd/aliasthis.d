/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/aliasthis.d, _aliasthis.d)
 * Documentation:  https://dlang.org/phobos/dmd_aliasthis.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/aliasthis.d
 */

module dmd.aliasthis;

import core.stdc.stdio;
import core.stdc.string;
import dmd.aggregate;
import dmd.dscope;
import dmd.dsymbol;
import dmd.expression;
import dmd.expressionsem;
import dmd.globals;
import dmd.identifier;
import dmd.mtype;
import dmd.opover;
import dmd.tokens;
import dmd.visitor;
import dmd.root.outbuffer;
import dmd.dclass;
import dmd.declaration;
import dmd.func;
import dmd.denum;
import dmd.dtemplate;
import dmd.arraytypes;
import dmd.errors;
import dmd.statement;
import dmd.statementsem;

/***********************************************************
 * alias ident this;
 */
extern (C++) final class AliasThis : Dsymbol
{
    Identifier ident;

    extern (D) this(const ref Loc loc, Identifier ident)
    {
        super(null);    // it's anonymous (no identifier)
        this.loc = loc;
        this.ident = ident;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new AliasThis(loc, ident);
    }

    override const(char)* kind() const
    {
        return "alias this";
    }

    AliasThis isAliasThis()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}


/*
 * Resolves alias this of an expression: e -> e.aliasthissym
 * Resolves alias this symbol as property or template if needed.
 * Params:
 *      sc = scope
 *      e = expression to resolve
 * Returns:
 *      Result expression with resolved alias this symbol.
 */
private Expression resolveAliasThis(Scope* sc, Expression e)
{
    AggregateDeclaration ad = isAggregate(e.type);
    if (ad && ad.aliasthis)
    {
        Loc loc = e.loc;
        Type tthis = (e.op == TOK.type ? e.type : null);
        e = e.expressionSemantic(sc);

        e = new DotIdExp(loc, e, ad.aliasthis.ident);
        e = e.expressionSemantic(sc);
        if (tthis && ad.aliasthis.needThis())
        {
            if (e.op == TOK.variable)
            {
                if (auto fd = (cast(VarExp)e).var.isFuncDeclaration())
                {
                    // https://issues.dlang.org/show_bug.cgi?id=13009
                    // Support better match for the overloaded alias this.
                    bool hasOverloads;
                    if (auto f = fd.overloadModMatch(loc, tthis, hasOverloads))
                    {
                        if (!hasOverloads)
                            fd = f;     // use exact match
                        e = new VarExp(loc, fd, hasOverloads);
                        e.type = f.type;
                        e = new CallExp(loc, e);
                        goto L1;
                    }
                }
            }
            /* non-@property function is not called inside typeof(),
             * so resolve it ahead.
             */
            {
                int save = sc.intypeof;
                sc.intypeof = 1; // bypass "need this" error check
                e = resolveProperties(sc, e);
                sc.intypeof = save;
            }
        L1:
            e = new TypeExp(loc, new TypeTypeof(loc, e));
            e = e.expressionSemantic(sc);
        }
        e = resolveProperties(sc, e);
    }
    return e;
}

/*
 * Similar resolveAliasThis, but it doesn't resolve properties and templates.
 */
private Expression resolveAliasThis2(Scope* sc, Expression e)
{
    AggregateDeclaration ad = isAggregate(e.type);
    if (ad && ad.aliasthis)
    {
        Loc loc = e.loc;
        Type tthis = (e.op == TOK.type ? e.type : null);
        e = e.expressionSemantic(sc);
        e = new DotIdExp(loc, e, ad.aliasthis.ident);
        e = e.expressionSemantic(sc);
    }
    return e;
}

/**
 * iterateAliasThis resolves alias this subtypes for `e` and applies it to `dg`.
 * dg should return true, if appropriate subtype has been found.
 * Otherwise it should returns false.
 * `dg` can return result expression through  `outexpr` parameter, and if it is not
 * null, it will be pushed to `ret` array.
 * At the first stage iterateAliasThis checks direct alias this and pushes non-null
 * `outexpr` to `ret`. If `dg` for direct "alias this" returns true then
 * `iterateAliasThis` breaks at this stage and returns true through return value and
 * returned by `dg` expression array through `ret`.
 *
 * If direct alias this did not return true iterateAliasThis
 * is recursive applied to direct alias and base classes and interfaces.
 * If one of those `iterateAliasThis` calls returns true our `iterateAliasThis` will return true.
 * Otherwise it will return false.
 *
 * The last argument is needed for internal using and should be null in user call.
 * It contains a hash table of visited types and used for avoiding of infinity recursion if
 * processed type has a circular alias this subtyping:
 * class A
 * {
 *      B b;
 *      alias b this;
 * }
 *
 * class B
 * {
 *      C c;
 *      alias c this;
 * }
 *
 * class C
 * {
 *      A a;
 *      alias a this;
 * }
 *
 * Params:
 *      sc = Scope.
 *      e = Expression to resolve subtypes.
 *      dg = Delegate, which is applies to every subtype expression of e.
 *           Takes scope, subtype expression and returns result expression through `outexpr`.
 *           Returns true if subtypes expression is applied successfully, otherwise false.
 *      ret = Result array of expressions, which returned by dg through `outexpr`.
 *      resolve_at = Does need to resolve properties and templates for alias this.
 *      gagerrors = Does need to gag errors.
 *      directtypes = Inner parameter, table of passed types. Need to avoid circle recursion.
 *                    Should be always null in caller code.
 * Returns:
 *      Result expression with resolved alias this symbol.
 */
bool iterateAliasThis(Scope* sc, Expression e, bool delegate(Scope* sc, Expression aliasexpr, ref Expression outexpr) dg,
                      ref Expression[] ret, bool resolve_at = true, bool gagerrors = false, bool[string] directtypes = null)
{
    // printf("iterateAliasThis(%s)\n", e.toChars());
    Dsymbol aliasThisSymbol = null;
    Type baseType = e.type.toBasetype();
    if (baseType.ty == Tstruct)
    {
        TypeStruct ts = cast(TypeStruct)baseType;
        aliasThisSymbol = ts.sym.aliasthis;
    }
    else if (baseType.ty == Tclass)
    {
        TypeClass ts = cast(TypeClass)baseType;
        aliasThisSymbol = ts.sym.aliasthis;
    }
    else
    {
        return false;
    }

    string deco = e.type.deco[0 .. strlen(e.type.deco)].idup;

    bool *depth_counter = deco in directtypes;
    if (!depth_counter)
    {
        directtypes[deco] = true;
    }
    else
    {
        return false; //This type has already been visited.
    }

    bool r = false;

    if (aliasThisSymbol)
    {
        uint olderrors = 0;
        if (gagerrors)
            olderrors = global.startGagging();
        Expression e1;
        if (resolve_at)
            e1 = resolveAliasThis(sc, e);
        else
            e1 = resolveAliasThis2(sc, e);

        // printf("iterateAliasThis(%s) => %s\n", e.toChars(), e1.toChars());
        if (!(gagerrors && global.endGagging(olderrors)) && e1 && e1.type && e1.type.ty != Terror)
        {
            assert(e1.type.deco);

            Expression e2 = null;
            // printf("iterateAliasThis(%s) dg(%s)\n", e.toChars(), e1.toChars());
            int success = dg(sc, e1, e2);
            r = r || success;

            if (e2)
            {
                ret ~= e2;
            }

            if (!success)
            {
                if (!resolve_at)
                {
                    if (gagerrors)
                        olderrors = global.startGagging();
                    Expression eres = resolveAliasThis(sc, e);
                    if (!(gagerrors && global.endGagging(olderrors)) && eres && eres.type && eres.type.ty != Terror)
                    {
                        e1 = eres;
                    }
                }
                r = iterateAliasThis(sc, e1, dg, ret, resolve_at, gagerrors, directtypes) || r;
            }
        }
    }

    if (r)
        return r; // direct alias this should hide inherited alias this for backward compatibility.

    if (e.type.ty == Tclass)
    {
        ClassDeclaration cd = (cast(TypeClass)e.type).sym;
        assert(cd.baseclasses);
        for (size_t i = 0; i < cd.baseclasses.dim; ++i)
        {
            ClassDeclaration bd = (*cd.baseclasses)[i].sym;
            Type bt = bd.type;
            Expression e1 = e.castTo(sc, bt);
            r = iterateAliasThis(sc, e1, dg, ret, resolve_at, gagerrors, directtypes) || r;
        }
    }

    directtypes.remove(deco);
    return r;
}

/**
 * Returns the type of the alias this symbol of the type `t`.
* If the `islvalue` is not null, `aliasThisOf` sets `*islvalue` to true
 * if alias this symbol may be resolved to a L-value (if it variable of ref-property),
 * otherwise it sets `*islvalue` to false.
 * Params:
 *      t = type.
 *      islvalue = optional parameter. Needs to return if alias this of t is a l-value.
 * Returns:
 *      Type of alias this.
 */

Type aliasThisOf(Type t, bool* islvalue = null)
{
    bool dummy;
    if (!islvalue)
        islvalue = &dummy;
    *islvalue = false;
    AggregateDeclaration ad = isAggregate(t);
    if (ad && ad.aliasthis)
    {
        Dsymbol s = ad.aliasthis;
        if (s.isAliasDeclaration())
            s = s.toAlias();
        Declaration d = s.isDeclaration();
        if (d && !d.isTupleDeclaration())
        {
            assert(d.type);
            Type t2 = d.type;
            if (d.isVarDeclaration() && d.needThis())
            {
                t2 = t2.addMod(t.mod);
                *islvalue = true; //Variable is always l-value
            }
            else if (d.isFuncDeclaration())
            {
                FuncDeclaration fd = resolveFuncCall(Loc.initial, null, d, null, t, null, 1);
                if (fd && fd.errors)
                    return Type.terror;
                if (fd && !fd.type.nextOf() && !fd.functionSemantic())
                    fd = null;
                if (fd)
                {
                    t2 = fd.type.nextOf();
                    if (!t2) // issue 14185
                        return Type.terror;
                    t2 = t2.substWildTo(t.mod == 0 ? MODFlags.mutable : t.mod);
                    if ((cast(TypeFunction)fd.type).isref)
                        *islvalue = true;
                }
                else
                    return Type.terror;
            }
            return t2;
        }
        EnumDeclaration ed = s.isEnumDeclaration();
        if (ed)
        {
            Type t2 = ed.type;
            return t2;
        }
        TemplateDeclaration td = s.isTemplateDeclaration();
        if (td)
        {
            assert(td._scope);
            FuncDeclaration fd = resolveFuncCall(Loc.initial, null, td, null, t, null, 1);
            if (fd && fd.errors)
                return Type.terror;
            if (fd && fd.functionSemantic())
            {
                Type t2 = fd.type.nextOf();
                t2 = t2.substWildTo(t.mod == 0 ? MODFlags.mutable : t.mod);
                if ((cast(TypeFunction)fd.type).isref)
                    *islvalue = true;
                return t2;
            }
            else
                return Type.terror;
        }
        //printf("%s\n", s.kind());
    }
    return null;
}

/**
 * Walks over `from` basetype tree and search types,
 * which can be converted (without alias this subtyping) to `to`.
 * If there are many ways to convert `from` to `to`, this function
 * raises an error and prints all those ways.
 * To prevent infinity loop in types with circular subtyping,
 * pattern "check a flag, lock a flag, do work is a flag wasn't locked, return flag back" is used.
 * `root_from`, `full_symbol_name`, `state` and `matchname` are needed for internal
 * using and should be null if the initial call.
 *
 * `full_symbol_name` contains the current symbol name like `TypeA.symbolX.symbolY` and needed
 * for the error message creating.
 * `state` contains current state of the lookup: no matches, there is one match,
 * there are many matches: even if we have found two matches and we are know that
 * we will raise the error, we should find remaining matches for the correct error message.
 * `matchname` contains the full name of the found alias this symbol. It is needed,
 * if we will find anothers matches and will need to raise an error.
 * Params:
 *      loc = Location
 *      from = Type which need to be converted from
 *      to = Type which need to be converted to
 *      root_from = Initial `from` type and it is needed for correct error message creating.
 *      full_symbol_name = Internal parameter, should be null in initial call.
 *                         Accumulates the name of aliasthis-ed symbol e.g. from.aliasthis1.aliasthis2
 *      state = Internal parameter, should be null in initial call.
 *              Need to return state of searching from the recursion chain.
 *      matchname = Internal parameter, should be null in initial call.
 *                  Needs to contian name of matched symbol.
 * Returns:
 *      Is `from` can be converted to `to`
 **/
MATCH implicitConvToWithAliasThis(Loc loc, Type from, Type to, Type root_from = null, OutBuffer* full_symbol_name = null,
                                  int* state = null, OutBuffer* matchname = null)
{
    //printf("implicitConvToWithAliasThis, %s . %s\n", from.toChars(), to.toChars());
    if (from.aliasthislock & AliasThisRec.RECtracing)
        return MATCH.nomatch;

    uint oldatlock = from.aliasthislock;
    from.aliasthislock |= AliasThisRec.RECtracing;
    if (!full_symbol_name)
    {
        full_symbol_name = new OutBuffer();
        full_symbol_name.writestring(from.toChars());
    }
    int st = 0; //0 - no match
                //1 - match
                //2 - many matches
    if (!state)
        state = &st;

    if (!matchname)
    {
        matchname = new OutBuffer();
    }

    if (!root_from)
    {
        root_from = from;
    }

    AggregateDeclaration ad = isAggregate(from);
    if (!ad)
        return MATCH.nomatch;
    AggregateDeclaration err_ad = isAggregate(root_from);
    assert(err_ad);

    MATCH mret = MATCH.nomatch;
    if (ad && ad.aliasthis)
    {
        bool islvalue = false;
        Type a = aliasThisOf(from, &islvalue);
        if (a)
        {
            uint tatt = a.aliasthislock;
            a.aliasthislock |= AliasThisRec.RECtracing;
            MATCH m = a.implicitConvTo(to);
            a.aliasthislock = tatt;

            if (m != MATCH.nomatch)
            {
                if (*state == 0)
                {
                    // the first match
                    *state = 1;
                    mret = m;
                    matchname.printf("%s.%s", full_symbol_name.peekString(), ad.aliasthis.toChars());
                }
                else if (*state == 1)
                {
                    // the second match
                    *state = 2;
                    err_ad.error(loc, "There are many candidates for cast %s to %s; Candidates:",
                                  root_from.toChars(), to.toChars());
                    err_ad.error(loc, " => %s", matchname.extractString());
                    matchname.printf("%s.%s", full_symbol_name.peekString(), ad.aliasthis.toChars());
                    err_ad.error(loc, " => %s", matchname.extractString());
                }
                else
                {
                    matchname.printf("%s.%s", full_symbol_name.peekString(), ad.aliasthis.toChars());
                    err_ad.error(loc, " => %s", matchname.extractString());
                }
            }
            else if (!(a.aliasthislock & AliasThisRec.RECtracing))
            {
                OutBuffer next_buff;
                next_buff.printf("%s.%s", full_symbol_name.peekString(), ad.aliasthis.toChars());

                MATCH m2 = implicitConvToWithAliasThis(loc, a, to, root_from, &next_buff, state, matchname);

                if (mret == MATCH.nomatch)
                    mret = m2;
            }
        }
    }

    if (ClassDeclaration cd = ad ? ad.isClassDeclaration() : null)
    {
        for (size_t i = 0; i < cd.baseclasses.dim; i++)
        {
            ClassDeclaration bd = (*cd.baseclasses)[i].sym;
            Type bt = (*cd.baseclasses)[i].type;
            if (!bt)
                bt = bd.type;
            if (!(bt.aliasthislock & AliasThisRec.RECtracing))
            {
                OutBuffer next_buff;
                next_buff.printf("(cast(%s)%s)", bt.toChars(), full_symbol_name.peekString());

                MATCH m2 = implicitConvToWithAliasThis(loc, bt, to, root_from, &next_buff, state, matchname);

                if (mret == MATCH.nomatch)
                    mret = m2;
            }
        }
    }
    from.aliasthislock = oldatlock;
    return mret;
}

/***
 * Returns (through `ret`) all subtypes of `t`, which can be implied via
 * alias this mechanism.
 * The `islvalues` contains the array of bool values: the one value for a
 * one `ret` value.
 * This value is true if appropriate type from `ret` refers to L-value symbol,
 * otherwise this value if false.
 * Params:
 *      t = Initial type.
 *      ret = Array of subtypes of `t`.
 *      islvalues = Contains information for each type from `ret` if it is l-value.
 */
void getAliasThisTypes(Type t, ref Type[] ret, ref bool[] islvalues)
{
    AggregateDeclaration ad = isAggregate(t);
    if (ad && ad.aliasthis)
    {
        bool islvalue = false;
        Type a = aliasThisOf(t, &islvalue);
        if (a)
        {
            bool duplicate = false;

            for (size_t j = 0; j < ret.length; ++j)
            {
                if (ret[j].equals(a))
                {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate)
            {
                ret ~= a;
                islvalues ~= islvalue;
                getAliasThisTypes(a, ret, islvalues);
            }
        }
    }

    if (ClassDeclaration cd = ad ? ad.isClassDeclaration() : null)
    {
        for (size_t i = 0; i < cd.baseclasses.dim; i++)
        {
            ClassDeclaration bd = (*cd.baseclasses)[i].sym;
            Type bt = (*cd.baseclasses)[i].type;
            if (!bt)
                bt = bd.type;
            getAliasThisTypes(bt, ret, islvalues);
        }
    }
}

/***
 * Enforces that results has only one element. Otherwise raises an error and prints
 * all results.
 * Params:
 *      results = Expression array to check.
 *      loc = Location for error.
 *      fmt = Format string for error message.
 *      args = parameters for error message.
 * Returns:
 *      results[0] if results contains only one element, ErrorExp, if results
 *      contains many elements, otherwise null.
 */
Expression enforceOneResult(T...)(Expression[] results, Loc loc, const(char)* fmt, T args)
{
    if (results.length == 1)
    {
        return results[0];
    }
    else if (results.length > 1)
    {
        .error(loc, fmt, args);
        for (size_t j = 0; j < results.length; ++j)
        {
            .errorSupplemental(loc, "%s", results[j].toChars());
        }
        return new ErrorExp();
    }
    return null;
}


struct TypeAliasThisCtx
{
    Type t;

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute a next subtype expression and check
     * if it convertable to the target type.
     * Returns true if the exactly matching has been found.
     * Otherwise returns false.
     */
    bool castTo(Scope *sc, Expression e, ref Expression outexpr)
    {
        uint oldatt = e.type.aliasthislock;
        e.type.aliasthislock |= AliasThisRec.RECtracing;
        MATCH m = e.type.implicitConvTo(t);
        e.type.aliasthislock = oldatt;

        if (m == MATCH.exact)
        {
            outexpr = e;
            return true;
        }
        else if (m != MATCH.nomatch)
        {
            outexpr = e;
            return false;
        }

        outexpr = null;
        return false;
    }

    /**
     * Should be called by iterateAliasThis.
     * Similar castTo, but gags errors and accepts any kind of match with target type.
     */
    bool findType(Scope *sc, Expression e, ref Expression outexpr)
    {
        uint errors = global.startGagging();
        bool is_val = e.checkValue();
        if (!global.endGagging(errors) && !is_val && e.type.implicitConvTo(t) != MATCH.nomatch)
        {
            outexpr = e;
            return true;
        }
        return false;
    }
}

struct FindMemberAliasThisCtx
{
    Loc loc;
    Identifier ident;
    int flags;
    Dsymbol[] candidates;

    this (Loc loc, Identifier ident, int flags)
    {
        this.loc = loc;
        this.ident = ident;
        this.flags = flags;
    }

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to an DotIdExp inside an WithStatement.
     * with(e) { ident } -> with(e) { aliasthisX.ident }
     */
    bool findMember(Scope *sc, Expression e, ref Expression outexpr)
    {
        Dsymbol s = null;
        if (e.op == TOK.import_)
        {
            s = (cast(ScopeExp)e).sds;
        }
        else if (e.op == TOK.type)
        {
            s = e.type.toDsymbol(null);
        }
        else
        {
            Type t = e.type.toBasetype();
            s = t.toDsymbol(null);
        }
        if (s)
        {
            s = s.search(loc, ident);
            if (s)
            {
                candidates ~= s;
                return true;
            }
        }

        return false;
    }
}

struct DeduceFunctionAliasThisCtx
{
    TemplateDeclaration td;
    TemplateInstance ti;
    Scope* sc;
    FuncDeclaration fd;
    Type tthis;
    Expressions* fargs;
    size_t idx;
    FuncDeclaration[] ret_fd = [];

    /**
     * Should be called by iterateAliasThis.
     * Deduce function from temeplate declaration, tries to apple alias this of parameters.
     */
    bool deduce(Scope *sc, Expression e, ref Expression outexpr)
    {
        Expressions* fargs2 = fargs.copy();
        (*fargs2)[idx] = e;
        e.aliasthislock = true;
        MATCH m = td.deduceFunctionTemplateMatch(ti, sc, fd, tthis, fargs2);
        if (m != MATCH.nomatch)
        {
            outexpr = e;
            ret_fd ~= fd;
            return true;
        }
        return false;
    }
}

struct UnaAliasThisCtx
{

    UnaExp ctx;

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to an UnaExp.
     * una(e) -> una(e.aliasthisX)
     */
    bool atUna(Scope *sc, Expression e, ref Expression outexpr)
    {
        // printf("atUna(%s); ue:  %s\n", e.toChars(), ctx.toChars());
        UnaExp ue = cast(UnaExp)ctx.copy();
        ue.aliasthislock = true;
        ue.e1 = e; //replace op(e1) with op(e1.%aliasthis%)
        Expression e2 = ue.trySemantic(sc);
        if (e2)
        {
            outexpr = e2;
            return true;
        }
        return false;
    }


    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to an UnaExp inside an UnaExp.
     * una(una(e)) -> una(una(e.aliasthisX))
     */
    bool atUnaUna(Scope *sc, Expression e, ref Expression outexpr)
    {
        UnaExp ue = cast(UnaExp)ctx.copy();
        UnaExp ae = cast(UnaExp)ue.e1.copy();
        ue.aliasthislock = true;
        ae.e1 = e;
        ue.e1 = ae;
        Expression e2 = ue.trySemantic(sc);
        if (e2)
        {
            outexpr = e2;
            return true;
        }
        return false;
    }

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to an DotIdExp inside an UnaExp.
     * una(e.ident) -> una(e.aliasthisX.ident)
     */
    bool atUnaDotId(Scope *sc, Expression e, ref Expression outexpr)
    {
        UnaExp ue = cast(UnaExp)ctx.copy();
        if (ue.e1.op != TOK.dotIdentifier)
        {
            printf("%s\n", Token.toChars(ue.e1.op));
        }
        assert(ue.e1.op == TOK.dotIdentifier || ue.e1.op == TOK.dotTemplateInstance);
        UnaExp die = cast(UnaExp)ue.e1.copy();
        ue.aliasthislock = true;
        die.e1 = e;
        Expression ey;

        if (ue.e1.op == TOK.dotIdentifier)
            ey = (cast(DotIdExp)die).semanticY(sc, 1);
        else if (ue.e1.op == TOK.dotTemplateInstance)
            ey = (cast(DotTemplateInstanceExp)die).semanticY(sc, 1);
        else
            assert(0);

        if (!ey)
            return false;
        ue.e1 = ey;
        Expression e2 = ue.trySemantic(sc);
        if (e2)
        {
            outexpr = e2;
            return true;
        }
        return false;
    }

}

struct BinAliasThisCtx
{

    BinExp ctx;
    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to an UnaExp inside a BinExp.
     * bin(una(e), x) -> bin(una(e.aliasthisX), x)
     */
    bool atBinUna(Scope *sc, Expression e, ref Expression outexpr)
    {
        BinExp e1 = cast(BinExp)ctx.copy();
        UnaExp ae1 = cast(UnaExp)e1.e1;
        ae1 = cast(UnaExp)ae1.copy();
        e1.aliasthislock = true;
        e1.e2 =  e1.e2.expressionSemantic(sc);
        if (e1.e2.op == TOK.error)
        {
            return false;
        }
        ae1.e1 = e; //replace bin(una(e1), ...) with bin(una(e1.%aliasthis%), ...)
        e1.e1 = ae1;
        ae1.aliasthislock = true;
        Expression e2 = e1.trySemantic(sc);
        if (e2)
        {
            outexpr = e2;
            return true;
        }
        return false;
    }

    /**
     * Issue 11355:
     * Should be called by iterateAliasThis.
     * It substitutes subtyped expression to an rhs of a BinExp, if it converts to the lhs type.
     * bin(x, e) -> bin(x, e.aliasthisX))
     */
    bool atBinRhsConv(Scope *sc, Expression e, ref Expression outexpr)
    {
        BinExp e1 = cast(BinExp)ctx.copy();
        e1.e2 = e.expressionSemantic(sc);
        assert(e1.e1.type);
        assert(e1.e2.type);
        uint oldatlock1 = e1.e1.type.aliasthislock;
        uint oldatlock2 = e1.e2.type.aliasthislock;
        e1.e1.type.aliasthislock |= AliasThisRec.RECtracing;
        e1.e2.type.aliasthislock |= AliasThisRec.RECtracing;
        MATCH conv = e1.e1.type.implicitConvTo(e1.e2.type);
        e1.e2.type.aliasthislock = oldatlock2;
        e1.e1.type.aliasthislock = oldatlock1;
        if (conv != MATCH.nomatch)
        {
            outexpr = e1.expressionSemantic(sc);
            return true;
        }
        return false;
    }

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to a lhs of a BinExp.
     * While it is working, it locks another term of the BinExp to prevent alias this resolving for it.
     * bin(e, x) -> bin(e.aliasthis, x)
     */
    bool atBinLhs(Scope *sc, Expression e, ref Expression outexpr)
    {
        BinExp be = cast(BinExp)ctx.copy();
        be.e1 = e;
        be.aliasthislock = true;
        uint oldatlock1 = be.e1.type.aliasthislock;
        uint oldatlock2 = be.e2.type.aliasthislock;
        e.type.aliasthislock |= AliasThisRec.RECtracing;
        be.e2.type.aliasthislock |= AliasThisRec.RECtracing;
        be.e1.aliasthislock = true;
        be.e2.aliasthislock = true;
        Expression eret = be.trySemantic(sc);
        be.e2.type.aliasthislock = oldatlock2;
        e.type.aliasthislock = oldatlock1;
        if (eret)
        {
            outexpr = eret;
            return true;
        }
        return false;
    }

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to a rhs of a BinExp.
     * While it is working, it locks another term of the BinExp to prevent alias this resolving for it.
     * bin(x, e) -> bin(x, e.aliasthis)
     */
    bool atBinRhs(Scope *sc, Expression e, ref Expression outexpr)
    {
        BinExp be = cast(BinExp)ctx.copy();
        be.e2 = e;
        be.aliasthislock = true;
        uint oldatlock1 = be.e1.type.aliasthislock;
        uint oldatlock2 = be.e2.type.aliasthislock;
        be.e1.type.aliasthislock |= AliasThisRec.RECtracing;
        be.e2.type.aliasthislock |= AliasThisRec.RECtracing;
        Expression eret = be.trySemantic(sc);
        be.e2.type.aliasthislock = oldatlock2;
        be.e1.type.aliasthislock = oldatlock1;
        if (eret)
        {
            outexpr = eret;
            return true;
        }
        return false;
    }
}


struct EmptyAliasThisCtx
{
    /**
     * Should be called by iterateAliasThis
     * It tries to cast subtyped expression to a bool value.
     */
    bool castToBool(Scope *sc, Expression e, ref Expression outexpr)
    {
        uint errors = global.startGagging();
        bool err = false;
        Type etb = e.type.toBasetype();
        uint oldatlock = etb.aliasthislock;
        etb.aliasthislock |= AliasThisRec.RECtracing;
        Expression eret = e.toBoolean(sc);
        etb.aliasthislock = oldatlock;
        if (eret && eret.op == TOK.error)
            err = true;
        if (!global.endGagging(errors) && !err)
        {
            outexpr = eret;
            return true;
        }
        return false;
    }

    /**
     * Should be called by iterateAliasThis
     * It checks if subtyped expression is a value.
     */
    bool findType(Scope *sc, Expression e, ref Expression outexpr)
    {
        uint errors = global.startGagging();
        bool is_val = e.checkValue();
        if (!global.endGagging(errors) && !is_val)
        {
            outexpr = e;
            return true;
        }
        return false;
    }

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to a switch statement.
     * switch(e) -> switch(e.aliasthis)
     */
    bool findSwitch(Scope *sc, Expression e, ref Expression outexpr)
    {
        e.aliasthislock = true;
        Statement _body = new DefaultStatement(Loc.initial, new BreakStatement(Loc.initial, null));
        SwitchStatement ss = new SwitchStatement(Loc.initial, e, _body, false);
        uint errors = global.startGagging();
        Statement ss2 = statementSemantic(ss, sc);
        if (!global.endGagging(errors))
        {
            outexpr = e;
            return true;
        }
        return false;
    }
}

struct IdentifierAliasThisCtx
{
    Identifier ident;

    /**
     * Should be called by iterateAliasThis.
     * It tries to create DotIdExp from subtyped expression.
     * una(e) -> una(e.aliasthisX)
     */
    bool findIdent(Scope *sc, Expression e, ref Expression outexpr)
    {
        Expression e1 = new DotIdExp(e.loc, e, ident);
        e1 = e1.trySemantic(sc);
        if (e1)
        {
            outexpr = e1;
            return true;
        }
        return false;
    }
}

struct FindDotIdAliasThisCtx
{
    Identifier ident;
    bool gagError;

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to an DotIdExp.
     * e.ident -> e.aliasthisX.ident
     */
    bool findDotId(Scope *sc, Expression e, ref Expression outexpr)
    {
        /* Rewrite e.ident as:
         *  e.aliasthis.ident
         */
        DotIdExp die = new DotIdExp(e.loc, e, ident);
        uint errors = gagError ? 0 : global.startGagging();
        uint oldatlock = e.type.aliasthislock;
        e.type.aliasthislock |= AliasThisRec.RECtracing;
        Expression eret = die.semanticY(sc, gagError);
        if (!gagError)
        {
            global.endGagging(errors);
            if (eret && eret.op == TOK.error)
                eret = null;
        }
        e.type.aliasthislock = oldatlock;

        if (eret)
        {
            outexpr = eret;
            return true;
        }
        return false;
    }
}

struct BinExpBothAliasThisCtx
{
    Expression[]* results;
    BinExp be;

    /**
     * Should be called by iterateAliasThis inside resolveAliasThisForBinExp.
     * It tries to substitute subtyped expression to a lhs of a BinExp and apply all rhs subtypes to it.
     * bin(x, e) -> bin(x, e.aliasthis)
     */
    bool atBinBoth(Scope *sc, Expression e, ref Expression outexpr)
    {
        BinExp be1 = cast(BinExp)be.copy();
        be1.e1 = e;
        e.aliasthislock = true;
        // e1.aliasthis op e2 => e1.aliasthis op e2.aliasthis
        int ret = iterateAliasThis(sc, be1.e2, &BinAliasThisCtx(be1).atBinRhs, *results, true, true);

        if (ret) //we don't need write to results: previous call have done it.
            return true;
        return false;
    }
};

/**
 * Search all conversions from binary expressions `be` using alias this.
 * Prefer conversions which changes only one term of `be`
 * Params:
 *      sc = Scope.
 *      be = binary expression to resolve.
 *      check_lvl = Does need to convert left term of be using alias this.
 *      check_rvl = Does need to convert right term of be using alias this.
 * Returns:
 *      Result expression if only one conversion has been found, ErrorExp if many results
 *      have been found, null if no results.
 */
Expression resolveAliasThisForBinExp(Scope *sc, BinExp be, bool check_lvl, bool check_rvl)
{
    // printf("resolveAliasThisForBinExp(%s); %d, %d\n", be.toChars(), cast(int)check_lvl, cast(int)check_rvl);
    Expression[] ret;
    if (check_lvl)
    {
        // e1 op e2 => e1.aliasthis op e2
        // don't resolve left alias this to property call
        iterateAliasThis(sc, be.e1, &BinAliasThisCtx(be).atBinLhs, ret, false, true);
    }

    Expression[] right_ret;
    if (check_rvl)
    {
        // e1 op e2 => e1 op e2.aliasthis
        iterateAliasThis(sc, be.e2, &BinAliasThisCtx(be).atBinRhs, right_ret, true, true);
    }

    if (ret.length == 1 && right_ret.length > 0)
    {
        be.deprecation("binary expression %s is resolved as %s; however there are other ways:", be.toChars(), ret[0].toChars());
        for (size_t j = 0; j < right_ret.length; ++j)
        {
            .deprecationSupplemental(be.loc, "%s", right_ret[j].toChars());
        }
        return ret[0];
    }

    ret ~= right_ret;
    if (ret.length == 1)
    {
        //if we have a one result - return it
        return ret[0];
    }
    else if (ret.length > 1)
    {
        //if we have many results - raise a error
        be.error("unable to unambiguously resolve %s; candidates:", be.toChars());
        for (size_t j = 0; j < ret.length; ++j)
        {
            .errorSupplemental(be.loc, "%s", ret[j].toChars());
        }
        return new ErrorExp();
    }

    if (check_lvl && check_rvl)
    {
        //if we haven't results try to compile e1.aliasthis op e2.aliasthis
        // e1 op e2 -> e1.aliasthis op e2.aliasthis
        // don't resolve left alias this to property call
        iterateAliasThis(sc, be.e1, &BinExpBothAliasThisCtx(&ret, be).atBinBoth, ret, false, true);
    }
    if (ret.length == 1)
    {
        //if we have a one result - return it
        return ret[0];
    }
    else if (ret.length > 1)
    {
        //if we have many results - raise a error
        be.error("unable to unambiguously resolve %s; candidates:", be.toChars());
        for (size_t j = 0; j < ret.length; ++j)
        {
            .errorSupplemental(be.loc, "%s", ret[j].toChars());
        }
        return new ErrorExp();
    }

    return null;
}

struct ForeachAliasThisCtx
{
    Scope* sc;
    bool isForeach;

    /**
     * Should be called by iterateAliasThis.
     * It tries to substitute subtyped expression to a foreach statement.
     * foreach(...; e) -> foreach(...; e.aliasthis)
     */
    bool findForeach(Scope *sc, Expression e, ref Expression outexpr)
    {
        Dsymbol sapply = null;
        uint oldatlock = e.type.aliasthislock;
        e.type.aliasthislock |= AliasThisRec.RECtracing;
        bool ret = inferForeachAggregate(sc, isForeach, e, sapply);
        e.type.aliasthislock = oldatlock;
        if (ret)
        {
            outexpr = e;
            return true;
        }
        return false;
    }
}
