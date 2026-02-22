/**
 * Expression walker for the fast Data Flow Analysis engine.
 *
 * This module tracks how values flow through expressions.
 * It is responsible for:
 * 1. Tracking Assignments: Updating the state of variables when they are written to.
 * 2. Inferring Facts: Learning about variables from conditions (e.g., `if (ptr)`).
 * 3. Handling Function Calls: Managing side effects and return values.
 * 4. Modeling Arithmetic: Tracking ranges of values (Point Analysis) to detect overflows.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dfa/fast/expression.d, dfa/fast/expression.d)
 * Documentation: https://dlang.org/phobos/dmd_dfa_fast_expression.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dfa/fast/expression.d
 */
module dmd.dfa.fast.expression;
import dmd.dfa.fast.analysis;
import dmd.dfa.fast.report;
import dmd.dfa.fast.statement;
import dmd.dfa.fast.structure;
import dmd.dfa.utils;
import dmd.common.outbuffer;
import dmd.location;
import dmd.expression;
import dmd.expressionsem;
import dmd.typesem;
import dmd.astenums;
import dmd.tokens;
import dmd.func;
import dmd.declaration;
import dmd.mtype;
import dmd.dtemplate;
import dmd.arraytypes;
import dmd.rootobject;
import dmd.id;
import dmd.dsymbol;
import core.stdc.stdio;

/***********************************************************
 * Visits Expression nodes to track data flow.
 *
 * This struct implements the logic for how expressions affect the DFA state.
 * It translates AST operations (like `+`, `=`, `==`) into `DFALatticeRef` updates.
 */
struct ExpressionWalker
{
    DFACommon* dfaCommon;
    StatementWalker stmtWalker;
    DFAAnalyzer* analyzer;

    __gshared immutable(string[]) AllExprOpNames = [__traits(allMembers, EXP)];

    void seeConvergeExpression(DFALatticeRef lr, bool isSideEffect = false)
    {
        dfaCommon.printStateln("Converging expression:");
        lr.printState("", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        lr.check;

        dfaCommon.check;
        analyzer.convergeExpression(lr, isSideEffect);
        dfaCommon.check;

        dfaCommon.currentDFAScope.printState("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeFunctionCallArgument(DFALatticeRef lr, ParameterDFAInfo* paramInfo,
            ulong paramStorageClass, FuncDeclaration calling, ref Loc loc)
    {
        dfaCommon.printStateln("Converging argument:");
        lr.printState("", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        lr.check;

        dfaCommon.check;
        analyzer.convergeFunctionCallArgument(lr, paramInfo, paramStorageClass, calling, loc);
        dfaCommon.check;

        dfaCommon.currentDFAScope.printState("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.check;
    }

    /***********************************************************
     * Handles variable assignment (e.g., `x = y`).
     *
     * This function updates the `assignTo` variable in the current scope
     * to reflect the new state derived from `lr` (the right-hand side).
     *
     * Params:
     *      assignTo = The variable being written to.
     *      construct = True if this is an initialization (e.g., `int x = 5;`), false if reassignment.
     *      lr = The lattice state of the value being assigned.
     *      loc = Source file location of the assignment.
     *      isBlit = True if the assignment is a bitwise copy (blit).
     *      alteredState = An integer representing a specific state alteration or flag.
     */
    DFALatticeRef seeAssign(DFAVar* assignTo, bool construct, DFALatticeRef lr,
            ref Loc loc, bool isBlit = false, int alteredState = 0)
    {
        DFALatticeRef assignTo2 = dfaCommon.makeLatticeRef;
        assignTo2.setContext(assignTo);

        dfaCommon.check;
        DFALatticeRef ret = seeAssign(assignTo2, construct, lr, loc, isBlit);
        dfaCommon.check;

        return ret;
    }

    DFALatticeRef seeAssign(DFALatticeRef assignTo, bool construct, DFALatticeRef lr, ref Loc loc,
            bool isBlit = false, int alteredState = 0, DFALatticeRef indexLR = DFALatticeRef.init)
    {
        dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) => ob.printf(
                "Assigning construct?%d:%d %d\n", construct, isBlit, alteredState));
        assignTo.printState("to", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        assignTo.check;
        lr.printState("from", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        lr.check;
        indexLR.printState("index", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        indexLR.check;

        assert(analyzer !is null);
        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferAssign(assignTo, construct,
                isBlit, lr, alteredState, loc, indexLR);
        dfaCommon.check;

        ret.check;
        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.currentDFAScope.printState("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.check;
        return ret;
    }

    /***********************************************************
     * Handles equality checks (e.g., `x == y`).
     *
     * This is critical for control flow. If the DFA sees `if (x == null)`,
     * this function records that relationship so the `StatementWalker` can
     * create a scope where `x` is known to be null.
     */
    DFALatticeRef seeEqual(DFALatticeRef lhs, DFALatticeRef rhs, bool truthiness,
            Type lhsType, Type rhsType)
    {
        const equalityType = equalityArgTypes(lhsType, rhsType);

        dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("Equal iff=%d, ty=%d:%d, ety=%d", truthiness, lhsType.ty,
                rhsType !is null ? rhsType.ty : -1, equalityType);
            ob.writestring("\n");
        });

        lhs.printState("lhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        rhs.printState("rhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferEqual(lhs, rhs, truthiness, equalityType, false);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    /***********************************************************
     * Handles equality checks (e.g., `x is y`).
     *
     * This is critical for control flow. If the DFA sees `if (x == null)`,
     * this function records that relationship so the `StatementWalker` can
     * create a scope where `x` is known to be null.
     */
    DFALatticeRef seeEqualIdentity(DFALatticeRef lhs, DFALatticeRef rhs,
            bool truthiness, Type lhsType, Type rhsType)
    {
        const equalityType = equalityArgTypes(lhsType, rhsType);

        dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("Equal identity iff=%d, ty=%d:%d, ety=%d", truthiness,
                lhsType.ty, rhsType !is null ? rhsType.ty : -1, equalityType);
            ob.writestring("\n");
        });

        lhs.printState("lhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        rhs.printState("rhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferEqual(lhs, rhs, truthiness, equalityType, true);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    DFALatticeRef seeNegate(DFALatticeRef lr, Type type,
            bool protectElseNegate = false, bool limitToContext = false)
    {
        lr.printState("Negate", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferNegate(lr, type, protectElseNegate, limitToContext);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    DFALatticeRef seeMathOp(DFALatticeRef lhs, DFALatticeRef rhs, Type type, PAMathOp op)
    {
        dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("Math op %d", op);
            ob.writestring("\n");
        });
        lhs.printState("lhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        rhs.printState("rhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferMathOp(lhs, rhs, type, op);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    DFALatticeRef seeDereference(ref Loc loc, DFALatticeRef lr)
    {
        dfaCommon.printStateln("Dereferencing");
        lr.printState("Dereference", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferDereference(lr, loc);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    void seeAssert(DFALatticeRef lr, ref Loc loc, bool dueToConditional = false)
    {
        lr.printState("Assert", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.currentDFAScope.printState("scope", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.check;

        dfaCommon.check;
        analyzer.transferAssert(lr, loc, false, dueToConditional);
        dfaCommon.check;

        dfaCommon.currentDFAScope.printState("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.check;
    }

    void seeSilentAssert(DFALatticeRef lr, bool ignoreWriteCount = false,
            bool dueToConditional = false)
    {
        lr.printState("Assert silent", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.currentDFAScope.printState("scope", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.check;

        Loc loc;
        dfaCommon.check;
        analyzer.transferAssert(lr, loc, ignoreWriteCount, dueToConditional);
        dfaCommon.check;

        dfaCommon.currentDFAScope.printState("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.check;
    }

    DFALatticeRef seeLogicalAnd(DFALatticeRef lhs, DFALatticeRef rhs)
    {
        dfaCommon.printStateln("Logical and:");
        lhs.printState("lhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        lhs.check;
        rhs.printState("rhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        rhs.check;

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferLogicalAnd(lhs, rhs);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        ret.check;
        return ret;
    }

    DFALatticeRef seeLogicalOr(DFALatticeRef lhs, DFALatticeRef rhs)
    {
        dfaCommon.printStateln("Logical or:");
        lhs.printState("lhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        rhs.printState("rhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferLogicalOr(lhs, rhs);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    DFALatticeRef seeConditional(DFALatticeRef condition, DFAScopeRef scrTrue, DFALatticeRef lrTrue,
            DFAScopeRef scrFalse, DFALatticeRef lrFalse, bool unknownBranchTaken,
            int predicateNegation)
    {
        dfaCommon.printStateln("Condition:");
        condition.printState("condition", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        scrTrue.printState("true sc", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        lrTrue.printState("true lr", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        scrFalse.printState("false sc", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);
        lrFalse.printState("false lr", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferConditional(condition, scrTrue,
                lrTrue, scrFalse, lrFalse, unknownBranchTaken, predicateNegation);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        dfaCommon.currentDFAScope.printState("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction, dfaCommon.edepth);

        ret.check;
        dfaCommon.currentDFAScope.check;
        return ret;
    }

    DFALatticeRef seeGreaterThan(bool orEqualTo, DFALatticeRef lhs, DFALatticeRef rhs)
    {
        dfaCommon.printStateln(orEqualTo ? "Greater than or equal to:" : "Greater than:");
        lhs.printState("lhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        rhs.printState("rhs", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        dfaCommon.check;
        DFALatticeRef ret = analyzer.transferGreaterThan(orEqualTo, lhs, rhs);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    void seeRead(ref DFALatticeRef lr, ref Loc loc)
    {
        dfaCommon.printStateln("Seeing read of lr");
        lr.printState("read lr", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        analyzer.onRead(lr, loc);
    }

    void seeReadMathOp(ref DFALatticeRef lr, ref Loc loc)
    {
        dfaCommon.printStateln("Seeing read of math op lr");
        lr.printState("read lr", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        analyzer.onRead(lr, loc, false, false, true);
    }

    DFALatticeRef adaptConditionForBranch(Expression expr, bool truthiness)
    {
        if (expr is null)
            return DFALatticeRef.init;

        return this.adaptConditionForBranch(this.walk(expr), expr.type, truthiness);
    }

    DFALatticeRef adaptConditionForBranch(DFALatticeRef ret, Type type, bool truthiness)
    {
        if (ret.isNull)
        {
            ret = dfaCommon.makeLatticeRef;
            ret.acquireConstantAsContext;
        }

        DFAVar* ctx;
        DFAConsequence* cctx = ret.getContext(ctx);
        assert(cctx !is null);

        if (ctx !is null && ctx.isNullable && cctx.truthiness == Truthiness.Unknown)
        {
            DFALatticeRef against = dfaCommon.makeLatticeRef;

            if (truthiness)
                against.acquireConstantAsContext(Truthiness.True, Nullable.NonNull, null);
            else
                against.acquireConstantAsContext(Truthiness.False, Nullable.Null, null);

            ret = this.seeEqual(ret, against, truthiness, type, null);
        }
        else if (!truthiness)
        {
            if ((cctx = ret.getGateConsequence) !is null)
            {
                ret.setContext(cctx);
                ret = this.seeNegate(ret, type);
            }
            else
            {
                // Unfortunately negation is a bit overactive for else bodies.
                ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext;
            }
        }

        return ret;
    }

    /***********************************************************
     * The main dispatch loop for expressions.
     *
     * Visits an expression node and returns the resulting Lattice state.
     * This handles the recursion for complex expressions like `(a + b) * c`.
     *
     * Returns:
     * A `DFALatticeRef` representing the computed value/state of the expression.
     */
    DFALatticeRef walk(Expression expr)
    {
        if (expr is null)
            return DFALatticeRef.init;

        dfaCommon.edepth++;
        dfaCommon.check;

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("[%p]%3d walk (%s): at ", expr, expr.op, AllExprOpNames[expr.op].ptr);
            appendLoc(ob, expr.loc);
            ob.writestring("\n");
        });

        scope (exit)
        {
            dfaCommon.check;
            dfaCommon.edepth--;
        }

        final switch (expr.op)
        {
        case EXP.not: // !x
        case EXP.equal:
        case EXP.notEqual:
        case EXP.identity: // is
        case EXP.notIdentity: // !is
        case EXP.string_:
        case EXP.typeid_:
        case EXP.arrayLiteral:
        case EXP.assocArrayLiteral:
        case EXP.arrayLength:
        case EXP.int64:
        case EXP.null_:
        case EXP.cast_:
        case EXP.variable:
            int predicateNegation;
            return this.walkCondition(expr, predicateNegation);

        case EXP.this_:
            auto vd = expr.isThisExp.var;

            if (vd is null)
                vd = dfaCommon.currentFunction.vthis;

            if (!dfaCommon.debugUnknownAST && vd is null)
                return DFALatticeRef.init;
            else if (vd is null)
                assert(0);

            DFAVar* var = dfaCommon.findVariable(vd);
            return dfaCommon.acquireLattice(var);

        case EXP.dotVariable:
            auto dve = expr.isDotVarExp;

            dfaCommon.printStateln("Dot var lhs");
            DFALatticeRef ret = this.walk(dve.e1);
            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* context = ret.getContext;
            DFAVar* var;

            // for indirection we start with a clean slate on each access
            if (auto vd = dve.var.isVarDeclaration)
            {
                if (context is null || context.var is null)
                    var = dfaCommon.findVariable(vd);
                else
                    var = dfaCommon.findVariable(vd, context.var);
            }

            DFAConsequence* c = ret.addConsequence(var);
            ret.setContext(c);
            return ret;

        case EXP.symbolOffset:
            // similar to address except has a variable offset
            auto soe = expr.isSymOffExp;
            DFALatticeRef ret;
            DFAVar* varBase, varOffset;

            if (auto vd = soe.var.isVarDeclaration)
            {
                varBase = dfaCommon.findVariable(vd);
                if (varBase is null)
                    return DFALatticeRef.init;

                ret = dfaCommon.acquireLattice(varBase);
                if (ret.isNull)
                    ret = dfaCommon.makeLatticeRef;

                varOffset = dfaCommon.findOffsetVar(soe.offset, varBase);
                assert(varOffset is null || varOffset.haveBase);

                DFAConsequence* c = ret.addConsequence(varOffset);
                ret.setContext(c);

                c.obj = dfaCommon.makeObject(varBase);

                if (varBase.declaredAtDepth > 0)
                {
                    c.truthiness = Truthiness.True;
                    c.nullable = Nullable.NonNull;
                }

                if (soe.offset != 0)
                    c.obj.mayNotBeExactPointer = true;
            }
            else if (auto fd = soe.var.isFuncDeclaration)
            {
                // For some reason, sometimes people like to do an offset that isn't zero for functions.
                // So we'll ignore that and assume the offset is "right",
                //  even if it probably doesn't make sense to be doing it.

                ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext(Truthiness.True, Nullable.NonNull,
                        dfaCommon.makeObject);
            }
            else
            {
                if (!dfaCommon.debugUnknownAST)
                    return DFALatticeRef.init;
                else
                    assert(0);
            }

            return ret;

        case EXP.address:
            // Similar to symbolOffset except is always at offset 0
            auto ae = expr.isAddrExp;

            DFALatticeRef ret = this.walk(ae.e1);

            if (!ret.isNull)
            {
                DFAVar* ctx = ret.getContextVar;

                if (ctx !is null)
                {
                    DFAVar* varOffset = dfaCommon.findOffsetVar(0, ctx);
                    DFAConsequence* cctx = ret.setContext(varOffset);

                    cctx.obj = dfaCommon.makeObject(ctx);

                    if (ctx.declaredAtDepth > 0)
                    {
                        cctx.truthiness = Truthiness.True;
                        cctx.nullable = Nullable.NonNull;
                    }
                }
            }

            return ret;

        case EXP.declaration:
            {
                auto symbol = expr.isDeclarationExp.declaration;

                void eachDeclarationSymbol(Dsymbol symbol)
                {
                    if (auto var = symbol.isVarDeclaration)
                    {
                        if (var.ident !is null)
                        {
                            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                                ob.printf("Declaring variable: %s\n", var.ident.toChars);
                            });
                        }

                        DFAVar* dfaVar = dfaCommon.findVariable(var);
                        dfaVar.declaredAtDepth = dfaCommon.currentDFAScope.depth;
                        DFAScopeVar* scv = dfaCommon.acquireScopeVar(dfaVar);
                        DFAConsequence* cctx = scv.lr.getContext;

                        // ImportC supports syntax as: Type var = var;
                        // Bit of a problem that...
                        // Due to the construct expression on rhs, is going to see var as being uninitialized.
                        // What we'll do instead, is init ALL VARIABLES, and based upon the init expression, uninitialize it.

                        {
                            dfaVar.writeCount = 1;
                            cctx.writeOnVarAtThisPoint = 1;
                        }

                        if (var._init !is null)
                        {
                            final switch (var._init.kind)
                            {
                            case InitKind.exp:
                                auto ei = var._init.isExpInitializer;

                                if (ei.loc == var.loc && (var.storage_class & STC.foreach_) == 0)
                                {
                                    // This is default initialization

                                    if (dfaVar.isFloatingPoint)
                                    {
                                        // Floating point initializes to NaN which is NOT a good default.
                                        // Allow explicit, but not default initialization.
                                        dfaVar.wasDefaultInitialized = true;
                                        goto case InitKind.void_;
                                    }
                                }

                                // does this var escape another? Can't model that.
                                if ((var.storage_class & STC.ref_) == STC.ref_)
                                    markUnmodellable(ei.exp);

                                DFALatticeRef lr = this.walk(ei.exp);

                                if (!(ei.exp.isConstructExp || ei.exp.isBlitExp))
                                    seeAssign(dfaVar, true, lr, ei.exp.loc);
                                break;

                            case InitKind.array:
                                auto ai = var._init.isArrayInitializer;
                                DFALatticeRef lr = dfaCommon.makeLatticeRef;
                                DFAConsequence* c = lr.addConsequence(dfaVar);
                                lr.setContext(c);

                                seeAssign(dfaVar, true, lr, ai.loc, false,
                                        ai.value.length > 0 ? 3 : 2);
                                break;

                            case InitKind.void_:
                                dfaVar.writeCount = 0;
                                cctx.writeOnVarAtThisPoint = 0;
                                break;

                            case InitKind.error:
                            case InitKind.struct_:
                            case InitKind.C_:
                            case InitKind.default_:
                                break;
                            }
                        }
                    }
                }

                if (auto ad = symbol.isAttribDeclaration)
                {
                    // ImportC wraps their declarations

                    if (ad.decl !is null)
                    {
                        foreach (symbol2; *ad.decl)
                        {
                            eachDeclarationSymbol(symbol2);
                        }
                    }
                }
                else
                    eachDeclarationSymbol(symbol);

                return DFALatticeRef.init;
            }

        case EXP.construct:
            auto ce = expr.isConstructExp;

            dfaCommon.printStateln("construct lhs");
            DFALatticeRef lhs = this.walk(ce.e1);

            dfaCommon.printStateln("construct rhs");
            DFALatticeRef rhs = this.walk(ce.e2);

            return seeAssign(lhs, true, rhs, ce.loc);

        case EXP.negate: // -x
            auto ue = expr.isUnaExp;
            DFALatticeRef ret = this.walk(ue.e1);
            return this.seeNegate(ret, ue.type, false, true);

            // Basic types
        case EXP.void_:
        case EXP.float64:
        case EXP.complex80:
            DFALatticeRef ret = dfaCommon.makeLatticeRef;
            ret.acquireConstantAsContext;
            return ret;

        case EXP.call:
            auto ce = expr.isCallExp;
            assert(ce !is null);
            assert(ce.e1 !is null);
            return callFunction(ce.f, ce.e1, null, ce.arguments, ce.loc);

        case EXP.blit:
            auto be = expr.isBlitExp;

            dfaCommon.printStateln("blit lhs");
            DFALatticeRef lhs, rhs;

            if (auto se = be.e1.isSliceExp)
            {
                // if we're bliting to a static array, let's ignore the empty slice.
                assert(se.upr is null);
                assert(se.lwr is null);
                lhs = this.walk(se.e1);
            }
            else
                lhs = this.walk(be.e1);

            if (auto e2ve = be.e2.isVarExp)
            {
                if (auto sd = e2ve.var.isSymbolDeclaration)
                {
                    // this evaluates out to a type

                    rhs = dfaCommon.makeLatticeRef;
                    rhs.acquireConstantAsContext(Truthiness.True,
                            Nullable.NonNull, dfaCommon.makeObject);

                    goto BlitAssignRet;
                }
            }

            dfaCommon.printStateln("blit rhs");
            rhs = this.walk(be.e2);

        BlitAssignRet:
            DFALatticeRef ret = seeAssign(lhs, true, rhs, be.loc, true);
            return ret;

        case EXP.assign:
            auto ae = expr.isAssignExp;

            Expression lhsContext = ae.e1, lhsIndex;

            if (auto ie = ae.e1.isIndexExp)
            {
                // Is this AA assignment?

                if (isIndexContextAA(ie))
                {
                    // ae.e1 resolves to a ctx[idx]
                    // ie.e1 is ctx, and ie.e2 is idx

                    lhsContext = ie.e1;
                    lhsIndex = ie.e2;
                }
            }

            dfaCommon.printStateln("assign lhs");
            DFALatticeRef lhs = this.walk(lhsContext);
            DFALatticeRef indexLR;

            if (lhsIndex !is null)
            {
                dfaCommon.printStateln("assign lhs index");
                indexLR = this.walk(lhsIndex);
            }

            dfaCommon.printStateln("assign rhs");
            DFALatticeRef rhs = this.walk(ae.e2);
            DFALatticeRef ret = seeAssign(lhs, false, rhs, ae.loc, false,
                    lhsIndex !is null ? 3 : 0, indexLR);

            if (ret.isNull)
            {
                ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext;
            }

            return ret;

        case EXP.star:
            auto pe = expr.isPtrExp;
            dfaCommon.printStateln("Derefencing exp");
            DFALatticeRef lr = walk(pe.e1);
            return seeDereference(pe.loc, lr);

        case EXP.index:
            {
                // See Slice
                auto ie = expr.isIndexExp;

                dfaCommon.printStateln("index lhs");
                DFALatticeRef lhs = this.walk(ie.e1);
                dfaCommon.printStateln("index rhs");
                DFALatticeRef index = this.walk(ie.e2);

                DFAVar* lhsCtx;
                DFAConsequence* lhsCctx = lhs.getContext(lhsCtx);

                DFAObject* lhsObject;

                Type lhsType = ie.e1.type;
                bool resultHasEffect;

                if (lhsCctx !is null)
                {
                    // Apply effects that this operation will have on to the lhs

                    bool effectIndexBase = ie.indexIsInBounds;

                    if (lhsType.isTypeAArray !is null)
                    {
                        if (ie.modifiable)
                            effectIndexBase = true;
                    }
                    else
                        resultHasEffect = true;

                    if (effectIndexBase)
                    {
                        lhsCctx.truthiness = Truthiness.True;
                        lhsCctx.nullable = Nullable.NonNull;
                    }

                    if (lhsCctx.obj !is null)
                    {
                        lhsObject = lhsCctx.obj;
                        lhsObject.mayNotBeExactPointer = true;
                    }
                }

                if (lhsCtx !is null && lhsCtx.isNullable)
                {
                    // Dereference the lhs if its a pointer,
                    //  this really should be the case, but it prevents unnecessary work for static arrays.
                    lhs = seeDereference(ie.loc, lhs);
                }

                DFAVar* indexVar = dfaCommon.findIndexVar(lhsCtx);
                DFALatticeRef combined = this.seeLogicalAnd(lhs, index);
                DFAConsequence* newCctx = combined.addConsequence(indexVar);
                combined.setContext(newCctx);

                if (resultHasEffect && indexVar !is null)
                {
                    if (indexVar.isTruthy)
                        newCctx.truthiness = Truthiness.True;
                    if (indexVar.isNullable)
                        newCctx.nullable = Nullable.NonNull;
                }

                return combined;
            }

        case EXP.slice:
            {
                // See index
                auto se = expr.isSliceExp;

                dfaCommon.printStateln("Slice base");
                DFALatticeRef base = this.walk(se.e1);
                DFAVar* baseCtx;
                DFAConsequence* baseCctx = base.getContext(baseCtx);

                if (se.lwr is null && se.upr is null)
                {
                    // Equivalent to doing slice[]
                    DFAVar* asSliceVar = dfaCommon.findAsSliceVar(baseCtx);
                    DFAConsequence* newCctx = base.addConsequence(asSliceVar);
                    base.setContext(newCctx);

                    if (baseCctx !is null && baseCctx.obj !is null)
                        newCctx.obj = baseCctx.obj;
                    else
                        newCctx.obj = dfaCommon.makeObject(baseCtx);
                    return base;
                }

                Truthiness expectedTruthiness;
                DFALatticeRef ret = base;

                {
                    dfaCommon.printStateln("Slice [lwr");
                    DFALatticeRef lower = this.walk(se.lwr);
                    dfaCommon.printStateln("Slice upr]");
                    DFALatticeRef upper = this.walk(se.upr);

                    DFAConsequence* lowerCctx = lower.getContext, upperCctx = upper.getContext;
                    DFAPAValue newPA;

                    if (lowerCctx !is null && upperCctx !is null)
                    {
                        newPA = upperCctx.pa;
                        newPA.subtractFrom(lowerCctx.pa, Type.tuns64);
                    }

                    DFALatticeRef together = this.seeLogicalAnd(lower, upper);
                    ret = this.seeLogicalAnd(ret, together);

                    DFAConsequence* cctx = ret.addConsequence(baseCtx);
                    cctx.pa = newPA;

                    if (se.upperIsInBounds
                            || (newPA.kind == DFAPAValue.Kind.Concrete && newPA.value > 0))
                    {
                        expectedTruthiness = Truthiness.True;
                        cctx.truthiness = Truthiness.True;
                        cctx.nullable = Nullable.NonNull;
                    }
                }

                if (baseCtx !is null && baseCtx.isNullable)
                {
                    // Dereference if its a pointer,
                    //  this really should be the case, but it prevents unnecessary work for static arrays.
                    ret = seeDereference(se.loc, ret);
                }

                DFAVar* indexVar = dfaCommon.findIndexVar(baseCtx);
                DFAConsequence* newCctx = ret.addConsequence(indexVar);
                ret.setContext(newCctx);

                if (indexVar !is null)
                {
                    if (indexVar.isTruthy)
                        newCctx.truthiness = expectedTruthiness;

                    // If this expression were to succeed, the resulting slice will be non-null.
                    // Thanks to the read barrier for bounds checking.
                    if (indexVar.isNullable)
                        newCctx.nullable = Nullable.NonNull;
                }

                return ret;
            }

        case EXP.assert_:
            // User assertions act as facts for the DFA.
            // `assert(x != null)` tells the engine that `x` is NonNull
            // for all subsequent code in this scope.
            auto ae = expr.isAssertExp;
            DFALatticeRef lr = this.walk(ae.e1);
            seeAssert(lr, ae.e1.loc);
            return DFALatticeRef.init;

        case EXP.halt:
            DFALatticeRef lr = dfaCommon.makeLatticeRef;
            lr.acquireConstantAsContext(Truthiness.False, Nullable.Unknown, null);

            seeAssert(lr, expr.loc);
            // Evaluates to void
            return DFALatticeRef.init;

        case EXP.new_:
            auto ne = expr.isNewExp;

            DFALatticeRef ret = this.callFunction(ne.member, ne.thisexp,
                    ne.argprefix, ne.arguments, ne.loc);

            if (ne.placement !is null)
                markUnmodellable(ne.placement);

            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAVar* var = dfaCommon.getInfiniteLifetimeVariable;
            DFAConsequence* c = ret.addConsequence(var);
            ret.setContext(c);

            c.truthiness = Truthiness.True;
            c.nullable = Nullable.NonNull;
            c.obj = dfaCommon.makeObject;
            return ret;

        case EXP.andAnd:
            auto be = expr.isBinExp;

            stmtWalker.startScope;
            dfaCommon.currentDFAScope.sideEffectFree = true;
            DFALatticeRef inProgress;

            // if lhs is false, so will the andAnd

            // assume rhs could be andAnd
            while (be !is null)
            {
                DFALatticeRef lhs = this.walk(be.e1);
                seeRead(lhs, be.e1.loc);

                {
                    lhs = this.adaptConditionForBranch(lhs, be.e1.type, true);
                    DFAConsequence* c = lhs.getContext;

                    if (c !is null && c.truthiness == Truthiness.False)
                    {
                        inProgress = dfaCommon.makeLatticeRef;
                        inProgress.acquireConstantAsContext(Truthiness.False,
                                Nullable.Unknown, null);
                        break;
                    }
                }

                this.seeSilentAssert(lhs.copy);

                if (inProgress.isNull)
                    inProgress = lhs;
                else
                    inProgress = seeLogicalAnd(inProgress, lhs);

                if (be.e2.op == EXP.andAnd)
                {
                    be = be.e2.isBinExp;
                    continue;
                }
                else
                {
                    DFALatticeRef rhs = this.walk(be.e2);
                    seeRead(rhs, be.e2.loc);
                    rhs = this.adaptConditionForBranch(rhs, be.e2.type, true);

                    {
                        rhs = this.adaptConditionForBranch(rhs, be.e1.type, true);
                        DFAConsequence* c = rhs.getContext;

                        if (c !is null && c.truthiness == Truthiness.False)
                        {
                            inProgress = dfaCommon.makeLatticeRef;
                            inProgress.acquireConstantAsContext(Truthiness.False,
                                    Nullable.Unknown, null);
                            break;
                        }
                    }

                    inProgress = seeLogicalAnd(inProgress, rhs);
                    break;
                }
            }

            stmtWalker.endScope;
            return inProgress;

        case EXP.orOr:
            int predicateNegation;
            return this.walkCondition(expr.isLogicalExp, predicateNegation);

        case EXP.lessThan:
            // < becomes >
            auto be = expr.isBinExp;
            DFALatticeRef lhs = this.walk(be.e2);
            DFALatticeRef rhs = this.walk(be.e1);
            return this.seeGreaterThan(false, lhs, rhs);

        case EXP.lessOrEqual:
            // <= becomes >=
            auto be = expr.isBinExp;
            DFALatticeRef lhs = this.walk(be.e2);
            DFALatticeRef rhs = this.walk(be.e1);
            return this.seeGreaterThan(true, lhs, rhs);

        case EXP.greaterThan:
            auto be = expr.isBinExp;
            DFALatticeRef lhs = this.walk(be.e1);
            DFALatticeRef rhs = this.walk(be.e2);
            return this.seeGreaterThan(false, lhs, rhs);

        case EXP.greaterOrEqual:
            auto be = expr.isBinExp;
            DFALatticeRef lhs = this.walk(be.e1);
            DFALatticeRef rhs = this.walk(be.e2);
            return this.seeGreaterThan(true, lhs, rhs);

        case EXP.in_:
            auto be = expr.isBinExp;

            DFALatticeRef lhs = this.walk(be.e1);
            lhs.check;

            DFALatticeRef rhs = this.walk(be.e2);
            rhs.check;

            DFAVar* rhsVar = rhs.getContextVar;

            // change comparison to: lhs in rhs[...]
            if (rhsVar !is null)
                rhs.setContext(dfaCommon.findIndexVar(rhsVar));

            return this.seeEqual(lhs, rhs, true, be.e1.type, be.e2.type);

        case EXP.addAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.add);
        case EXP.minAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.sub);
        case EXP.mulAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.mul);
        case EXP.divAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.div);
        case EXP.modAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.mod);
        case EXP.andAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.and);
        case EXP.orAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.or);
        case EXP.xorAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.xor);
        case EXP.powAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.pow);
        case EXP.leftShiftAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.leftShift);
        case EXP.rightShiftAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.rightShiftSigned);
        case EXP.unsignedRightShiftAssign:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.rightShiftUnsigned);

        case EXP.concatenateAssign: // ~=
            return concatenateTwo(expr.isBinExp, 0, true);
        case EXP.concatenateElemAssign:
            return concatenateTwo(expr.isBinExp, 1, true);
        case EXP.concatenateDcharAssign:
            return concatenateTwo(expr.isBinExp, 2, true);

        case EXP.loweredAssignExp:
            {
                // Used for changing the length of lhs.
                // While we can just walk the lowering and it'll "work",
                //  it won't be good enough.
                auto be = expr.isLoweredAssignExp;

                if (auto ale = be.e1.isArrayLengthExp)
                {
                    // See: slice.length = rhs
                    dfaCommon.printStateln("length assign lhs");
                    DFALatticeRef lhs = this.walk(ale.e1);
                    dfaCommon.printStateln("length assign rhs");
                    DFALatticeRef rhs = this.walk(be.e2);

                    DFAConsequence* lhsCctx = lhs.getContext, rhsCctx = rhs.getContext;
                    assert(lhsCctx !is null);
                    assert(rhsCctx !is null);

                    {
                        // remove anything that added to the calculation of the point analysis value
                        DFAPAValue rhsPA = rhsCctx.pa;

                        rhs = dfaCommon.makeLatticeRef;
                        rhsCctx = rhs.acquireConstantAsContext;
                        rhsCctx.pa = rhsPA;
                    }

                    // We use the rhs truthiness to model the new length
                    // If it is false, the new length is zero, and therefore null.
                    // If it is true, the new length is greater than zero, and therefore non-null.
                    int alteredState;

                    if (rhsCctx is null || rhsCctx.truthiness == Truthiness.Unknown
                            || rhsCctx.truthiness == Truthiness.Maybe)
                    {
                        alteredState = 5;
                    }
                    else
                    {
                        if (rhsCctx.truthiness == Truthiness.True)
                            alteredState = 3;
                        else
                            alteredState = 4;
                    }

                    {
                        DFAVar* lhsLengthVar = dfaCommon.findSliceLengthVar(lhsCctx.var);
                        lhs.addConsequence(lhsLengthVar, lhsCctx);
                    }

                    return this.seeAssign(lhs, false, rhs, be.loc, false, alteredState);
                }
                else
                {
                    // unknown lowered assign exp, use the lowering.
                    return this.walk(be.lowering);
                }
            }

        case EXP.add:
            return walkMathOp(expr.isBinExp, PAMathOp.add);
        case EXP.min:
            return walkMathOp(expr.isBinExp, PAMathOp.sub);
        case EXP.mul:
            return walkMathOp(expr.isBinExp, PAMathOp.mul);
        case EXP.div:
            return walkMathOp(expr.isBinExp, PAMathOp.div);
        case EXP.mod:
            return walkMathOp(expr.isBinExp, PAMathOp.mod);
        case EXP.and:
            return walkMathOp(expr.isBinExp, PAMathOp.and);
        case EXP.or:
            return walkMathOp(expr.isBinExp, PAMathOp.or);
        case EXP.xor:
            return walkMathOp(expr.isBinExp, PAMathOp.xor);
        case EXP.pow:
            return walkMathOp(expr.isBinExp, PAMathOp.pow);
        case EXP.leftShift:
            return walkMathOp(expr.isBinExp, PAMathOp.leftShift);
        case EXP.rightShift:
            return walkMathOp(expr.isBinExp, PAMathOp.rightShiftSigned);
        case EXP.unsignedRightShift:
            return walkMathOp(expr.isBinExp, PAMathOp.rightShiftUnsigned);

        case EXP.plusPlus:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.postInc);
        case EXP.minusMinus:
            return walkMathAssignOp(expr.isBinExp, PAMathOp.postDec);

        case EXP.prePlusPlus:
            DFALatticeRef effect = dfaCommon.makeLatticeRef;
            DFAConsequence* cctx = effect.acquireConstantAsContext;
            cctx.pa = DFAPAValue(1);

            return walkMathAssignOp(expr.isUnaExp, effect, PAMathOp.add);
        case EXP.preMinusMinus:
            DFALatticeRef effect = dfaCommon.makeLatticeRef;
            DFAConsequence* cctx = effect.acquireConstantAsContext;
            cctx.pa = DFAPAValue(1);

            return walkMathAssignOp(expr.isUnaExp, effect, PAMathOp.sub);

        case EXP.tilde:
            {
                auto ue = expr.isUnaExp;

                DFALatticeRef ret = this.walk(ue.e1);

                if (ret.isNull)
                {
                    ret = dfaCommon.makeLatticeRef;
                    ret.acquireConstantAsContext;
                }
                else
                {
                    DFAConsequence* cctx = ret.getContext;
                    cctx.pa.bitwiseInvert(ue.type);
                }

                return ret;
            }

        case EXP.comma:
            {
                auto ce = expr.isCommaExp;

                {
                    // We need to recognize the following AST:
                    // (((declaration), (loweredAssignExp)), (var))
                    //                   arrayLengthExp

                    auto ce2 = ce.e1.isCommaExp;
                    auto var = ce.e2.isVarExp;

                    if (ce2 !is null && var !is null)
                    {
                        auto de = ce2.e1.isDeclarationExp;
                        auto lae = ce2.e2.isLoweredAssignExp;

                        if (de !is null && lae !is null)
                        {
                            auto vd = de.declaration.isVarDeclaration;
                            auto laeLength = lae.e1.isArrayLengthExp;

                            if (var.var.isVarDeclaration is vd && laeLength !is null)
                            {
                                // (((vd), (lae)), (var))
                                //          laeLength

                                // ce.e1 can now be walked just fine, its ce.e2 that is the problem.

                                dfaCommon.printStateln("comma lhs");
                                DFALatticeRef lhs = this.walk(ce.e1);
                                dfaCommon.printStateln("comma rhs");
                                DFALatticeRef rhs = this.walk(ce.e2);

                                DFAConsequence* rhsCctx = rhs.getContext;
                                DFAConsequence* cctx = lhs.acquireConstantAsContext;

                                cctx.truthiness = rhsCctx.truthiness;
                                cctx.nullable = rhsCctx.nullable;
                                cctx.pa = rhsCctx.pa;

                                return lhs;
                            }
                        }
                    }
                }

                dfaCommon.printStateln("comma lhs");
                DFALatticeRef lhs = this.walk(ce.e1);
                dfaCommon.printStateln("comma rhs");
                DFALatticeRef rhs = this.walk(ce.e2);

                DFAVar* rhsVar = rhs.getContextVar;
                DFALatticeRef ret = this.seeLogicalAnd(lhs, rhs);

                if (rhsVar !is null)
                    ret.setContext(rhsVar);

                return ret;
            }

        case EXP.structLiteral:
            {
                auto sle = expr.isStructLiteralExp;

                if (sle.elements !is null)
                {
                    foreach (ele; *sle.elements)
                    {
                        if (ele is null)
                            continue;

                        if (auto ae = ele.isAddrExp)
                        {
                            if (auto sle2 = ae.e1.isStructLiteralExp)
                            {
                                if (sle.origin is sle2.origin)
                                    continue;
                            }
                        }

                        DFALatticeRef temp = this.walk(ele);
                        this.seeConvergeFunctionCallArgument(temp, null, 0, null, sle.loc);
                    }
                }

                DFALatticeRef ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext;
                return ret;
            }

        case EXP.tuple:
            {
                auto te = expr.isTupleExp;

                DFAVar* expectedContext;
                DFALatticeRef inProgress;

                if (te.e0 !is null)
                {
                    inProgress = this.walk(te.e0);
                    expectedContext = inProgress.getContextVar;
                }

                if (inProgress.isNull)
                    inProgress = dfaCommon.makeLatticeRef;

                if (te.exps !is null)
                {
                    foreach (exp; *te.exps)
                    {
                        inProgress = this.seeLogicalAnd(inProgress, this.walk(exp));
                    }
                }

                if (inProgress.isNull)
                    inProgress = dfaCommon.makeLatticeRef;

                DFAConsequence* c = inProgress.addConsequence(expectedContext);
                inProgress.setContext(c);

                if (expectedContext is null)
                {
                    c.nullable = Nullable.Unknown;
                    c.truthiness = Truthiness.Unknown;
                }

                return inProgress;
            }

        case EXP.question:
            {
                auto qe = expr.isCondExp;

                auto origScope = dfaCommon.currentDFAScope;
                dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
                    ob.printf("Question expression %p:%p ", dfaCommon.currentDFAScope, origScope);
                    appendLoc(ob, qe.loc);
                    ob.writestring("\n");
                });

                bool ignoreTrueBranch, ignoreFalseBranch;
                bool unknownBranchTaken;
                int predicateNegation;
                DFALatticeRef conditionLR;
                DFAVar* conditionVar;

                {
                    stmtWalker.startScope;
                    dfaCommon.currentDFAScope.sideEffectFree = true;

                    dfaCommon.printStateln("Question condition:");
                    conditionLR = this.walkCondition(qe.econd, predicateNegation);
                    conditionVar = conditionLR.getGateConsequenceVariable;

                    stmtWalker.endScope;
                }

                {
                    dfaCommon.printStateln("Question true branch:");
                    stmtWalker.startScope;
                    dfaCommon.currentDFAScope.inConditional = true;

                    DFAConsequence* c = conditionLR.getContext;
                    if (c !is null)
                    {
                        if (c.truthiness == Truthiness.False)
                            ignoreTrueBranch = true;
                        else if (c.truthiness == Truthiness.True)
                            ignoreFalseBranch = true;
                        else
                            unknownBranchTaken = true;
                    }
                    else
                        unknownBranchTaken = true;

                    DFALatticeRef trueCondition = this.adaptConditionForBranch(conditionLR.copy,
                            qe.econd.type, true);
                    this.seeSilentAssert(trueCondition, true, true);
                    stmtWalker.applyGateOnBranch(conditionVar, predicateNegation, true);
                }

                DFAScopeRef scrTrue, scrFalse;
                DFALatticeRef lrTrue, lrFalse;

                if (!ignoreTrueBranch)
                {
                    lrTrue = this.walk(qe.e1);
                    assert(dfaCommon.currentDFAScope !is origScope);
                }

                scrTrue = stmtWalker.endScope;
                scrTrue.check;

                assert(dfaCommon.currentDFAScope is origScope);

                {
                    dfaCommon.printStateln("Question false branch:");
                    stmtWalker.startScope;
                    dfaCommon.currentDFAScope.inConditional = true;

                    if (!ignoreTrueBranch)
                    {
                        DFALatticeRef falseCondition = this.adaptConditionForBranch(conditionLR.copy,
                                qe.econd.type, false);
                        this.seeSilentAssert(falseCondition, true, true);
                    }

                    stmtWalker.applyGateOnBranch(conditionVar, predicateNegation, false);

                    if (!ignoreFalseBranch)
                        lrFalse = this.walk(qe.e2);

                    scrFalse = stmtWalker.endScope;
                    scrFalse.check;
                }

                return this.seeConditional(conditionLR, scrTrue, lrTrue,
                        scrFalse, lrFalse, unknownBranchTaken, predicateNegation);
            }

        case EXP.delegate_:
        case EXP.function_:
            // known no-op
            return DFALatticeRef.init;

        case EXP.concatenate:
            {
                auto be = expr.isBinExp;
                auto beTypeBT = be.type.toBasetype;
                const lhsIsArray = be.e1.type.toBasetype.equals(beTypeBT);
                const rhsIsArray = be.e2.type.toBasetype.equals(beTypeBT);
                const op = [3, 1, 4, 0][lhsIsArray + (rhsIsArray * 2)];

                return concatenateTwo(be, op);
            }

        case EXP.vector:
        case EXP.vectorArray:
        case EXP.delegatePointer:
        case EXP.delegateFunctionPointer:
            auto ue = expr.isUnaExp;
            return this.walk(ue.e1);

        case EXP.throw_:
            auto te = expr.isThrowExp;
            dfaCommon.currentDFAScope.haveJumped = true;
            dfaCommon.currentDFAScope.haveReturned = true;
            return this.walk(te.e1);

        case EXP.type:
            // holds a type, known no-op
            return DFALatticeRef.init;

        case EXP.reserved:

            // Other
        case EXP.is_: //is()
        case EXP.array:
        case EXP.delete_:
        case EXP.dotIdentifier:
        case EXP.dotTemplateInstance:
        case EXP.dotType:
        case EXP.dollar:
        case EXP.template_:
        case EXP.dotTemplateDeclaration:
        case EXP.dSymbol:
        case EXP.uadd:
        case EXP.remove:
        case EXP.newAnonymousClass:
        case EXP.classReference:
        case EXP.thrownException:

            // Operators

        case EXP.dot:

            // Leaf operators
        case EXP.identifier:
        case EXP.interpolated:
        case EXP.super_:
        case EXP.error:

        case EXP.import_:
        case EXP.mixin_:
        case EXP.break_:
        case EXP.continue_:
        case EXP.goto_:
        case EXP.scope_:

        case EXP.traits:
        case EXP.overloadSet:
        case EXP.line:
        case EXP.file:
        case EXP.fileFullPath:
        case EXP.moduleString: // __MODULE__
        case EXP.functionString: // __FUNCTION__
        case EXP.prettyFunction: // __PRETTY_FUNCTION__

        case EXP.voidExpression:
        case EXP.cantExpression:
        case EXP.showCtfeContext:
        case EXP.objcClassReference:
        case EXP.compoundLiteral: // ( type-name ) { initializer-list }
        case EXP._Generic:
        case EXP.interval:

        case EXP.rvalue:
            if (dfaCommon.debugUnknownAST)
            {
                fprintf(stderr, "Unknown DFA walk expression %d at %s\n",
                        expr.op, expr.loc.toChars);
                assert(0);
            }
            else
                return DFALatticeRef.init;
        }
    }

    /// Walks an expression that is used for a condition i.e. and if statement.
    /// Tells you if the expression for the gate variable, will be exact, vs negated state.
    /// Applying by test is for when (expr) > 0, use 0 for unknown, 1 is <= 0 and 2 is > 0
    /// Returns: 0 for unknown negation, 1 or has been negated from gate variable or 2 if it hasn't been.
    DFALatticeRef walkCondition(Expression expr, out int predicateNegation)
    {
        bool allGateConditional = true;
        bool outComeNegated;

        dfaCommon.edepth++;

        scope (exit)
        {
            dfaCommon.edepth--;

            if (!allGateConditional)
                predicateNegation = 0;
            else
                predicateNegation = outComeNegated ? 1 : 2;
        }

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("[%p]%3d walkCondition (%s): at ", expr, expr.op,
                AllExprOpNames[expr.op].ptr);
            appendLoc(ob, expr.loc);
            ob.writestring("\n");
        });

        int negateApplyByTest(int val)
        {
            if (val == 1)
                return 2;
            else if (val == 2)
                return 1;
            else
                return 0;
        }

        bool canBeInverted(Expression expr)
        {
            switch (expr.op)
            {

            case EXP.typeid_:
            case EXP.arrayLiteral:
            case EXP.assocArrayLiteral:
            case EXP.arrayLength:
            case EXP.null_:
            case EXP.cast_:
            case EXP.variable:
            default:
                return false;

            case EXP.int64:
            case EXP.string_:
                return true;

            case EXP.not: // !x
                auto ue = expr.isUnaExp;
                if (ue.e1.isInExp)
                    return false;
                return canBeInverted(ue.e1);

            case EXP.orOr:
            case EXP.notEqual: // !=
            case EXP.notIdentity: // !is
            case EXP.equal: // ==
            case EXP.identity: // is
            case EXP.lessThan:
            case EXP.lessOrEqual:
            case EXP.greaterThan:
            case EXP.greaterOrEqual:
                auto be = expr.isBinExp;
                return canBeInverted(be.e1) && canBeInverted(be.e2);
            }
        }

        DFALatticeRef seeExp(Expression expr, ref bool negated, int applyByTest)
        {
            dfaCommon.check;
            dfaCommon.edepth++;
            scope (exit)
            {
                dfaCommon.check;
                dfaCommon.edepth--;
            }

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("[%p]%3d walkCondition.seeExp (%s): at ", expr,
                    expr.op, AllExprOpNames[expr.op].ptr);
                appendLoc(ob, expr.loc);
                ob.writestring("\n");
            });

            switch (expr.op)
            {
            case EXP.not: // !x
            {
                    negated = !negated; // !!x
                    auto ue = expr.isUnaExp;

                    if (auto ie = ue.e1.isInExp)
                    {
                        allGateConditional = false;

                        DFALatticeRef lhs = seeExp(ie.e1, negated, 0);
                        lhs.check;

                        DFALatticeRef rhs = seeExp(ie.e2, negated, 0);
                        rhs.check;

                        DFAVar* rhsVar = rhs.getContextVar;

                        // change comparison to: lhs in rhs[...]
                        if (rhsVar !is null)
                            rhs.setContext(dfaCommon.findIndexVar(rhsVar));

                        return this.seeEqual(lhs, rhs, false, ie.e1.type, ie.e2.type);
                    }
                    else
                    {
                        DFALatticeRef lr = seeExp(ue.e1, negated, negateApplyByTest(applyByTest));
                        return (applyByTest != 0) ? lr : seeNegate(lr, ue.type);
                    }
                }

            case EXP.notEqual: // !=
            {
                    negated = !negated;
                    auto be = expr.isBinExp;

                    bool negated2;

                    dfaCommon.printStateln("!equal lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2, 0);
                    dfaCommon.printStateln("!equal rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2, 0);

                    return seeEqual(lhs, rhs, applyByTest == 2, be.e1.type, be.e2.type);
                }

            case EXP.notIdentity: // !is
            {
                    negated = !negated;
                    auto be = expr.isBinExp;

                    bool negated2;

                    dfaCommon.printStateln("!is lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2, 0);
                    dfaCommon.printStateln("!is rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2, 0);

                    return seeEqualIdentity(lhs, rhs, applyByTest == 2, be.e1.type, be.e2.type);
                }

            case EXP.equal: // ==
            {
                    auto be = expr.isBinExp;
                    bool negated2;

                    dfaCommon.printStateln("equal lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2, 0);
                    dfaCommon.printStateln("equal rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2, 0);

                    return seeEqual(lhs, rhs, applyByTest != 1, be.e1.type, be.e2.type);
                }

            case EXP.identity: // is
            {
                    auto be = expr.isBinExp;
                    bool negated2;

                    dfaCommon.printStateln("is lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2, 0);
                    dfaCommon.printStateln("is rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2, 0);

                    return seeEqualIdentity(lhs, rhs, applyByTest != 1, be.e1.type, be.e2.type);
                }

            case EXP.string_:
                {
                    auto se = expr.isStringExp;

                    // A string literal even when empty will be non-null and true.
                    DFALatticeRef ret = dfaCommon.makeLatticeRef;

                    DFAVar* var = dfaCommon.getInfiniteLifetimeVariable;
                    DFAConsequence* cctx = ret.addConsequence(var);
                    ret.setContext(cctx);

                    cctx.truthiness = se.len > 0 ? Truthiness.True : Truthiness.Maybe;
                    cctx.nullable = Nullable.NonNull;
                    cctx.obj = dfaCommon.makeObject;
                    cctx.pa = DFAPAValue(se.len);
                    return ret;
                }

            case EXP.typeid_:
                {
                    auto te = expr.isTypeidExp;
                    DFALatticeRef ret;

                    void seeTypeIdObject(RootObject ro)
                    {
                        if (auto e = isExpression(te.obj))
                        {
                            // [!val] does not effect the literal, gate capabilitiy
                            DFALatticeRef temp = seeExp(e, negated, 0);

                            if (!ret.isNull)
                                ret = this.seeLogicalAnd(ret, temp);
                            else
                                ret = temp;
                        }
                        else if (auto v = isTuple(te.obj))
                        {
                            foreach (obj; v.objects)
                            {
                                seeTypeIdObject(obj);
                            }
                        }
                    }

                    seeTypeIdObject(te.obj);

                    if (ret.isNull)
                        ret = dfaCommon.makeLatticeRef;

                    DFAVar* var = dfaCommon.getInfiniteLifetimeVariable;
                    DFAConsequence* cctx = ret.addConsequence(var);
                    ret.setContext(cctx);

                    cctx.truthiness = Truthiness.True;
                    cctx.nullable = Nullable.NonNull;
                    cctx.obj = dfaCommon.makeObject;
                    return ret;
                }

            case EXP.arrayLiteral:
                {
                    auto ale = expr.isArrayLiteralExp;
                    DFALatticeRef ret = dfaCommon.makeLatticeRef;

                    if (ale.elements !is null && ale.elements.length > 0)
                    {
                        foreach (ele; *ale.elements)
                        {
                            if (ele !is null)
                                this.seeConvergeFunctionCallArgument(seeExp(ele,
                                        negated, 0), null, 0, null, ele.loc);
                        }

                        DFAVar* var = dfaCommon.getInfiniteLifetimeVariable;
                        DFAConsequence* cctx = ret.addConsequence(var);
                        ret.setContext(cctx);

                        cctx.truthiness = Truthiness.True;
                        cctx.nullable = Nullable.NonNull;
                        cctx.pa = DFAPAValue(ale.elements.length);
                        cctx.obj = dfaCommon.makeObject;
                    }
                    else
                        ret.acquireConstantAsContext(Truthiness.Maybe, Nullable.Null, null);

                    return ret;
                }

            case EXP.assocArrayLiteral:
                {
                    auto aale = expr.isAssocArrayLiteralExp;
                    DFALatticeRef ret = dfaCommon.makeLatticeRef;

                    if (aale.keys !is null && aale.keys.length > 0)
                    {
                        DFAVar* var = dfaCommon.getInfiniteLifetimeVariable;
                        DFAConsequence* cctx = ret.addConsequence(var);
                        ret.setContext(cctx);

                        cctx.truthiness = Truthiness.True;
                        cctx.nullable = Nullable.NonNull;
                        cctx.obj = dfaCommon.makeObject;
                    }
                    else
                        ret.acquireConstantAsContext(Truthiness.False, Nullable.Null, null);

                    return ret;
                }

            case EXP.arrayLength:
                {
                    // This is supposed to be a read only,
                    // Lowered assign expression will handle the write version.

                    auto ue = expr.isUnaExp;

                    DFALatticeRef ret = seeExp(ue.e1, negated, 0);
                    DFAConsequence* cctx = ret.getContext;

                    if (ret.isNull)
                    {
                        ret = dfaCommon.makeLatticeRef;
                        ret.acquireConstantAsContext;
                    }
                    else if (cctx is null || cctx.var is null)
                        ret.acquireConstantAsContext;
                    else
                    {
                        DFAVar* ctx = dfaCommon.findSliceLengthVar(cctx.var);

                        DFAConsequence* newCctx = ret.addConsequence(ctx);
                        newCctx.truthiness = cctx.truthiness;
                        newCctx.pa = cctx.pa;
                        newCctx.maybe = cctx.var;

                        ret.setContext(newCctx);
                    }

                    return ret;
                }

            case EXP.null_:
                {
                    DFALatticeRef ret = dfaCommon.makeLatticeRef;

                    DFAConsequence* c = ret.addConsequence(null);
                    ret.setContext(c);

                    c.truthiness = Truthiness.False;
                    c.nullable = Nullable.Null;
                    c.pa = DFAPAValue(0);

                    return ret;
                }

            case EXP.int64:
                {
                    auto ie = expr.isIntegerExp;

                    auto b = ie.toBool;
                    if (!b.isPresent)
                        return DFALatticeRef.init;

                    DFALatticeRef ret = dfaCommon.makeLatticeRef;
                    DFAConsequence* c = ret.addConsequence(null);
                    ret.setContext(c);

                    auto ty = ie.type.toBasetype().ty;

                    if (ty != Tpointer)
                    {
                        c.pa = DFAPAValue(0);
                        const value = ie.getInteger();

                        switch (ty)
                        {
                        case Tbool:
                            c.pa.value = value != 0;
                            break;

                        case Tint8:
                            c.pa.value = cast(byte) value;
                            break;

                        case Tchar:
                        case Tuns8:
                            c.pa.value = cast(ubyte) value;
                            break;

                        case Tint16:
                            c.pa.value = cast(short) value;
                            break;

                        case Twchar:
                        case Tuns16:
                            c.pa.value = cast(ushort) value;
                            break;

                        case Tint32:
                            c.pa.value = cast(int) value;
                            break;

                        case Tdchar:
                        case Tuns32:
                            c.pa.value = cast(uint) value;
                            break;

                        case Tint64:
                            c.pa.value = cast(long) value;
                            break;

                        case Tuns64:
                            c.pa.value = cast(ulong) value;

                            if (value > long.max)
                                c.pa.kind = DFAPAValue.Kind.UnknownUpperPositive;
                            break;

                        default:
                            printf("integer type %d\n", ty);
                            assert(0, "Unknown integer type");
                        }

                        c.truthiness = c.pa.value > 0 ? Truthiness.True : Truthiness.False;
                    }

                    return ret;
                }

            case EXP.cast_:
                {
                    auto ce = expr.isCastExp;

                    dfaCommon.printState((ref OutBuffer ob,
                            scope PrintPrefixType prefix) => ob.printf("cast to %d\n",
                            ce.to !is null ? ce.to.ty : -1));

                    DFALatticeRef ret = seeExp(ce.e1, negated, 0);
                    ret.check;

                    if (ce.to is null || ce.to.isTypeClass || ce.to is Type.tvoid)
                    {
                        // For classes: ideally we'd model up casts, and only disallow down casts
                        // For void: no side effects wrt. convergance

                        ret = dfaCommon.makeLatticeRef;
                        ret.acquireConstantAsContext(Truthiness.Unknown, Nullable.Unknown, null);
                    }
                    else
                    {
                        if (ret.isNull)
                            ret = dfaCommon.makeLatticeRef;

                        bool paHandled;

                        DFAVar* baseVar;
                        DFAConsequence* cctx = ret.getContext(baseVar);
                        if (cctx is null)
                            cctx = ret.acquireConstantAsContext;

                        if (baseVar !is null)
                        {
                            if (baseVar.isNullable && !isTypeNullable(ce.to))
                            {
                                // This prevents pointer integer checks from infecting pointers

                                cctx = ret.acquireConstantAsContext(cctx.truthiness,
                                        cctx.nullable, null);
                            }
                            else if (baseVar.isStaticArray && ce.to.isTypeDArray)
                            {
                                DFAVar* asSliceVar = dfaCommon.findAsSliceVar(baseVar);

                                Truthiness truthiness = cctx.truthiness;
                                DFAPAValue oldPA = cctx.pa;
                                DFAObject* newObj = cctx.obj !is null ? cctx.obj
                                    : dfaCommon.makeObject(baseVar);

                                cctx = ret.addConsequence(asSliceVar);
                                ret.setContext(cctx);

                                cctx.nullable = Nullable.NonNull;
                                cctx.truthiness = truthiness;
                                cctx.pa = oldPA;
                                cctx.obj = newObj;
                            }
                        }

                        // If we're doing any kind of cast to anything that is not an integer,
                        //  we have no idea if VRP is going to still be accurate.
                        if (!paHandled && !cctx.pa.canFitIn(ce.to))
                            cctx.pa = DFAPAValue.Unknown;
                    }

                    return ret;
                }

            case EXP.variable:
                {
                    auto ve = expr.isVarExp;
                    assert(ve !is null);

                    DFALatticeRef ret;

                    if (ve.var !is null)
                    {
                        if (auto vd = ve.var.isVarDeclaration)
                        {
                            if (vd.ident is Id.withSym)
                            {
                                // Copied from function semantic analysis checkNestedReference function.
                                // With statements sometimes have temporaries that do get written out,
                                //  pretend we're the initializer instead.

                                auto ez = vd._init.isExpInitializer();
                                assert(ez);

                                Expression e = ez.exp;
                                if (e.op == EXP.construct || e.op == EXP.blit)
                                    e = (cast(AssignExp) e).e2;

                                return this.walk(e);
                            }

                            DFAVar* var = dfaCommon.findVariable(vd);

                            if (var !is null)
                            {
                                ret = dfaCommon.acquireLattice(var);
                                ret.check;
                                assert(!ret.isNull);

                                if (applyByTest != 0)
                                {
                                    DFAConsequence* cctx = ret.getContext;
                                    assert(cctx !is null);

                                    if (var.isNullable && cctx.nullable == Nullable.Unknown)
                                        cctx.nullable = applyByTest == 2
                                            ? Nullable.NonNull : Nullable.Null;

                                    if (var.isTruthy && cctx.truthiness == Truthiness.Unknown)
                                        cctx.truthiness = applyByTest == 2
                                            ? Truthiness.True : Truthiness.False;
                                }

                                return ret;
                            }
                        }
                    }

                    // no other declarations really apply for the DFA
                    ret = dfaCommon.makeLatticeRef;
                    ret.setContext(dfaCommon.getUnknownVar);

                    return ret;
                }

            default:
                allGateConditional = false;
                return this.walk(expr);
            }
        }

        DFALatticeRef seeExpInOr(Expression expr, bool invert)
        {
            dfaCommon.check;
            dfaCommon.edepth++;
            scope (exit)
            {
                dfaCommon.check;
                dfaCommon.edepth--;
            }

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("[%p]%3d walkCondition.seeExpInOr (%s): at ", expr,
                    expr.op, AllExprOpNames[expr.op].ptr);
                appendLoc(ob, expr.loc);
                ob.writestring("\n");
            });

            switch (expr.op)
            {
            case EXP.orOr:
                int predicateNegation;
                DFALatticeRef ret = walkCondition(expr.isLogicalExp, predicateNegation);
                if (invert)
                    return this.seeNegate(ret, expr.type);
                else
                    return ret;

            case EXP.lessThan:
                if (invert)
                    goto GreaterThan;
            LessThan:
                // < becomes >
                auto be = expr.isBinExp;
                bool negated;

                DFALatticeRef lhs = seeExp(be.e2, negated, 0);
                DFALatticeRef rhs = seeExp(be.e1, negated, 0);
                return this.seeGreaterThan(false, lhs, rhs);

            case EXP.lessOrEqual:
                if (invert)
                    goto GreaterThanEqual;
            LessThanEqual:
                // <= becomes >=
                auto be = expr.isBinExp;
                bool negated;

                DFALatticeRef lhs = seeExp(be.e2, negated, 0);
                DFALatticeRef rhs = seeExp(be.e1, negated, 0);
                return this.seeGreaterThan(true, lhs, rhs);

            case EXP.greaterThan:
                if (invert)
                    goto LessThan;
            GreaterThan:
                auto be = expr.isBinExp;
                bool negated;

                DFALatticeRef lhs = seeExp(be.e1, negated, 0);
                DFALatticeRef rhs = seeExp(be.e2, negated, 0);
                return this.seeGreaterThan(false, lhs, rhs);

            case EXP.greaterOrEqual:
                if (invert)
                    goto LessThanEqual;
            GreaterThanEqual:
                auto be = expr.isBinExp;
                bool negated;

                DFALatticeRef lhs = seeExp(be.e1, negated, 0);
                DFALatticeRef rhs = seeExp(be.e2, negated, 0);
                return this.seeGreaterThan(true, lhs, rhs);

            default:
                bool negated;
                return seeExp(expr, negated, invert ? 1 : 2);
            }
        }

        // In theory a gate condition can support more expressions, but to be on the safe side, let's call this good.
        switch (expr.op)
        {
        case EXP.not: // !x
        case EXP.variable:
        case EXP.cast_:
        case EXP.null_:
        case EXP.int64:
        case EXP.arrayLength:
        case EXP.string_:
        case EXP.typeid_:
        case EXP.arrayLiteral:
        case EXP.assocArrayLiteral:
        case EXP.equal: // ==
        case EXP.identity: // is
        case EXP.notEqual: // !=
        case EXP.notIdentity: // !is
            return seeExp(expr, outComeNegated, 0);

        case EXP.orOr:
            {
                const canThisBeInverted = canBeInverted(expr);
                auto oe = expr.isLogicalExp;
                DFALatticeRef inProgress;

                stmtWalker.startScope;
                dfaCommon.currentDFAScope.sideEffectFree = true;
                scope (exit)
                    stmtWalker.endScope;

                while (oe !is null)
                {
                    DFALatticeRef lhs;
                    DFALatticeRef toNegate;

                    {
                        // Make sure any effects converged into the scope by and expressions ext. don't effect rhs
                        stmtWalker.startScope;
                        dfaCommon.currentDFAScope.sideEffectFree = true;

                        if (canThisBeInverted)
                        {
                            dfaCommon.printStructureln("Or expression lhs:");

                            lhs = seeExpInOr(oe.e1, false);
                        }
                        else
                        {
                            dfaCommon.printStructureln("Or expression lhs walk-adapt:");
                            lhs = this.walk(oe.e1);
                            toNegate = this.adaptConditionForBranch(lhs.copy, oe.e1.type, false);
                        }

                        seeRead(lhs, oe.e1.loc);
                        lhs.printState("or lhs", dfaCommon.sdepth,
                                dfaCommon.currentFunction, dfaCommon.edepth);

                        stmtWalker.endScope;

                        if (inProgress.isNull)
                            inProgress = lhs;
                        else
                            inProgress = seeLogicalOr(inProgress, lhs);
                    }

                    if (toNegate.isNull)
                    {
                        dfaCommon.printStructureln("Or expression lhs inverted:");
                        this.seeSilentAssert(seeExpInOr(oe.e1, true));
                    }
                    else
                    {
                        this.seeSilentAssert(toNegate, false, true);
                    }

                    if (oe.e2.op == EXP.orOr)
                    {
                        oe = oe.e2.isLogicalExp;
                        continue;
                    }
                    else
                    {
                        // Make sure any effects converged into the scope by and expressions ext. don't effect rhs or return
                        stmtWalker.startScope;
                        dfaCommon.currentDFAScope.sideEffectFree = true;

                        // e2 is the right most or expression in chain (a || b || c) where it is c
                        dfaCommon.printStructureln("Or expression rhs:");
                        // don't care about seeExpInOr here, can just do a normal walk
                        DFALatticeRef rhs = this.walk(oe.e2);
                        rhs.printState("or rhs", dfaCommon.sdepth,
                                dfaCommon.currentFunction, dfaCommon.edepth);
                        seeRead(rhs, oe.e2.loc);

                        stmtWalker.endScope;

                        inProgress = seeLogicalOr(inProgress, rhs);
                        break;
                    }
                }

                return inProgress;
            }

        default:
            return this.walk(expr);
        }
    }

    DFALatticeRef walkMathOp(BinExp be, PAMathOp op)
    {
        dfaCommon.printStateln("math op lhs");
        DFALatticeRef lhs = this.walk(be.e1);
        seeReadMathOp(lhs, be.e1.loc);
        lhs.check;

        dfaCommon.printStateln("math op rhs");
        DFALatticeRef rhs = this.walk(be.e2);
        seeReadMathOp(rhs, be.e2.loc);
        rhs.check;

        DFALatticeRef ret = this.seeMathOp(lhs, rhs, be.type, op);
        ret.check;
        return ret;
    }

    DFALatticeRef walkMathAssignOp(BinExp be, PAMathOp op)
    {
        dfaCommon.printStateln("math assign1 op lhs");
        DFALatticeRef lhs = this.walk(be.e1);
        assert(!lhs.isNull);
        lhs.check;

        DFAConsequence* lhsCctx = lhs.getContext;
        assert(lhsCctx !is null);

        dfaCommon.printStateln("math assign1 op rhs");
        DFALatticeRef rhs = this.walk(be.e2);
        rhs.check;
        seeReadMathOp(rhs, be.e2.loc);

        DFAPAValue oldPA;
        bool useOldPA;

        if (op == PAMathOp.postInc)
        {
            op = PAMathOp.add;
            useOldPA = true;
            oldPA = lhsCctx.pa;
        }
        else if (op == PAMathOp.postDec)
        {
            op = PAMathOp.sub;
            useOldPA = true;
            oldPA = lhsCctx.pa;
        }

        DFAObject* lhsObject = lhsCctx.obj;
        DFALatticeRef ret = this.seeMathOp(lhs.copy, rhs, be.type, op);
        ret.check;

        ret = this.seeAssign(lhs, false, ret, be.loc);
        ret.check;

        {
            DFAConsequence* cctx;

            if (useOldPA)
            {
                cctx = ret.acquireConstantAsContext;
                cctx.pa = oldPA;
            }
            else
                cctx = ret.getContext;

            cctx.obj = lhsObject;

            if (lhsObject !is null)
                lhsObject.mayNotBeExactPointer = true;
        }

        return ret;
    }

    DFALatticeRef walkMathAssignOp(UnaExp ue, DFALatticeRef rhs, PAMathOp op)
    {
        dfaCommon.printStateln("math assign2 op lhs");
        DFALatticeRef lhs = this.walk(ue.e1);
        assert(!lhs.isNull);
        lhs.check;

        DFAConsequence* lhsCctx = lhs.getContext;
        assert(lhsCctx !is null);
        DFAObject* lhsObject = lhsCctx.obj;

        DFALatticeRef ret = this.seeMathOp(lhs.copy, rhs, ue.type, op);
        ret.check;
        seeReadMathOp(rhs, ue.loc);

        ret = this.seeAssign(lhs, false, ret, ue.loc);
        ret.check;

        DFAConsequence* cctx = ret.getContext;
        cctx.obj = lhsObject;

        if (lhsObject !is null)
            lhsObject.mayNotBeExactPointer = true;

        ret.printStructure("math assign2 ret");
        return ret;
    }

    DFALatticeRef callFunction(FuncDeclaration toCallFunction, Expression thisPointer,
            Expression argPrefix, Expressions* arguments, ref Loc loc)
    {
        TypeFunction toCallFunctionType = toCallFunction !is null ? toCallFunction
            .type.isFunction_Delegate_PtrToFunction : null;

        if (thisPointer !is null)
        {
            // Extract from the this pointer expression the function to call.

            if (auto dve = thisPointer.isDotVarExp)
            {
                if (auto fd = dve.var.isFuncDeclaration)
                {
                    // e1.method()
                    thisPointer = dve.e1;
                    toCallFunction = fd;
                    toCallFunctionType = toCallFunction.type.isFunction_Delegate_PtrToFunction;
                }
            }
            else if (auto ve = thisPointer.isVarExp)
            {
                // method()
                thisPointer = null;
                toCallFunctionType = ve.var.type.isFunction_Delegate_PtrToFunction;
            }
        }

        if (toCallFunction !is null && toCallFunction.ident !is null)
        {
            dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("Calling function `%s` at ", toCallFunction.ident.toChars);
                appendLoc(ob, loc);
                ob.writestring(" from ");
                appendLoc(ob, toCallFunction.loc);
                ob.writestring("\n");
            });
        }
        else if (loc.isValid)
        {
            dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.writestring("Calling function at ");
                appendLoc(ob, loc);

                if (toCallFunction !is null)
                {
                    ob.writestring(" from ");
                    appendLoc(ob, toCallFunction.loc);
                }

                ob.writestring("\n");
            });
        }
        else
            dfaCommon.printStateln("Calling function");

        const functionIsNoReturn = (toCallFunction !is null && toCallFunction.noreturn) || (toCallFunctionType !is null
                && toCallFunctionType.next !is null
                && toCallFunctionType.next.isTypeNoreturn !is null);

        {
            ParametersDFAInfo* calledFunctionInfo;
            ParameterDFAInfo* thisPointerInfo;
            ParameterDFAInfo* returnInfo;

            if (toCallFunction !is null && toCallFunction.parametersDFAInfo)
            {
                calledFunctionInfo = toCallFunction.parametersDFAInfo;
                thisPointerInfo = &calledFunctionInfo.thisPointer;
                returnInfo = &calledFunctionInfo.returnValue;
            }

            stmtWalker.startScope;
            dfaCommon.currentDFAScope.sideEffectFree = true;

            if (thisPointer !is null)
            {
                dfaCommon.printStateln("This:");
                DFALatticeRef thisExp = this.walk(thisPointer);

                if (isTypeNullable(thisPointer.type))
                    thisExp = this.seeDereference(thisPointer.loc, thisExp);

                this.seeConvergeFunctionCallArgument(thisExp, thisPointerInfo,
                        0, toCallFunction, thisPointer.loc);
            }

            if (argPrefix !is null)
            {
                dfaCommon.printStateln("Argument prefix:");
                DFALatticeRef argPrefixLR = this.walk(argPrefix);
                this.seeConvergeFunctionCallArgument(argPrefixLR, null, 0,
                        toCallFunction, argPrefix.loc);
            }

            if (arguments !is null && arguments.length > 0)
            {
                Parameter[] allParameters;
                VarDeclaration[] allParameterVars;
                ParameterDFAInfo[] allInfos = calledFunctionInfo !is null ? calledFunctionInfo.parameters
                    : null;

                if (toCallFunctionType !is null)
                {
                    TypeFunction functionType = toCallFunctionType.toTypeFunction;

                    if (functionType.parameterList.parameters !is null
                            && functionType.parameterList.parameters.length != 0)
                    {
                        allParameters = (*functionType.parameterList.parameters)[];
                    }
                }

                if (toCallFunction !is null)
                {
                    if (toCallFunction.parameters !is null && toCallFunction.parameters.length != 0)
                    {
                        allParameterVars = (*toCallFunction.parameters)[];
                    }
                }

                dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
                    ob.writestring("Calling function parameter info\n");

                    prefix("    ");
                    ob.printf("count=%zd, calledFunctionInfo=%p:%zd\n", arguments.length, calledFunctionInfo,
                        calledFunctionInfo !is null ? calledFunctionInfo.parameters.length : 0);

                    prefix("    ");
                    ob.printf("allParameters=%zd, allParameterVars=%zd\n",
                        allParameters.length, allParameterVars.length);
                });

                foreach (i, arg; *arguments)
                {
                    Parameter* param = i < allParameters.length ? &allParameters.ptr[i] : null;
                    VarDeclaration paramVar = i < allParameterVars.length
                        ? allParameterVars.ptr[i] : null;
                    const storageClass = (param !is null ? param.storageClass : 0) | (paramVar !is null
                            ? paramVar.storage_class : 0);
                    ParameterDFAInfo* info = i < allInfos.length ? &allInfos.ptr[i] : null;

                    dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
                        ob.printf("Argument %zd, stc=%lld", i, storageClass);
                        ob.writestring("\n");

                        if (info !is null)
                        {
                            ob.printf("    info %d:%d", info.notNullIn, info.notNullOut);
                            ob.writestring("\n");
                        }
                    });

                    DFALatticeRef argExp = this.walk(arg);
                    this.seeConvergeFunctionCallArgument(argExp, info,
                            storageClass, toCallFunction, loc);

                    if (dfaCommon.currentDFAScope.haveJumped)
                        break;
                }
            }

            stmtWalker.endScope;

            {
                DFALatticeRef ret = dfaCommon.makeLatticeRef;

                if (returnInfo !is null && returnInfo.notNullOut == Fact.Guaranteed)
                    ret.acquireConstantAsContext(Truthiness.True,
                            Nullable.NonNull, dfaCommon.makeObject);
                else
                    ret.acquireConstantAsContext;

                // If the function is no return, or it hasn't been semantically analysed yet,
                //  we'll assume it can't return.
                // Otherwise we get false positives.
                if (functionIsNoReturn)
                {
                    dfaCommon.currentDFAScope.haveJumped = true;
                    dfaCommon.currentDFAScope.haveReturned = true;
                }

                return ret;
            }
        }
    }

    DFALatticeRef concatenateTwo(BinExp be, int op, bool assign = false)
    {
        // Whatever lhs started out as, it'll be non-null once we're done with it.

        const nullableResult = concatNullableResult(be.e1.type, be.e2.type);
        dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) => ob.printf(
                "concat nullableResult=%d, op=%d\n", nullableResult, op));

        dfaCommon.printStateln("concat lhs");
        DFALatticeRef lhs = this.walk(be.e1);
        dfaCommon.printStateln("concat rhs");
        DFALatticeRef rhs = this.walk(be.e2);

        DFAConsequence* lhsCctx = lhs.getContext, rhsCctx = rhs.getContext;

        if (lhsCctx is null || rhsCctx is null)
        {
            // We can't analyse this.
            return DFALatticeRef.init;
        }

        DFAPAValue pa;

        if (op == 0)
        {
            // T[] ~ T[]
            pa = rhsCctx.pa;
            pa.addFrom(lhsCctx.pa, Type.tuns64);
        }
        else if (op == 1)
        {
            // T[] ~ T
            pa = lhsCctx.pa;
            pa.addFrom(DFAPAValue(1), Type.tuns64);
        }
        else if (op == 2)
        {
            // T[] ~ dchar
            // We have no idea how many code units the dchar will encode as
            pa = DFAPAValue.Unknown;
        }
        else if (op == 3)
        {
            // T ~ T
            pa = DFAPAValue(2);
        }
        else if (op == 4)
        {
            // T ~ T[]
            pa = rhsCctx.pa;
            pa.addFrom(DFAPAValue(1), Type.tuns64);
        }

        DFALatticeRef ret;

        if (assign)
        {
            rhsCctx.pa = pa;
            ret = this.seeAssign(lhs, false, rhs, be.loc, false,
                    nullableResult == 1 || nullableResult == 2 ? 3 : 0);
        }
        else
        {

            Truthiness expectedTruthiness;
            Nullable expectedNullable;

            if (nullableResult == 2)
            {
                expectedTruthiness = Truthiness.True;
                expectedNullable = Nullable.NonNull;
            }
            else if (nullableResult == 1)
            {
                expectedNullable = lhsCctx.nullable;
                if (expectedNullable < rhsCctx.nullable)
                    expectedNullable = rhsCctx.nullable;

                if (expectedNullable == Nullable.NonNull)
                    expectedTruthiness = Truthiness.True;
            }

            ret = this.seeLogicalAnd(lhs, rhs);
            DFAConsequence* cctx = ret.acquireConstantAsContext;

            cctx.truthiness = expectedTruthiness;
            cctx.nullable = expectedNullable;
            cctx.pa = pa;
        }

        return ret;
    }

    void markUnmodellable(Expression e)
    {
        void perVar(VarDeclaration vd)
        {
            DFAVar* var = dfaCommon.findVariable(vd);
            if (var !is null)
                var.unmodellable = true;
        }

        void perExpr(Expression expr)
        {
            if (auto ve = expr.isVarExp)
            {
                if (auto vd = ve.var.isVarDeclaration)
                    perVar(vd);
            }
            else if (auto be = expr.isBinExp)
            {
                perExpr(be.e1);
                perExpr(be.e2);
            }
            else if (auto ue = expr.isUnaExp)
            {
                perExpr(ue.e1);
            }
        }

        perExpr(e);
    }
}
