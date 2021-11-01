/**
 * Compiler diagnostics.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/diagnostics.d, _diagnostics.d)
 * Documentation:  https://dlang.org/phobos/dmd_diagnostics.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/diagnostics.d
 * Todo:
 *
 * - Keep track of `VarStat` of aggregate member (expressions)
 *   needs `EVStats = EStats[VarDeclarationKey]`
 *   where, alias EStats = `Array!(ExpStat)`
 *   where, struct ExpStat { Expression exp; VarStat vs; }
 *  - and make use of `e` param in `getOrAddDefaultVarStat` and `setRecentStateOfExp`
 *  - remove `isDotVarFlag` specialhandling in `setStatAt`
 *  - recurse downwards left in handlings of DotVarExp's inside `setStatAt`
 *    and remove need for `inDotVarExpDepth`
 *  - Remove partial access of VSTATES in favour of Exp states
 *  - Use Object.equals() for `Expression`
 *
 * - Handle: nullness of if (!_data) { _data = new Data; }
 *
 * - Triggers false positive error `Error: dereferencing member of null class `f` in expressionsem.d:
 *   if (a && a.b && a.b.c) shouldn't warn
 *   if (!exp.f || exp.f.errors) return setError();
 *   if (!parentcond || parentcond.op == TOK.andAnd)
 *
 * - Line 42 in diag_access_return_member.d may mutate `pool`
 *
 * - Verify that member functions that mutate a in a.b.f() are logged.
 *
 * - Line 20 in diag_access_return_member.d
 *
 * - Exclude this when vd is found in enclosing scopes:
 *   value assigned to public parameter `readAccess` of function is unused, rename to `_` or prepend `_` to name to silence
 *
 * - Fix `f10a` in `diag_access_new.d`
 *
 * - Disable warnings in druntime/phobos to make CI pass
 *
 * - Use `@nonnull` to mimic GCC's `__attribute__((nonull))`
 *
 * - If a function's returns all take `@nonnull` expression the return value of the function can be inferred `@nonnull`
 *
 * `vstate` for `DotVarExp` make key type of `sc.vstats` an `Expression`. When a
 * class member is set to non-init and the parenting class `VSTATE.newInit` must
 * be change to `VSTATE.noninit`.
 *
 * - After `if (...) { x=...; }`, set all variables written in if-scope to maybe modified
 *
 * - In `y=x;` and `return x`, `x` leaks to `y` only if `x` is non-null (`getRecentState` is `yes`)
 *
 * - diag_access_unmodified_arg.d: Tag as maybe written in calls by value: f(C c) {}; C c; f(c);
 *
 * - diag_access_foreach_restrictions.d: Forbid modification of foreach aggregate
 *
 * - Disable some or all warnings in templates
*/

module dmd.diagnostics;

import dmd.astenums;
import dmd.root.string;
import dmd.dsymbol;
import dmd.dmodule;
import dmd.root.array : Array;
import dmd.arraytypes;
import dmd.errors;
import dmd.declaration;
import dmd.func;
import dmd.aggregate;
import dmd.dstruct;
import dmd.dclass;
import dmd.denum;
import dmd.dtemplate;
import dmd.statement;
import dmd.dimport;
import dmd.globals;
import dmd.dscope;
import dmd.visitor;
import dmd.identifier;
import dmd.init;
import dmd.expression;
import dmd.tokens;
import dmd.mtype;
import dmd.id : Id;
import dmd.asttypename : astTypeName;
// import core.stdc.stdio : printf;

static immutable g_warnUnusedParameter = true; // Unused (unread) parameters.
static immutable g_warnMutableUnmodifiedParameter = false; // Unmodified parameters being neither `const` nor `immutable.`

// version = TODO;

void checkVarStatsBeforePop(scope Scope* sc)
{
    assert(sc);

    /// Compare `a` and `b` by their location.
    static int compareByLoc(scope const VarDeclaration* a,
                            scope const VarDeclaration* b) @trusted nothrow pure
    {
        if (const diff = a.loc.linnum - b.loc.linnum)
            return diff;
        if (const diff = a.loc.charnum - b.loc.charnum)
            return diff;
        if (const diff = cast(int)a.ident.toString.length - cast(int)b.ident.toString.length)
            return diff;
        // TODO: is there a better way?:
        import core.stdc.string : strncmp;
        return strncmp(a.ident.toChars(),
                       b.ident.toChars(),
                       a.ident.toString.length);
    }

    scope Array!(VarDeclaration) vds;
    foreach (VarDeclarationKey vdk; sc.vstats.byKey)
        vds.push(vdk.key);
    vds.sort!(compareByLoc);            // sort by location

    foreach (const i, vd; vds)
    {
        if (!vd.parent ||
            !vd.parent.isFuncDeclaration)
            continue;
        checkUnusedDeclaration(vd);
        if (!vd.tryFindVarStatIn(sc.enclosing)) // lifetime of `vd` is limited to `sc`. TODO: this may be too costly to call for every variable `vd` in a scope
        {
            checkAccessAtEndOfLife(vd, sc.vstats[VarDeclarationKey(vd)]); // TODO: lookup this value in iteration above
        }
        checkUnmodifiedVarDeclaration(vd);
    }

    if (sc.func &&              // scope function
        sc.func.vthis &&        // scope function is a member function (has `this`)
        sc.func.type &&
        sc.func.type.isMutable &&     // is a mutable member function
        !sc.func.isDtorDeclaration()) // dtors cannot be const
    {
        void warn(bool anyvstats)
        {
            sc.func.loc.warning("member %s `%s` should be qualified as `const`, because it doesn't modify `this`",
                                sc.func.kind2,
                                sc.func.toChars());
        }
        if (sc.vstats)
        {
            // sc.func.vthis.loc.warning("%p type:%s isvar:%p", sc.func.vthis, astTypeName(sc.func.vthis).ptr, sc.func.vthis.isVarDeclaration);
            // foreach (kv; sc.vstats.byKeyValue)
            // {
            //     kv.key.key.loc.warning("key:%p %s type:%s", kv.key.key, kv.key.key.toChars(), astTypeName(kv.key.key).ptr);
            // }
            if (VarStat* vs = VarDeclarationKey(sc.func.vthis) in sc.vstats)
            {
                // sc.func.vthis.loc.warning("here");
                if (!vs.allWriteAccess)
                    warn(true);
            }
        }
        // else                    // `sc.func.vthis` not referenced at all
        //     warn(false);
    }

    sc.vstats.clear();
    sc.vstats = null;
}

/** Used by
    - `if` conditions (`s` is `IfStatement`) and
    - `assert` expressions (`s` is `AssertStatement`)
 */
private void scanTrueConditions(Expression cond,
                                Expression parentcond,
                                Statement s,
                                scope Scope* sc)
{
    if (auto e = cond.isLogicalExp)
    {
        if (parentcond &&
            !parentcond.isLogicalExp)
        {
            version(TODO) parentcond.warning("TODO: handle type %s", astTypeName(parentcond).ptr);
            assert(false);
        }
        auto p = parentcond ? parentcond.isLogicalExp : null; // TODO:
        if (!p || // either no parent or
            p.op == cond.op) // parentcond tree must have common operator `cond.op`
        {
            scanTrueConditions(e.e1, e, s, sc);
            scanTrueConditions(e.e2, e, s, sc);
        }
        return;
    }
    else if (auto e = cond.isCommaExp)
    {
        setAccessesInExpression(e.e1, sc, s);
        scanTrueConditions(e.e2, null, s, sc);
        return;
    }

    // try to canonicalize `cond`
    bool condNeg;
    if (auto ne = cond.isNotExp) // ne: !...
    {
        cond = ne.e1;
        condNeg = true;
    }
    else if (auto ie = cond.isIdentityExp) // ie: ... is ...
    {
        if (ie.e2.isNullExp)    // TODO: do we need to check for zero aswell?
        {
            cond = ie.e1;
            if (ie.op == TOK.identity) // ie: ... is null
                condNeg = true;
            else if (ie.op == TOK.notIdentity) // ie: ... !is null
                condNeg = false;
            else
                assert(false);
        }
    }

    if (!parentcond ||
        parentcond.op == TOK.orOr)
        // if `s` is `if (..) return ...;` enclosing scope afterwards will have
        // reverse state of variables in if-condition
        // TODO: do only if `s` is not the last statement
        // TODO: why can't we move this below `setStat`?
        if (auto ifs = s.isIfStatement)
        {
            void handle(CompoundStatement cs)
            {
                if (!cs.statements)
                    return;
                foreach (const i, Statement si; (*cs.statements))
                {
                    if (i + 1 == cs.statements.length && // last
                        si.isReturnStatement) // is a return
                    {
                        setRecentStateOfExp(cond, sc.enclosing,
                                            condNeg ? VSTATE.noninit : VSTATE.init); // reverse state
                    }
                    else if (!si.isExpStatement) // non-last is not a normal expression statement
                        return; // all bets off
                }
            }
            if (ifs.ifbody.isReturnStatement)
            {
                setRecentStateOfExp(cond, sc.enclosing,
                                    condNeg ? VSTATE.noninit : VSTATE.init); // reverse state
            }
            else if (ScopeStatement ss = ifs.ifbody.isScopeStatement)
            {
                if (CompoundStatement cs = ss.statement.isCompoundStatement)
                    handle(cs);
                else
                    version(TODO) ss.statement.loc.warning("TODO: handle type %s", astTypeName(ss.statement).ptr);
            }
            else if (CompoundStatement cs = ifs.ifbody.isCompoundStatement) // TODO: can this happen?
            {
                handle(cs);
            }
            else
                version(TODO) cond.warning("TODO: handle type %s", astTypeName(ifs.ifbody).ptr);
        }

    setAccessesInExpression(cond, sc, s);

    if (!parentcond ||
        parentcond.op == TOK.andAnd)
        null.setStatAt(cond, sc,
                       VACCESS.full,
                       VACCESS.none,
                       VACCESS.none, // no aliasing
                       condNeg ? VSTATE.init : VSTATE.noninit);
}

void setAccessesInIfStatementCondition(IfStatement s, scope Scope* sc) // TODO: pure
{
    assert(s);
    if (!doCheckUnused())
        return;
    scanTrueConditions(s.condition, null, s, sc);
    // TODO: when this scope exists and ifbody is a single ReturnStatement then reverse nullstates in s.condition
}

private VSTATE getRecentState(VarDeclaration vd, scope Scope* sc,
                              Expression e = null) /* TODO: pure nothrow */
{
    assert(vd);
    if (!vd.type.isNullable)
        return VSTATE.noninit;
    if (VarStat* vs = vd.tryFindVarStatIn(sc))
        return vs.recentState;
    if (e && e.isThisExp)   // if this expression
        return VSTATE.noninit; // assume it be to non-null until state is set (in `sc`)
    return VSTATE.unknown;
}

private bool isNullable(const scope Type type) @trusted pure nothrow @nogc
{
    assert(type);
    return (type.isTypeClass ||
            type.isTypePointer ||
            type.isTypeDArray);
}

private bool isClassOrPointer(const scope Type type) @trusted pure nothrow @nogc
{
    assert(type);
    return (type.isTypeClass ||
            type.isTypePointer);
}

/// Try to find `VarStat` of `vd` in `sc` and all its enclosing scopes transitively.
private VarStat* tryFindVarStatIn(scope VarDeclaration vd,
                                  scope Scope* sc) @safe /* TODO: pure nothrow */ @nogc
{
    assert(vd);
    assert(sc);
    for (auto scx = sc; scx; scx = scx.enclosing)
    {
        if (auto inEnclosing = VarDeclarationKey(vd) in scx.vstats)
        {
            // debug vd.loc.warning("HITT vd:%p(`%s`) scx:%p vs:%p found %d", vd, vd.toChars(), scx, inEnclosing, inEnclosing.recentState);
            return inEnclosing;
        }
    }
    return null;
}

private VarStat* tryFindOrNewVarStatIn(scope VarDeclaration vd,
                                       scope Scope* sc) @safe /* TODO: pure nothrow */
{
    if (auto vs = vd.tryFindVarStatIn(sc))
        return vs;                                          // existing
    return &(sc.vstats[VarDeclarationKey(vd)] = VarStat.init); // new. TODO: @nonnull
}

/// Add `vd` to `sc.vstats` if it's not there already.
private VarStat* getOrAddDefaultVarStat(VarDeclaration vd,
                                        scope Scope* sc,
                                        Expression e = null) /* TODO: pure nothrow */
{
    if (VarStat* vs = VarDeclarationKey(vd) in sc.vstats)
    {
        /* debug vd.loc.warning("%s: HIT vd:%p vs:%p", __FUNCTION__.ptr, vd, vs); */
        return vs;
    }
    else
    {
        /* debug vd.loc.warning("%s: MISS 1 vd:%p vstats:%p vstats.length:%llu", */
        /*                      __FUNCTION__.ptr, */
        /*                      vd, */
        /*                      sc.vstats, */
        /*                      sc.vstats.length); */
        auto vs = &(sc.vstats[VarDeclarationKey(vd)] = VarStat.init);
        assert(VarDeclarationKey(vd) in sc.vstats);
        /* debug vd.loc.warning("%s: MISS 2 vd:%p vs:%p vstats:%p vstats.length:%llu", */
                             /* __FUNCTION__.ptr, */
                             /* vd, */
                             /* vs, */
                             /* sc.vstats, */
                             /* sc.vstats.length); */
        return vs;
    }
}

private VSTATE getRecentStateOfExp(Expression e, scope Scope* sc) /* TODO: pure nothrow */
{
    if (auto e_ = e.isVarExp)
    {
        if (auto vd = e_.var.isVarDeclaration)
            return vd.getRecentState(sc); // copy from rhs
    }
    else if (auto e_ = e.isDotVarExp)
    {
        if (Declaration pd = tryLeftmostParentDeclaration(e_))
            if (VarDeclaration vd1 = pd.isVarDeclaration)
                if (vd1.getRecentState(sc) == VSTATE.newInit)
                    return VSTATE.init; // member has default value
    }
    else if (ThisExp e_ = e.isThisExp)
    {
        if (e_.var &&
            e_.loc.filename)
            return getRecentState(e_.var, sc, e_); // copy from rhs
    }
    else if (NewExp e_ = e.isNewExp)
    {
        if (TypeStruct ts = e_.newtype.isTypeStruct)
            if (!ts.sym.ctor)   // only default construction
                return VSTATE.newInit; // all fields are default initialized in new call
        if (TypeClass tc = e_.newtype.isTypeClass)
            if (!tc.sym.ctor)   // only default construction
                return VSTATE.newInit; // all fields are default initialized in new call
        return VSTATE.noninit;           // non-init value, including `non`-null for `class` `e_.newtype`
    }
    else if (e.isNullExp ||   // TODO: do we need to force constant folding here?
             e.isIntegerZero) // TODO: do we need to handle this case?
        return VSTATE.init;
    return VSTATE.unknown;
}

private VarDeclaration tryGetVarDeclarationOfVarExp(scope return Expression e,
                                                    out bool isDotVarFlag) // TODO: is there a better existing funcion in dmd?
{
    if (VarExp e_ = e.isVarExp)
        return e_.var.isVarDeclaration;
    else if (DotVarExp e_ = e.isDotVarExp)
    {
        isDotVarFlag = true;
        if (Declaration pd = tryLeftmostParentDeclaration(e_))
            return pd.isVarDeclaration;
    }
    else if (ThisExp e_ = e.isThisExp)
        return e_.var;
    else
        version(TODO) e.warning("TODO: handle type %s", astTypeName(e).ptr);
    return null;
}

private void setRecentStateOfExp(Expression e, scope Scope* sc, in VSTATE state)
{
    bool isDotVarFlag;
    VarDeclaration vd = tryGetVarDeclarationOfVarExp(e, isDotVarFlag);
    if (!vd)
        return;
    if (!(isDotVarFlag &&
          vd.type.isClassOrPointer))
    {
        VarStat* vs = getOrAddDefaultVarStat(vd, sc, e);
        if (!vs)
            return;
        if (vd.type.isNullable &&
            state == VSTATE.init && // detect unnecessary: `e = null`
            vs.recentState == VSTATE.init)
            e.warning("variable `%s` already `null`", vd.toChars());
        // e.warning("vd:%s sc:%p setting state to %d", vd.toChars(), sc, state);
        vs.recentState = state;
    }

}

void setAccessesInReturnStatement(scope ReturnStatement s, scope Scope* sc)
{
    assert(s);
    if (!doCheckUnused() || !s.exp)
        return;
    if (s.exp.type.isNullable &&
        getRecentStateOfExp(s.exp, sc) == VSTATE.init)
        s.exp.warning("returned expression is always `null`");
    setAccessesInExpression(s.exp, sc, s);
}

void setAccessesInExpStatement(ExpStatement s, scope Scope* sc)
{
    assert(s);
    assert(s.exp);
    if (!doCheckUnused() || !s.loc.filename)
        return;
    setAccessesInExpression(s.exp, sc, s);
}

// entrypoint for `DeclarationAccessVisitor`
private Expression setAccessesInExpression(Expression e, scope Scope* sc, Statement s)
{
    scope v = new DeclarationAccessVisitor(sc, s);
    e.accept(v);
    return v.result;
}

/// Logs access to declarations in the order they are access during an evaluation.
private extern (C++) final class DeclarationAccessVisitor : Visitor
{
    alias visit = Visitor.visit;

    Scope* sc;
    Expression result;
    Statement statement;        // current Statement
    ushort inDotVarExpDepth;    // TODO: remove?

    this(Scope* sc, Statement statement)
    {
        this.sc = sc;
        this.statement = statement;
    }

    private void setError()
    {
        result = ErrorExp.get();
    }

    override void visit(Expression e)
    {
        assert(e);
        version(TODO) e.warning("TODO: add `visit(T e)` member for expression `%s` of type T:`%s`",
                                e.toChars(),
                                e.type.toChars());
    }

    override void visit(TupleExp e)
    {
        assert(e);
        if (e.e0)            // TODO: is this needed?
            e.e0.accept(this);
        if (e.exps)
            foreach (exp; *e.exps)
                if (exp)
                    exp.accept(this);
    }

    override void visit(ArrayLiteralExp e)
    {
        assert(e);
        if (e.basis)            // TODO: is this needed?
            e.basis.accept(this);
        if (e.elements)
            foreach (elem; *e.elements)
                if (elem)
                    elem.accept(this);
    }

    override void visit(AssocArrayLiteralExp e)
    {
        assert(e);
        if (e.keys)
            foreach (key; *e.keys)
                if (key)
                    key.accept(this);
        if (e.values)
            foreach (value; *e.values)
                if (value)
                    value.accept(this);
    }

    override void visit(StructLiteralExp e)
    {
        assert(e);
        if (e.elements)
            foreach (elem; *e.elements)
                if (elem)
                    elem.accept(this);
    }

    override void visit(UnaExp e)
    {
        assert(e);
        if (e.e1)
            e.e1.accept(this);
    }

    override void visit(AddrExp e)
    {
        assert(e);
        if (e.e1)
            e.e1.accept(this); // overrides call to `UnaExp`. TODO: respect any pointers to variables that can leak here?
    }

    override void visit(BinExp e)
    {
        assert(e);
        if (e.e1)
            e.e1.accept(this);
        if (e.e2)
            e.e2.accept(this);
    }

    override void visit(PostExp e)
    {
        assert(e);
        if (e.e1)
            null.setStatAt(e.e1, sc, VACCESS.full, VACCESS.full, VACCESS.none);
    }

    override void visit(PreExp e)
    {
        assert(e);
        null.setStatAt(e.e1, sc, VACCESS.full, VACCESS.none, VACCESS.none); // first read
        null.setStatAt(e.e1, sc, VACCESS.none, VACCESS.full, VACCESS.none); // then write
    }

    override void visit(BinAssignExp e)
    {
        assert(e);
        // post-order evaluation
        null.setStatAt(e.e1, sc, VACCESS.full, VACCESS.none, VACCESS.none); // first read lhs
        e.e2.accept(this);      // then read rhs
        null.setStatAt(e.e1, sc, VACCESS.none, VACCESS.full, VACCESS.none, // then write lhs
                       VSTATE.noninit); // for instance, e: `x ~= ` => `x` non-null
    }

    override void visit(AssignExp e)
    {
        assert(e);
        // post-order evaluation
        visitAssignOrConstructCommon(e); // first read rhs, may leak to lhs
        null.setStatAt(e.e1, sc, VACCESS.none, VACCESS.full, VACCESS.none); // lhs
    }

    override void visit(ConstructExp e)
    {
        assert(e);
        // post-order evaluation
        visitAssignOrConstructCommon(e); // first read rhs, may leak to lhs
    }

    override void visit(BlitExp e)
    {
        assert(e);
        // post-order evaluation
        visitAssignOrConstructCommon(e); // first read rhs, may leak to lhs
    }

    private void visitAssignOrConstructCommon(AssignExp e)
    {
        assert(e);
        setRecentStateOfExp(e.e1, sc,
                            getRecentStateOfExp(e.e2, sc));
        VarDeclaration vd2;
        if (VarExp e2 = e.e2.isVarExp)
            vd2 = e2.var.isVarDeclaration;
        else if (DotVarExp e2 = e.e2.isDotVarExp)
        {
            if (Declaration pd = tryLeftmostParentDeclaration(e2))
                vd2 = pd.isVarDeclaration;
        }
        else if (ThisExp e2 = e.e2.isThisExp)
            vd2 = e2.var;
        if (vd2)
            vd2.setStatAt(e.e2, sc,
                          VACCESS.full,
                          VACCESS.none,
                          vd2.type.isNullable ? VACCESS.full : VACCESS.none);
    }

    override void visit(DefaultInitExp e)
    {
        assert(e);
        version(TODO) e.warning("TODO: handle DefaultInitExp: %s", e.toChars());
    }

    override void visit(DeclarationExp e)
    {
        assert(e);
        // TODO: copy state here
        if (auto vd = e.declaration.isVarDeclaration())
        {
            if (!vd._init)      // has no initializer
                return;
            if (auto ei = vd._init.isExpInitializer) // TODO: move into recusion?
            {
                if (ei.exp && ei.exp.loc.filename)
                    ei.exp.accept(this);
            }
            else if (auto vi = vd._init.isVoidInitializer)
            {
                // no operation
            }
            else
                version(TODO) e.warning("TODO: handle initializer: %s", vd._init.toChars());
        }
        else if (auto fd = e.declaration.isFuncDeclaration())
        {
            // skip for now: TODO: activate later when needed
        }
        else
            version(TODO) e.warning("TODO: %s: declaration:%s", __PRETTY_FUNCTION__.ptr, e.declaration.toChars());
    }

    override void visit(CondExp e)
    {
        assert(e);
        e.econd.accept(this);
        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(AssertExp e)
    {
        assert(e);
        assert(e.e1);
        assert(e.e1.type);
        if (e.e1.type.isNullable)
            // TODO: generalize to arbitrary logical expressions and merge logic into `scanTrueConditions`
            if (const rs = e.e1.getRecentStateOfExp(sc))
            {
                if (rs == VSTATE.noninit ||
                    rs == VSTATE.newInit)
                {
                    e.e1.warning("variable `%s` is unconditionally `true`, `assert` is not needed", e.e1.toChars());
                    // TODO: vd.warningSupplemental("`%` was set here", vd.toChars());
                }
                else if (rs == VSTATE.init)
                {
                    e.e1.warning("variable `%s` is unconditionally `false`", e.e1.toChars());
                    // TODO: vd.warningSupplemental("`%` was set here", vd.toChars());
                }
            }
        e.e1.accept(this);      // TODO: merge this line into the next
        scanTrueConditions(e.e1, null, statement, sc);
        if (e.msg)
            e.msg.accept(this);
    }

    override void visit(ThisExp e)
    {
        assert(e);
        if (auto vd = e.var.isVarDeclaration())
            visitExpOfVarDeclaration(e, vd, false, statement);
        else
            version(TODO) e.warning("TODO: %s: var:`%s`", __PRETTY_FUNCTION__.ptr, e.var.toChars());
    }

    override void visit(NewExp e)
    {
        assert(e);
        if (e.thisexp)
            e.thisexp.accept(this);
        if (e.argprefix)
            e.argprefix.accept(this);
        if (e.newargs)
            foreach (newarg; *e.newargs)
                if (newarg)
                    newarg.accept(this);
        if (e.arguments)
            foreach (argument; *e.arguments)
                if (argument)
                    argument.accept(this);
    }

    override void visit(NewAnonClassExp e)
    {
        assert(e);
        if (e.thisexp)
            e.thisexp.accept(this);
        if (e.newargs)
            foreach (newarg; *e.newargs)
                if (newarg)
                    newarg.accept(this);
        if (e.arguments)
            foreach (argument; *e.arguments)
                if (argument)
                    argument.accept(this);
    }

    override void visit(IndexExp e) // e1[e2]
    {
        assert(e);
        VACCESS readAccess = VACCESS.partialOrFullMaybe;
        if (e.e1.type.isTypeSArray)
            readAccess = e.e2.isIntegerZero() ? VACCESS.full : VACCESS.partial;
        null.setStatAt(e.e1,
                       sc,
                       readAccess,
                       VACCESS.none,
                       VACCESS.none);
        e.e2.accept(this);
    }

    override void visit(SliceExp e) // e1[lwr, upr]
    {
        assert(e);
        const isFull = ((e.e1.type.isTypeSArray ||
                         e.e1.type.isTypeDArray) &&
                        (e.lwr is null || e.lwr.isIntegerZero) &&
                        (e.upr is null || e.upr.isDollarExp));
        null.setStatAt(e.e1, // becomes a reference
                       sc,
                       isFull ? VACCESS.full : VACCESS.partial,
                       VACCESS.none,
                       isFull ? VACCESS.full : VACCESS.partial);
        if (e.lwr)
            e.lwr.accept(this);
        if (e.upr)
            e.upr.accept(this);
    }

    override void visit(SymOffExp e) // : SymbolExp
    {
        assert(e);
        if (auto vd = e.var.isVarDeclaration())
            visitExpOfVarDeclaration(e, vd, true, statement);
        else
            version(TODO) e.warning("TODO: %s: var:`%s`", __PRETTY_FUNCTION__.ptr, e.var.toChars());
    }

    override void visit(VarExp e) // : SymbolExp
    {
        assert(e);
        if (auto d = e.var.isVarDeclaration())
        {
            if (inDotVarExpDepth &&
                d.type.isNullable)
            {
                const state = d.getRecentState(sc);
                if (state == VSTATE.unknown)
                    e.warning("dereferencing maybe null `%s`", d.toChars());
                else if (state == VSTATE.init)
                    e.warning("dereferencing null `%s`", d.toChars()); // TODO: error
            }
            visitExpOfVarDeclaration(e, d, false, statement);
        }
        else if (auto d = e.var.isFuncDeclaration())
        {
            // TODO: mark as called at `e`
        }
        else
            version(TODO) e.warning("TODO: %s: var:`%s`", __PRETTY_FUNCTION__.ptr, e.var.toChars());
    }

    override void visit(DotVarExp e)
    {
        assert(e);
        if (auto d = e.var.isVarDeclaration())
        {
            if (inDotVarExpDepth &&
                d.type.isNullable)
            {
                if (d.getRecentState(sc) == VSTATE.unknown)
                    e.warning("dereferencing maybe null `%s`", d.toChars());
                else if (d.getRecentState(sc) == VSTATE.init)
                    e.error("dereferencing null `%s`", d.toChars());
            }
            visitExpOfVarDeclaration(e, d, false, statement);
        }
        else
            version(TODO) e.warning("TODO: %s: handle `%s`", __PRETTY_FUNCTION__.ptr, e.var.toChars());

        assert(inDotVarExpDepth != inDotVarExpDepth.max);
        inDotVarExpDepth++;

        e.e1.accept(this);      // ok to recurse `e.e1`

        assert(inDotVarExpDepth >= 1);
        inDotVarExpDepth--;
    }

    private void visitExpOfVarDeclaration(Expression e,
                                          VarDeclaration d,
                                          bool inSymOffExp,
                                          Statement s)
    {
        if (d.storage_class & STC.field)
            return;             // TODO: special handle many cases for fields
        if (s.isReturnStatement) // TODO: handle `e` not being a direct argument to `ReturnStatement`
        {
            // TODO: this code is duplicated from `visit(ReturnStatement rs)`:
            if (sc.parent)
            {
                if (FuncDeclaration fd = sc.parent.isFuncDeclaration())
                {
                    if (fd.fes)
                        fd = fd.fes.func; // fd is now function enclosing foreach
                    TypeFunction tf = cast(TypeFunction)fd.type;
                    assert(tf.ty == Tfunction);
                    Type tret = tf.next;
                    const Type tbret = tret ? tret.toBasetype() : null;
                    if (tbret.isNullable ||
                        tf.isref) // returned by reference
                    {
                        d.setStatAt(e, sc,
                                    VACCESS.fullMaybe, // maybe full read
                                    tbret.isMutable ? VACCESS.fullMaybe : VACCESS.none, // maybe full write if mutable
                                    VACCESS.full); // aliased
                        return;
                    }
                }
            }
        }
        if (inSymOffExp)
            d.setStatAt(e, sc,
                        VACCESS.none, // no read (yet)
                        VACCESS.none,  // no write (yet)
                        VACCESS.full);
        else
            d.setStatAt(e, sc,
                        VACCESS.full, // full read
                        VACCESS.none,  // no write
                        VACCESS.none); // no escape
        // if (VarStat* vs = VarDeclarationKey(d) in sc.vstats)
        //     e.warning("set e:%s %d", e.toChars(), vs.readAccess);
    }

    override void visit(DelegateExp e)
    {
        assert(e);
        version(TODO) e.warning("%s:: TODO: handle: e:%s, c.type:%s",
                                __PRETTY_FUNCTION__.ptr,
                                e.toChars(),
                                e.type ? e.type.toChars() : null);
    }

    override void visit(CallExp e)
    {
        assert(e);
        FuncDeclaration fd = e.f;
        if (fd)
        {
            assert(fd.type);
            // TODO: support recursion on `e.e1`
            if (DotVarExp dv1 = e.e1.isDotVarExp) // member call
            {
                if (VarExp v1 = dv1.e1.isVarExp) // the `this` variable in the call
                {
                    if (VarDeclaration d1 = v1.var.isVarDeclaration) // `d1` is "S", given `e` is "S.MEMBER()"
                        setStatInMemberCallExp(fd, d1, e);
                }
                else if (ThisExp v1 = dv1.e1.isThisExp) // the `this` variable in the call
                {
                    if (VarDeclaration d1 = v1.var) // `d1` is "S", given `e` is "S.MEMBER()"
                        setStatInMemberCallExp(fd, d1, e);
                }
                else
                    version(TODO) arg.warning("TODO: handle type %s", astTypeName(dv.e1).ptr);
            }
        }
        if (e.arguments)
            visitCallExpArguments(fd, e.arguments);
    }

    private void visitCallExpArguments(scope FuncDeclaration fd,
                                       scope Expressions* arguments)
    {
        assert(arguments);
        // if (!fd)            // TODO: handle delegates
        //     version(TODO) e.warning("e:%s, c.type:%s", e.toChars(),
        //                             e.type ? e.type.toChars() : null);
        const Parameters* parameters = fd ? getParametersMaybe(fd) : null;
        foreach (const i, arg; *arguments)
        {
            if (!arg)
                continue;   // TODO: is `arg` a defaulted argument?
            // arg.warning("i:%llu arg:%p type:%s", i, arg, astTypeName(arg).ptr);
            arg.accept(this);
            if (!parameters)
                continue;
            const i_ = (i >= parameters.length) ? parameters.length - 1 : i; // truncate variadic index
            setUsageInParameterArgument((*parameters)[i_], arg, sc);
        }
    }

    private void setStatInMemberCallExp(scope FuncDeclaration fd,
                                        scope VarDeclaration vd,
                                        scope Expression e)
    {
        VACCESS aliasedAccess;
        if (fd.isSafe)         // no need for `&& global.params.vsafe` here
        {
            if (fd.type.isTypeStruct) // this pointer for structs
                aliasedAccess = VACCESS.none; // cannot escape in @safe functions
            else
                aliasedAccess = ((// ((d1.type &&
                                    //   !d1.type.toBasetype.isTypeClass) || // either not a class
                                    //  (d1.storage_class & STC.scope_) != 0) &&
                                    fd.isScope) ?
                                VACCESS.none :
                                VACCESS.full);
        }
        else
            aliasedAccess = VACCESS.fullMaybe; // all bets are off
        vd.setStatAt(e, sc, // tag  `this`
                     VACCESS.partialOrFullMaybe, // maybe [partial|full] read
                     fd.type.isMutable ? VACCESS.partialOrFullMaybe : VACCESS.none, // maybe [partial|full] write if mutable
                     aliasedAccess);
    }

    // ignore these as they contain no references to `VarDeclaration`s
    override void visit(FuncExp e) {}
    override void visit(ErrorExp e) {}
    override void visit(IntegerExp e) {}
    override void visit(RealExp e) {}
    override void visit(ComplexExp e) {}
    override void visit(NullExp e) {}
    override void visit(StringExp e) {}
    override void visit(IdentifierExp e) {}
    override void visit(DollarExp e) {}
    override void visit(DsymbolExp e) {}
    override void visit(ScopeExp e) {}
    override void visit(TemplateExp e) {}
    override void visit(TypeidExp e) {}
    override void visit(TraitsExp e) {}
    override void visit(HaltExp e) {}
    override void visit(IsExp e) {}
    override void visit(MixinExp e) {}
    override void visit(ImportExp e) {}
    override void visit(DotIdExp e) {}
    override void visit(DotTemplateExp e) {}
    override void visit(DotTemplateInstanceExp e) {}
    override void visit(DotTypeExp e) {}
}

inout(Parameters)* getParametersMaybe(inout FuncDeclaration fd) @trusted
{
    if (!fd.type)
        return null;
    const TypeFunction tf = fd.type.isTypeFunction;
    if (!tf)
        return null;
    return cast(typeof(return))(tf.parameterList.parameters);
}

private bool isIntegerZero(Expression e) /* TODO: pure nothrow */ @nogc
{
    if (!e)
        return false;
    if (auto ie = e.isIntegerExp)
        return ie.getInteger == 0;
    return false;
}

private Declaration tryLeftmostParentDeclaration(DotVarExp e)
{
    while (true)
    {
        if (VarExp e1 = e.e1.isVarExp)
            return e1.var;
        else if (ThisExp e1 = e.e1.isThisExp)
            return e1.var;
        else if (DotVarExp e1 = e.e1.isDotVarExp)
        {
            e = e1;             // step left
            continue;
        }
        else
        {
            version(TODO) e.warning("TODO: e:%s: handle e1 of type %s", e.toChars(), astTypeName(e.e1).ptr);
            return null;
        }
    }
}

void setUsageInParameterArgument(const Parameter p,
                                 Expression arg,
                                 Scope* sc)
{
    assert(p);
    assert(arg);
    if (!doCheckUnused())
        return;

    // try getting `var` and set `tookAddrOf` for `&x` expressions
    Declaration var;
    bool tookAddrOf;
    if (VarExp ve = arg.isVarExp)
        var = ve.var;
    else if (DotVarExp de = arg.isDotVarExp)
        var = tryLeftmostParentDeclaration(de);
    else if (ThisExp ve = arg.isThisExp)
        var = ve.var;
    else if (SymOffExp se = arg.isSymOffExp) // of the form `&e`
    {
        tookAddrOf = true;
        var = se.var;
    }
    else
        version(TODO) arg.warning("TODO: handle arg of type %s", astTypeName(arg).ptr);

    if (var)
    {
        if (/*FuncDeclaration fd = */var.isFuncDeclaration)
        {
            // TODO: use `fd`
        }
        else if (auto vd = var.isVarDeclaration) // TODO: check for `isFuncDeclaration`
        {
            if (p.storageClass & STC.ref_) // `arg` is passed as `ref`
            {
                vd.setStatAt(arg, sc,
                             VACCESS.fullMaybe, // maybe read from inside function
                             p.type.isMutable ? VACCESS.fullMaybe : VACCESS.none,
                             VACCESS.none, // no escape,
                    ); // mutability is in `p.type`, not `p`
            }
            else if (p.storageClass & STC.in_) // `arg` is passed as `in`
            {
                vd.setStatAt(arg, sc,
                             VACCESS.fullMaybe, // TODO: only maybe if `in` lowers to ref with `-preview=in`
                             VACCESS.none,      // cannot be written
                             VACCESS.none, // no escape,
                    );
            }
            else if (p.storageClass & STC.out_) // `arg` is passed as `out`
            {
                vd.setStatAt(arg, sc,
                             VACCESS.none,
                             VACCESS.full,
                             VACCESS.none, // no escape,
                    ); // always zero-written before call and maybe written inside function
            }
            else if (vd.type.isTypeClass) // TODO: use p.type instead of vd.type?
            {
                vd.setStatAt(arg, sc,
                             VACCESS.fullMaybe, // maybe read
                             p.type.isMutable ? VACCESS.fullMaybe : VACCESS.none,
                             VACCESS.none, // no escape,
                    ); // maybe written if passes as mutable
            }
            else if (auto tp = p.type.isTypePointer)
            {
                vd.setStatAt(arg, sc,
                             VACCESS.fullMaybe, // maybe read
                             tp.next.isMutable ? VACCESS.fullMaybe : VACCESS.none,
                             VACCESS.none, // no escape,
                    ); // maybe written if passes as mutable
            }
            else if (tookAddrOf) // a pointer to `vd` is being passed
            {
                vd.setStatAt(arg, sc,
                             VACCESS.fullMaybe, // maybe read
                             p.type.isMutable ? VACCESS.fullMaybe : VACCESS.none,
                             VACCESS.none, // no escape,
                    ); // maybe written if passes as mutable
            }
            else // value
            {
                vd.setStatAt(arg, sc,
                             VACCESS.full, // always read at call site
                             VACCESS.none,
                             VACCESS.none, // no escape
                    ); // no write at call site
            }
        }
        else
        {
            arg.warning("handle Declaration of type:%s and kind:%s", var.type.toChars(), var.kind());
        }
    }
}

/********************************************
 * Set `VarStat` of `vd` at `e`.
 *
 * If `vd` is `null` it is searched for inside `e`.
 *
 * e += ... is `readAccess == VACCESS.full` and `writeAccess == VACCESS.full`
 * cannot be called at `expressionsem.d` because cannot distinguish between
 * assignment statements and initalizing assignments
 */
private void setStatAt(VarDeclaration vd,
                       Expression e,
                       Scope* sc,    // current scope
                       VACCESS readAccess,
                       VACCESS writeAccess,
                       VACCESS aliasedAccess,
                       VSTATE state = VSTATE.ignore)
{
    assert(e);
    if (!(e.isVarExp ||
          e.isDotVarExp ||
          e.isThisExp ||
          e.isSymOffExp ||
          e.isSliceExp ||
          e.isCallExp ||
          e.isLvalue))
    {
        version(TODO) e.warning("TODO: unknown type %s of expression `%s`", astTypeName(e).ptr, e.toChars());
    }

    bool isDotVarFlag;
    if (!vd)
        vd = tryGetVarDeclarationOfVarExp(e, isDotVarFlag);
    if (!vd)
    {
        version(TODO) e.warning("TODO: could get VarDeclaration from `%s`", astTypeName(e).ptr);
        return;
    }

    if (isDotVarFlag)
    {
        // TODO: remove later
        if (readAccess == VACCESS.full)
            readAccess = VACCESS.partial;
        if (readAccess == VACCESS.fullMaybe)
            readAccess = VACCESS.partialOrFullMaybe;
        if (writeAccess == VACCESS.full)
            writeAccess = VACCESS.partial;
        if (writeAccess == VACCESS.fullMaybe)
            writeAccess = VACCESS.partialOrFullMaybe;
        if (aliasedAccess == VACCESS.full)
            aliasedAccess = VACCESS.partial;
        if (aliasedAccess == VACCESS.fullMaybe)
            aliasedAccess = VACCESS.partialOrFullMaybe;
    }

    if (!doCheckUnused() ||
        (vd.storage_class & STC.foreach_) || // ignore written varable in foreach
        e.loc.filename is null) // skip generated expressions with no location
        return;

    vd.tagAsReferenced();      // TODO: probably not needed. try removing

    // TODO: merge with return condition above
    if (vd.ident.isAnonymous ||
        isLikelyGenerated(vd.ident)) // ignore foreach identifier matching regexp `__(key|limit)[0-9]+`,
        return;

    const isField = (vd.storage_class & STC.field) != 0;
    const isShared = (vd.storage_class & (STC.shared_ | STC.gshared)) != 0;

    // last
    if (!isField && // no use tracking access order of fields across members
        !isShared)  // nor globals
    {
        VarStat* vs = vd.tryFindOrNewVarStatIn(sc);
        assert(vs);             // TODO: not needed

        if (vs.recentExp is null ||     // first reference
            vs.recentExp is e)          // same reference
        {
            vs.recentReadAccess = VACCESS.none;
            vs.recentWriteAccess = VACCESS.none;
            vs.recentAliasedAccess = VACCESS.none;
        }
        else /*if (vs.recentExp !is e)*/ // other reference
        {
            if (readAccess == VACCESS.none &&
                writeAccess == VACCESS.full &&
                vs.recentReadAccess == VACCESS.none &&
                vs.recentWriteAccess == VACCESS.full)
            {
                vs.recentExp.warning("value assigned to `%s` is never used",
                                     vs.recentExp.toChars());
                e.loc.warningSupplemental("overwritten here");
            }
            vs.recentReadAccess = VACCESS.none;
            vs.recentWriteAccess = VACCESS.none;
            vs.recentAliasedAccess = VACCESS.none;
        }
        vs.recentExp = e;

        if (readAccess != VACCESS.none)
        {
            if (vs.recentReadAccess != VACCESS.full)
                vs.recentReadAccess = readAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
        }
        if (writeAccess != VACCESS.none)
        {
            if (vs.recentWriteAccess != VACCESS.full)
                vs.recentWriteAccess = writeAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
        }
        if (aliasedAccess != VACCESS.none)
        {
            if (vs.recentAliasedAccess != VACCESS.full)
                vs.recentAliasedAccess = aliasedAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
        }
        if (state != VSTATE.ignore)
            vs.recentState = state;

        if (readAccess != VACCESS.none &&
            vs.allReadAccess != VACCESS.full)
            vs.allReadAccess = readAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
        if (writeAccess != VACCESS.none &&
            vs.allWriteAccess != VACCESS.full)
            vs.allWriteAccess = writeAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
        if (aliasedAccess != VACCESS.none &&
            vs.allAliasedAccess != VACCESS.full)
            vs.allAliasedAccess = aliasedAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
    }

    // all
    // for fields (STC.field) order is not imported so ok to track here
    // TODO: functionize to vd.setAllVarStat()
    if (readAccess != VACCESS.none &&
        vd.allVarStat.readAccess != VACCESS.full)
        vd.allVarStat.readAccess = readAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
    if (writeAccess != VACCESS.none &&
        vd.allVarStat.writeAccess != VACCESS.full)
        vd.allVarStat.writeAccess = writeAccess == VACCESS.fullMaybe ? VACCESS.fullMaybe : VACCESS.full;
}

private bool isLikelyGenerated(const Identifier ident)
{
    assert(ident);
    import dmd.root.string : startsWith;
    // TODO: is null parent or null location more reliable?
    return ident.toChars().startsWith("__");
}

void printSymbolAccessStats(const ref Modules modules)
{
    if (global.params.warnings == DiagnosticReporting.off ||
        !doCheckUnused())
        return;

    static void checkModule(const Module m)
    {
        scope v = new DiagnosticsVisitor();
        (cast()m).accept(v);
    }

    foreach (m; modules)
        checkModule(m);
}

extern(C++) class DiagnosticsVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = SemanticTimeTransitiveVisitor.visit;

    override void visit(Dsymbol sym)
    {
        checkUnusedDsymbol(sym);
        super.visit(sym);
    }

    override void visit(AliasDeclaration ad)
    {
        checkUnusedAliasDeclaration(ad);
        super.visit(ad);
    }

    override void visit(VarDeclaration vd)
    {
        /* TODO: when moving this to `semantic3.d` check that `VarDeclaration`'s
         * doesn't already match function parameters
         */
        checkUnusedDeclaration(vd);
        checkUnmodifiedVarDeclaration(vd);
        super.visitVarDecl(vd); // TODO: needed?
    }

    override void visit(FuncDeclaration fd)
    {
        diagnoseSelfRecursion(fd);
        checkUnusedFuncDeclaration(fd);
        super.visit(fd);
    }

    override void visit(IfStatement ie)
    {
        checkUnusedIfStatement(ie);
        super.visit(ie);
    }

    override void visit(FuncAliasDeclaration fa)
    {
        checkUnusedFuncAliasDeclaration(fa);
        super.visit(fa);
    }

    override void visit(EnumDeclaration ed)
    {
        checkUnusedEnumDeclaration(ed);
        super.visit(ed);
    }

    override void visit(EnumMember em)
    {
        checkUnusedEnumMember(em);
        super.visit(em);
    }

    override void visit(StructDeclaration sd)
    {
        checkUnusedStructDeclaration(sd);
        super.visit(sd);
    }

    override void visit(ClassDeclaration cd)
    {
        checkUnusedClassDeclaration(cd);
        super.visit(cd);
    }

    override void visit(InterfaceDeclaration id)
    {
        checkUnusedInterfaceDeclaration(id);
        super.visit(id);
    }

    override void visit(TemplateDeclaration td)
    {
        checkUnusedTemplateDeclaration(td);
        super.visit(td);
    }

    override void visit(TemplateParameter tp)
    {
        checkUnusedTemplateParameter(tp);
        super.visit(tp);
    }

    override void visit(LabelDsymbol ls)
    {
        checkUnusedLabelDsymbol(ls);
        super.visit(ls);
    }

    override void visit(LabelStatement ls)
    {
        checkUnusedLabelStatement(ls);
        super.visit(ls);
    }

    override void visit(Import im)
    {
        checkUnusedImport(im);
        super.visit(im);
    }
}

private void checkUnusedDsymbol(Dsymbol sym)
{
    assert(sym);
    if (sym.isReferenced)
        return;
    // TODO: activate thie to find more cases
    // sym.loc.warning("unused symbol `%s`", sym.toChars());
}

private void checkUnusedAliasDeclaration(AliasDeclaration ad)
{
    assert(ad);
    if (isReferencedDeclaration(ad))
        return;
    if (ad._import &&
        ad.protection.kind.shouldWarnUnunsed())
        ad.loc.warning("unused %sly imported alias `%s`",
                       ad.protection.kind.toChars(),
                       ad.toChars());
    else
        checkUnusedDeclaration(ad);
}

private void checkUnusedDeclaration(const Declaration dn)
{
    assert(dn);
    if (dn.ident == Id.__xpostblit || // skip generated postblit
        isReferencedDeclaration(dn) ||
        isIgnored(dn.ident))
        return;

    // TODO: branch on `__gshared`?
    // TODO: branch on dn.isImportedSymbol()?

    if (!dn.parent)
    {
        // hide because we're most likely not interested in messages such as:
        // `Warning: unused public variable `typeid(const(uint))` of no parent`
        version(none) dn.loc.warning("unused %s %s `%s` of no parent",
                                     dn.protection.kind.toChars(), dn.kind2(), dn.toChars());
        return;
    }

    if (dn.parent.isFuncDeclaration())
    {
        // NOTE: `dn.parent.isFuncDeclaration().fes` (foreach symbol) is `null` here
        // `dn` is always public in scope of function `dn.parent`
        const inForeach = dn.storage_class & STC.foreach_ ? true : false;
        dn.loc.warning("unused %s%s `%s` of %s, %srename to `_` or prepend `_` to name to silence",
                       (inForeach ? "" : "local ").ptr,
                       dn.kind2(),
                       dn.toChars(),
                       dn.parentKind().ptr,
                       (inForeach ? "" : "remove, ").ptr);
    }
    else if (const pad = dn.parent.isAggregateDeclaration())
    {
        // TODO: instead capture `pad.stc.extern_` before/during `pad.semantic()`
        // const pad_extern = (pad.storage_class & STC.extern_) ? 1 : 0;
        if ((pad._scope && pad._scope.stc == STC.extern_ ||
             pad.classKind == ClassKind.cpp ||
             pad.classKind == ClassKind.objc))
            return;
        const padUU = pad.protection.kind.shouldWarnUnunsed();
        const dnUU = dn.protection.kind.shouldWarnUnunsed();
        if (padUU && dnUU)
            dn.loc.warning("unused %s %s `%s` of %s %s, rename to `_` or prepend `_` to name to silence",
                           dn.protection.kind.toChars(), dn.kind2(), dn.toChars(),
                           pad.protection.kind.toChars(), pad.kind());
        else if (padUU)
            dn.loc.warning("unused %s %s `%s` of %s %s, rename to `_` or prepend `_` to name to silence",
                           dn.protection.kind.toChars(), dn.kind2(), dn.toChars(),
                           pad.protection.kind.toChars(), pad.kind());
        else if (dnUU)
            dn.loc.warning("unused %s %s `%s` of %s %s, rename to `_` or prepend `_` to name to silence",
                           dn.protection.kind.toChars(), dn.kind2(), dn.toChars(),
                           pad.protection.kind.toChars(), pad.kind());
    }
    else if (dn.parent.isModule())
    {
        if (dn.protection.kind == Visibility.Kind.private_ ||
            dn.protection.kind == Visibility.Kind.package_)
            dn.loc.warning("unused %s %s `%s` of %s `%s`, rename to `_` or prepend `_` to name to silence",
                           dn.protection.kind.toChars(), dn.kind2(), dn.toChars(),
                           dn.parent.kind(), dn.parent.toChars());
    }
    else
        dn.loc.warning("unused %s %s `%s` of %s `%s`, rename to `_` or prepend `_` to name to silence",
                       dn.protection.kind.toChars(), dn.kind2(), dn.toChars(),
                       dn.parent.kind(), dn.parent.toChars());
}

private void checkUnmodifiedVarDeclaration(const VarDeclaration vd)
{
    assert(vd);

    if ((vd.storage_class & (STC.manifest | STC.const_ | STC.immutable_)) ||
        (vd.protection.kind != Visibility.Kind.private_ && // private
         vd.storage_class & STC.field) ||            // field
        vd.isRef ||
        isUnreferencedVarDeclaration(vd) ||
        vd.ident == Id.__xpostblit || // skip generated postblit
        isIgnored(vd.ident))
        return;

    version(none)
    if (!vd.allVarStat.writeAccess) // TODO: also warn about `package_` declarations if compiling package
    {
        // vd.loc.warning("%p: `%s`", vd, vd.toChars());
        // unfortunately `vd._scope` is `null` here
        vd.loc.warning("unmodified %s %s `%s` of %s should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence",
                       vd.protection.kind.toChars(),
                       vd.kind2(),
                       vd.toChars(),
                       vd.parentKind().ptr);
    }

    version(none)               // TODO: activate
    if (vd.allVarStat.writeAccess &&
        !vd.allVarStat.readAccess)
        vd.loc.warning("unused modified %s %s `%s` of %s, rename to `_` or prepend `_` to name to silence",
                       vd.protection.kind.toChars(),
                       vd.kind2(),
                       vd.toChars(),
                       vd.parentKind().ptr);

    // TODO: move this to place where `vd` goes out of scope
    version(none)
    if (vd.lastVarStat.writeAccess &&
        !vd.lastVarStat.aliasedAccess)
        vd.recentExp.warning("value assigned to %s %s `%s` of %s is unused, rename to `_` or prepend `_` to name to silence",
                             vd.protection.kind.toChars(),
                             vd.kind2(),
                             vd.toChars(),
                             vd.parentKind().ptr);
}

private void warningVarStat(const VarDeclaration vd,
                            const VarStat vs,
                            scope Scope* sc = null,
                            immutable(char)* prefix = "")
{
    assert(vd);
    vd.loc.warning("vd:%p: sc:%p %s: RD: R/A:%d/%d, WR: R/A:%d/%d, ESC: R/A:%d/%d",
                   vd, sc,
                   prefix,
                   vs.recentReadAccess, vs.allReadAccess,
                   vs.recentWriteAccess, vs.allWriteAccess,
                   vs.recentAliasedAccess, vs.allAliasedAccess);
}

private void checkAccessAtEndOfLife(const VarDeclaration vd,
                                    const VarStat vs)
{
    assert(vd);
    assert(!(vd.storage_class & STC.field));

    if ((vd.storage_class & (STC.manifest | STC.const_ | STC.immutable_)) ||
        vd.isRef ||
        vd.ident == Id.__xpostblit || // skip generated postblit
        isIgnored(vd.ident))
        return;

    if (!vs.allWriteAccess)
    {
        if ((!vd.isParameter ||
             g_warnUnusedParameter) &&
            !vs.allReadAccess)
        {
            vd.loc.warning("unused %s %s `%s` of %s, rename to `_` or prepend `_` to name to silence",
                           vd.protection.kind.toChars(),
                           vd.kind2(),
                           vd.toChars(),
                           vd.parentKind().ptr);
        }
        if ((!vd.isParameter ||
             g_warnMutableUnmodifiedParameter) &&
            !vs.allAliasedAccess) // was aliased to mutable variable
        {
            vd.loc.warning("unmodified %s %s `%s` of %s should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence",
                           vd.protection.kind.toChars(),
                           vd.kind2(),
                           vd.toChars(),
                           vd.parentKind().ptr);
        }
    }

    if (!vd.isOut && // `out` parameters are typically written before return, so no warn
        !vd.isThisDeclaration)
    {
        if (!vs.recentReadAccess &&
            vs.recentWriteAccess)
            vs.recentExp.warning("value assigned to %s %s `%s` of %s is unused, rename to `_` or prepend `_` to name to silence",
                                 vd.protection.kind.toChars(),
                                 vd.kind2(),
                                 vd.toChars(),
                                 vd.parentKind().ptr);
        if (!vs.allReadAccess &&
            vs.allWriteAccess &&
            !vs.allAliasedAccess)
            vd.loc.warning("unused modified %s %s `%s` of %s, rename to `_` or prepend `_` to name to silence",
                           vd.protection.kind.toChars(),
                           vd.kind2(),
                           vd.toChars(),
                           vd.parentKind().ptr);
    }
}

private string parentKind(in Declaration dn)
{
    assert(dn);
    const inForeach = dn.storage_class & STC.foreach_ ? true : false;
    return (inForeach ?
            "foreach" :
            (dn.parent.ident.toChars().startsWith("__unittest_") ?
             "unittest" :
             "function"));
}

// See_Also: https://github.com/rust-lang/rust/issues/48777
private bool isIgnored(const Identifier ident)
{
    assert(ident);
    return (// vd.ident.toString() == "_" ||
        ident.toChars().startsWith("_") // generic skip for now
        // ||
        // vd.ident.toChars().startsWith("__r") || // or if a foreach ignore these
        // vd.ident.toChars().startsWith("__key") ||
        // vd.ident.toChars().startsWith("__limit") ||
        // vd.ident.toChars().startsWith("__aggr")
        );
}

private void checkUnusedFuncDeclaration(FuncDeclaration fd)
{
    assert(fd);
    if (fd.generated ||         // skip generated functions
        isReferencedDeclaration(fd))
        return;

    if (!fd.parent)
    {
        fd.loc.warning("unused %s function `%s` of no parent", fd.prot.kind.toChars(), fd.toChars());
        return;
    }

    if (fd.parent.isModule())
    {
        if (fd.protection.kind == Visibility.Kind.private_)
            fd.loc.warning("unused private function `%s` of module", fd.toChars());
        else if (fd.protection.kind == Visibility.Kind.package_)
            fd.loc.warning("unused package function `%s` of module", fd.toChars());
    }
    else if (const pad = fd.parent.isAggregateDeclaration())
    {
        // TODO: instead capture `pad.stc.extern_` before/during `pad.semantic()`
        // const pad_extern = (pad.storage_class & STC.extern_) ? 1 : 0;
        if ((pad._scope && pad._scope.stc == STC.extern_ ||
             pad.classKind == ClassKind.cpp ||
             pad.classKind == ClassKind.objc))
            return;
        const padUU = pad.protection.kind.shouldWarnUnunsed();
        const dnUU = fd.protection.kind.shouldWarnUnunsed();
        if (padUU && dnUU)
            fd.loc.warning("unused %s %s `%s` of %s %s",
                           fd.protection.kind.toChars(), fd.kind2(), fd.toChars(),
                           pad.protection.kind.toChars(), pad.kind());
        else if (padUU)
            fd.loc.warning("unused %s %s `%s` of %s %s",
                           fd.protection.kind.toChars(), fd.kind2(), fd.toChars(),
                           pad.protection.kind.toChars(), pad.kind());
        else if (dnUU)
            fd.loc.warning("unused %s %s `%s` of %s %s",
                           fd.protection.kind.toChars(), fd.kind2(), fd.toChars(),
                           pad.protection.kind.toChars(), pad.kind());
    }
    else if (fd.parent.isFuncDeclaration())
    {
        // protection always public
        fd.loc.warning("unused nested function `%s`", fd.toChars()); // https://dlang.org/spec/function.html#nested
    }
    else if (!(fd.isMain() ||
               fd.isCMain() ||
               fd.isWinMain() ||
               fd.isDllMain()))
        fd.loc.warning("unused %s function `%s` of parent:%s", fd.protection.kind.toChars(), fd.toChars(), fd.parent.toChars());

    if (!fd.parameters)
        return;

    // if (fd.isVirtualMethod)     // TODO: more advanced condition?
    //     return;                 // exclude non-final methods

    foreach (const param; *(fd.parameters))
        if (!param.isReferenced)
            if (!startsWith(param.ident.toChars(), "_param_")) // named parameters
                param.loc.warning("unused parameter `%s` of function, pass type `%s` only by removing or commenting out name `%s` to silence",
                                  param.toChars(),
                                  param.type.toChars(),
                                  param.toChars());
}

private void checkUnusedIfStatement(IfStatement ie)
{
    assert(ie);
    if (ie.match &&
        !ie.match.isReferenced)
    {
        if (const Initializer ii = ie.match._init)
        {
            if (const ExpInitializer ei = ii.isExpInitializer)
            {
                assert(ei);
                if (const ConstructExp ce = ei.exp.isConstructExp)
                    return ie.match.loc.warning("unused variable `%s` in match expression of if statement, replace with `%s` to silence",
                                                ie.match.toChars(),
                                                ce.e2.toChars());
            }
            // TODO better diagnostics other type of `ii`
            ie.match.loc.warning("unused variable `%s` in match expression of if statement, replace with rhs-expression to silence",
                                 ie.match.toChars());
        }
    }
}

private void checkUnusedFuncAliasDeclaration(FuncAliasDeclaration fd) // TODO: add test for this case
{
    assert(fd);
    if (isReferencedDeclaration(fd))
        return;
    if (fd.protection.kind.shouldWarnUnunsed())
        fd.loc.warning("unused %s function `%s`", fd.prot.kind.toChars(), fd.toChars());
}

private void checkUnusedEnumDeclaration(EnumDeclaration ed)
{
    assert(ed);
    if (isUsedEnumDeclaration(ed))
        return;
    if (ed.protection.kind.shouldWarnUnunsed())
        ed.loc.warning("unused %s enum `%s`", ed.prot.kind.toChars(), ed.toChars());
}

private void checkUnusedEnumMember(EnumMember ed)
{
    assert(ed);
    if (isReferencedDeclaration(ed))
        return;
    if (ed.parent.prot.kind.shouldWarnUnunsed())
        ed.loc.warning("unused member (enumerator) `%s` of %s enum `%s`", ed.toChars(), ed.parent.prot.kind.toChars(), ed.parent.toChars());
}

private void checkUnusedStructDeclaration(StructDeclaration sd)
{
    assert(sd);
    // sd.loc.warning("unused %s struct `%s` with storage class %d", sd.prot.kind.toChars(), sd.toChars(), sd.storage_class);
    if (isUsedAggregateDeclaration(sd))
        return;
    if (sd.protection.kind.shouldWarnUnunsed())
        sd.loc.warning("unused %s struct `%s`", sd.prot.kind.toChars(), sd.toChars());
}

private void checkUnusedClassDeclaration(ClassDeclaration cd)
{
    assert(cd);
    if (isUsedAggregateDeclaration(cd))
        return;
    if (cd.protection.kind.shouldWarnUnunsed())
        cd.loc.warning("unused %s class `%s`", cd.prot.kind.toChars(), cd.toChars());
}

private void checkUnusedInterfaceDeclaration(InterfaceDeclaration id)
{
    assert(id);
    if (isUsedAggregateDeclaration(id))
        return;
    if (id.protection.kind.shouldWarnUnunsed())
        id.loc.warning("unused %s interface `%s`", id.prot.kind.toChars(), id.toChars());
}

private void checkUnusedTemplateDeclaration(TemplateDeclaration td)
{
    assert(td);
    if (isUsedTemplatedDeclaration(td))
        return;
    if (td.protection.kind.shouldWarnUnunsed())
        td.loc.warning("unused %s template `%s`", td.prot.kind.toChars(), td.toChars());
}

private void checkUnusedTemplateParameter(TemplateParameter tp)
{
    assert(tp);
    // TODO: uncomment
    // if (tp.vrefByName == VarStat.none)
    // tp.loc.warning("unused %s template `%s`", tp.prot.kind.toChars(), tp.toChars());
}

private void checkUnusedLabelDsymbol(LabelDsymbol ls)
{
    assert(ls);
    if (ls.isReferenced)
        return;
    ls.loc.warning("unused %s label `%s`", ls.prot.kind.toChars(), ls.toChars());
}

private void checkUnusedLabelStatement(LabelStatement ls)
{
    assert(ls);
    // TODO: detect unused label
}

private void checkUnusedImport(Import im)
{
    assert(im);
    if (!im.aliasdecls.length)  // no explicit symbols given
    {
        if (im.protection.kind == Visibility.Kind.public_)
            return;
        if (im.aliasId)         // Example: `import io = std.stdio;`
        {
            if (!im.isReferenced)
                im.loc.warning("unused %s aliased import `%s`", im.protection.kind.toChars(), im.toChars());
        }
        else                    // Example: `import std.stdio;`
        {
            if (im.mod)
            {
                if (im.mod.isReferenced)
                {
                    if (global.params.diagnostics & Diagnostics.usedImportModuleMembers)
                    {
                        foreach (sym; *im.mod.members)
                            if (sym.isReferenced)
                            {
                                // TODO: use pkg, pkg.isModule(), pkg.toChars(), pkg.toPrettyChars(), id.toChars()?
                                im.loc.warning("used member `%s` of import `%s`, is:", sym.toChars(), im.toChars());
                                sym.loc.warning("definition of used member `%s`", sym.toChars());
                            }
                    }
                }
                else
                    // TODO: use pkg, pkg.isModule(), pkg.toChars(), pkg.toPrettyChars(), id.toChars()?
                    im.loc.warning("unused module `%s` of %s import `%s`",
                                   im.mod.toChars(),
                                   im.protection.kind.toChars(),
                                   im.toChars());
            }
            else
            {
                // im.loc.warning("no module for import %s `%s`", im.protection.kind.toChars(), im.toChars());
            }
        }
        // im.loc.warning("unused import im=`%s`-%d id=`%s` aliasId=`%s` static:`%d` toAlias=`%s`-%d pkg:%s-%d mod:%s-%d",
        //                im.toChars(), im.vrefByName,
        //                im.id ? im.id.toChars() : "none".ptr,
        //                im.aliasId ? im.aliasId.toChars() : "none".ptr,
        //                im.isstatic,
        //                im.toAlias.toChars(), im.toAlias.vrefByName,
        //                im.pkg ? im.pkg.toChars() : "null", im.pkg ? im.pkg.vrefByName : false,
        //                im.mod ? im.mod.toChars() : "null", im.mod ? im.mod.vrefByName : false);
    }
    else
    {
        // TODO: detect and give special diagnostics when all symbols are unused
        foreach (const ad; im.aliasdecls)
        {
            if (ad.isReferenced)
                continue;
            if (ad.protection.kind == Visibility.Kind.public_)
                continue;
            // TODO correct `ad.loc` upon its creation
            ad.loc.warning("unused %s imported alias `%s`", im.prot.kind.toChars(), ad.toChars());
        }
    }
}

static private immutable(char)* toChars(in Visibility.Kind protKind) @safe /* TODO: pure nothrow */ @nogc
{
    final switch (protKind)
    {
    case Visibility.Kind.undefined:
        return "undefined";
    case Visibility.Kind.none:
        return "none";
    case Visibility.Kind.private_:
        return "private";
    case Visibility.Kind.package_:
        return "package";
    case Visibility.Kind.protected_:
        return "protected";
    case Visibility.Kind.public_:
        return "public";
    case Visibility.Kind.export_:
        return "export";
    }
}

static private bool shouldWarnUnunsed(in Visibility.Kind protKind) @safe /* TODO: pure nothrow */ @nogc
{
    final switch (protKind)
    {
    case Visibility.Kind.undefined:   // not semantically analyzed
    case Visibility.Kind.public_:
    case Visibility.Kind.export_:
        return false;
    case Visibility.Kind.none:        // unreachable. Voldemort?
    case Visibility.Kind.private_:
    case Visibility.Kind.package_:
    case Visibility.Kind.protected_:
        return true;
    }
}

bool doCheckUnused() nothrow @nogc
{
    return (global.params.diagnostics & Diagnostics.symbolAccess);
}

static private bool isReferencedDeclaration(const Declaration d) @safe /* TODO: pure nothrow */ @nogc
{
    assert(d);
    return (d.isReferenced ||
            d.protection.kind == Visibility.Kind.undefined); // has no semantics
}

static private bool isUnreferencedVarDeclaration(const VarDeclaration vd) @safe /* TODO: pure nothrow */ @nogc
{
    assert(vd);
    return (!vd.isReferenced ||
            vd.protection.kind == Visibility.Kind.undefined); // has no semantics
}

static private bool isUsedEnumDeclaration(const EnumDeclaration ed) @safe /* TODO: pure nothrow */ @nogc
{
    assert(ed);
    return (ed.isReferenced ||
            ed.protection.kind == Visibility.Kind.undefined); // has no semantics
}

static private bool isUsedAggregateDeclaration(const AggregateDeclaration ad) @safe /* TODO: pure nothrow */ @nogc
{
    assert(ad);
    // ad.loc.warning("`%s` classkind:%d storage_class:%x extern:%d",
    //                ad.toChars(),
    //                ad.classKind,
    //                ad.storage_class,
    //                (ad.storage_class & STC.extern_) ? 1 : 0);
    return (ad.isReferenced ||
            ad.protection.kind == Visibility.Kind.undefined || // has no semantics
            ad.classKind == ClassKind.cpp ||
            ad.classKind == ClassKind.objc ||
            (ad.storage_class & STC.extern_) ? 1 : 0);
}

static private bool isUsedTemplatedDeclaration(const TemplateDeclaration td) @safe /* TODO: pure nothrow */ @nogc
{
    assert(td);
    return (td.isReferenced ||
            td.protection.kind == Visibility.Kind.undefined); // has no semantics
}

static private const(char)* kind2(const Declaration dn) @safe /* TODO: pure nothrow */ @nogc
{
    assert(dn);
    if (dn.storage_class & STC.manifest)
        return dn.isField() ? "manifest constant field" : "manifest constant";
    else if (dn.storage_class & STC.const_)
        return (dn.isParameter() ?
                "constant parameter" :
                (dn.isField() ?
                 "constant field" :
                 "constant"));
    else if (dn.storage_class & STC.immutable_)
        return (dn.isParameter() ?
                "immutable parameter" :
                (dn.isField() ?
                 "immutable field" :
                 "immutable"));
    else
        return (dn.isParameter() ?
                "parameter" :
                (dn.isField() ?
                 "field" :
                 dn.kind()));
}

private void diagnoseSelfRecursion(FuncDeclaration fd)
{
    assert(fd);
    if (!fd)
        return;
    if (!fd.fbody)
        return;
    if (const s = fd.fbody.isReturnStatement)
    {
        s.loc.warning("rs:%s", s.toChars());
    }
    else if (const cs = fd.fbody.isCompoundStatement)
    {
        // cs.loc.warning("FuncDeclaration: name:%s, length:%d, pure:%d linkage:%d",
        //                fd.toChars(),
        //                cs.statements.length,
        //                fd.isPure,
        //                fd.linkage);
        if (!fd.isPure) // skip unpure functions for now or has control flow
            return;
        // fd.loc.warning("is pure");
        if (!cs.statements)
            return;
        foreach (s; *cs.statements)
            if (s.isReturnStatement())
            {
                // s.loc.warning("has return");
                // check if function is pure
            }
            // else
            //     s.loc.warning("s:%s", s.toChars());
    }
    // if (!fd.returns)
    //     return;
    // foreach (ret; *fd.returns)
    // {
    //     ret.loc.warning("ret:%s", ret.toChars());
    // }
}

/// Print STC-bits set in `storage_class`.
string toStringOfSTCs(in StorageClass storage_class) /* TODO: pure nothrow */ @safe
{
    typeof(return) result;
    static foreach (element; __traits(allMembers, STC))
    {
        if (storage_class & mixin("STC." ~ element) && // `mixin("STC.", element)` doesn't parse in DMD 2.079
            element != "safeGroup" &&
            element != "IOR" &&
            element != "TYPECTOR" &&
            element != "FUNCATTR")
        {
            if (result)
                result ~= ",";
            if (element.length && element[$ - 1] == '_') // endsWith('_')
                result ~= element[0 .. $ - 1];           // skip it
            else
                result ~= element;
        }
    }
    return result;
}
