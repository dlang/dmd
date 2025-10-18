/**
 * Expression walker for the fast Data Flow Analysis engine.
 *
 * Copyright: Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
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
import dmd.astenums;
import dmd.tokens;
import dmd.func;
import dmd.declaration;
import dmd.mtype;
import dmd.dtemplate;
import dmd.arraytypes;
import dmd.rootobject;
import core.stdc.stdio;

struct ExpressionWalker
{
    DFACommon* dfaCommon;
    StatementWalker stmtWalker;
    DFAAnalyzer* analyzer;

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

    DFALatticeRef seeAssign(DFAVar* assignTo, bool construct, DFALatticeRef lr,
            bool isBlit = false, int alteredState = 0)
    {
        DFALatticeRef assignTo2 = dfaCommon.makeLatticeRef;
        assignTo2.setContext(assignTo);

        dfaCommon.check;
        DFALatticeRef ret = seeAssign(assignTo2, construct, lr, isBlit);
        dfaCommon.check;

        return ret;
    }

    DFALatticeRef seeAssign(DFALatticeRef assignTo, bool construct, DFALatticeRef lr,
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
                isBlit, lr, alteredState, indexLR);
        dfaCommon.check;

        ret.check;
        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

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
        DFALatticeRef ret = analyzer.transferEqual(lhs, rhs, truthiness, equalityType);
        dfaCommon.check;

        ret.printState("result", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return ret;
    }

    DFALatticeRef seeNegate(DFALatticeRef lr, bool protectElseNegate = false)
    {
        lr.printState("Negate", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);
        return analyzer.transferNegate(lr, protectElseNegate);
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

    DFALatticeRef entry(DFAVar* assignTo, DFAVar* constructInto, Expression exp)
    {
        DFALatticeRef lattice = walk(exp);
        lattice.check;

        if (assignTo !is null)
            return seeAssign(assignTo, false, lattice);
        else if (constructInto !is null)
            return seeAssign(constructInto, true, lattice);
        else
            return lattice;
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
            against.acquireConstantAsContext(Truthiness.True, Nullable.NonNull);

            ret = this.seeEqual(ret, against, truthiness, type, null);
        }
        else if (!truthiness)
        {
            if ((cctx = ret.getGateConsequence) !is null)
            {
                ret.setContext(cctx);
                ret = this.seeNegate(ret);
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

    DFALatticeRef walk(Expression expr)
    {
        if (expr is null || dfaCommon.currentDFAScope.haveJumped)
            return DFALatticeRef.init;

        __gshared immutable(string[]) AllExprOpNames = [
            __traits(allMembers, EXP)
        ];

        dfaCommon.edepth++;
        dfaCommon.check;

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("[%p]%3d (%s): at ", expr, expr.op, AllExprOpNames[expr.op].ptr);
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
            }
            else if (auto fd = soe.var.isFuncDeclaration)
            {
                // For some reason, sometimes people like to do an offset that isn't zero for functions.
                // So we'll ignore that and assume the offset is "right",
                //  even if it probably doesn't make sense to be doing it.

                ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext(Truthiness.True, Nullable.NonNull);
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
                    ret.setContext(varOffset);
                }
            }

            return ret;

        case EXP.declaration:
            auto decl = expr.isDeclarationExp.declaration;

            if (auto var = decl.isVarDeclaration)
            {
                DFAVar* dfaVar = dfaCommon.findVariable(var);
                dfaVar.declaredAtDepth = dfaCommon.currentDFAScope.depth;
                dfaCommon.acquireScopeVar(dfaVar);

                if (var._init is null)
                {
                    // we can ignore this case, its likely from meta-programming
                    return DFALatticeRef.init;
                }
                else
                {
                    final switch (var._init.kind)
                    {
                    case InitKind.exp:
                        auto ei = var._init.isExpInitializer;
                        DFALatticeRef lr = this.walk(ei.exp);

                        if (ei.exp.isConstructExp || ei.exp.isBlitExp)
                            return lr;
                        else
                            return seeAssign(dfaVar, true, lr);

                    case InitKind.array:
                        auto ai = var._init.isArrayInitializer;
                        DFALatticeRef lr = dfaCommon.makeLatticeRef;
                        DFAConsequence* c = lr.addConsequence(dfaVar);
                        lr.setContext(c);

                        return seeAssign(dfaVar, true, lr, false, ai.value.length > 0 ? 3 : 2);

                    case InitKind.void_:
                    case InitKind.error:
                    case InitKind.struct_:
                    case InitKind.C_:
                    case InitKind.default_:
                        return DFALatticeRef.init;
                    }
                }
            }
            else
                return DFALatticeRef.init;

        case EXP.construct:
            auto ce = expr.isConstructExp;

            dfaCommon.printStateln("construct lhs");
            DFALatticeRef lhs = this.walk(ce.e1);

            dfaCommon.printStateln("construct rhs");
            DFALatticeRef rhs = this.walk(ce.e2);
            return seeAssign(lhs, true, rhs);

        case EXP.negate: // -x
            // Without VRP we can't actually model this.
            auto ue = expr.isUnaExp;
            DFALatticeRef ret = this.walk(ue.e1);
            ret.acquireConstantAsContext;
            return ret;

            // Basic types
        case EXP.void_:
        case EXP.float64:
        case EXP.complex80:
            return DFALatticeRef.init;

        case EXP.call:
            auto ce = expr.isCallExp;
            assert(ce !is null);
            assert(ce.e1 !is null);
            return callFunction(ce.f, ce.e1, null, ce.arguments, ce.loc);

        case EXP.blit:
            auto be = expr.isBlitExp;

            dfaCommon.printStateln("blit lhs");
            DFALatticeRef lhs = this.walk(be.e1), rhs;
            DFAVar* lhsVar = lhs.getContextVar;

            if (auto e2ve = be.e2.isVarExp)
            {
                if (auto sd = e2ve.var.isSymbolDeclaration)
                {
                    // this evaluates out to a type

                    rhs = dfaCommon.makeLatticeRef;
                    rhs.acquireConstantAsContext(Truthiness.True, Nullable.NonNull);

                    goto BlitAssignRet;
                }
            }

            dfaCommon.printStateln("blit rhs");
            rhs = this.walk(be.e2);

        BlitAssignRet:
            DFALatticeRef ret = seeAssign(lhs, true, rhs, true);
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
            DFALatticeRef ret = seeAssign(lhs, false, rhs, false, lhsIndex !is null ? 3 : 0,
                    indexLR);

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
            // See Slice
            auto ie = expr.isIndexExp;

            dfaCommon.printStateln("index lhs");
            DFALatticeRef lhs = this.walk(ie.e1);
            dfaCommon.printStateln("index rhs");
            DFALatticeRef index = this.walk(ie.e2);

            DFAVar* lhsCtx;
            DFAConsequence* lhsCctx = lhs.getContext(lhsCtx);

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

        case EXP.slice:
            // See index
            auto se = expr.isSliceExp;

            dfaCommon.printStateln("Slice base");
            DFALatticeRef base = this.walk(se.e1);
            DFAVar* baseCtx;
            DFAConsequence* baseCctx = base.getContext(baseCtx);

            if (se.lwr is null && se.upr is null)
            {
                // Equivalent to doing slice[]
                DFAVar* indexVar = dfaCommon.findIndexVar(baseCtx);
                DFAConsequence* newCctx = base.addConsequence(indexVar);
                base.setContext(newCctx);
                return base;
            }

            Truthiness expectedTruthiness;

            if (baseCctx !is null && se.upperIsInBounds)
            {
                // Earlier VRP in the compiler has determined that it is non-null.
                // Even if the fast DFA can't determine it, that has been done already.

                baseCctx.nullable = Nullable.NonNull;
            }

            DFALatticeRef ret = base;

            if (se.lwr !is null)
            {
                // Handle [X .. X]
                if (se.upr !is null)
                {
                    auto lwrI = se.lwr.isIntegerExp;
                    auto uprI = se.upr.isIntegerExp;

                    if (lwrI !is null && uprI !is null && lwrI.toInteger == uprI.toInteger)
                        expectedTruthiness = Truthiness.False;
                }

                dfaCommon.printStateln("Slice [lwr");
                ret = this.seeLogicalAnd(ret, this.walk(se.lwr));
            }

            if (se.upr !is null)
            {
                dfaCommon.printStateln("Slice upr]");
                ret = this.seeLogicalAnd(ret, this.walk(se.upr));
            }
            else if (se.lengthVar !is null)
            {
                // Implicit length var for the upper.
                DFAVar* lengthVar = dfaCommon.findVariable(se.lengthVar);
                ret = this.seeLogicalAnd(ret, dfaCommon.acquireLattice(lengthVar));
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

        case EXP.assert_:
            auto ae = expr.isAssertExp;
            DFALatticeRef lr = this.walk(ae.e1);
            seeAssert(lr, ae.e1.loc);
            return DFALatticeRef.init;

        case EXP.halt:
            DFALatticeRef lr = dfaCommon.makeLatticeRef;
            lr.acquireConstantAsContext(Truthiness.False, Nullable.Unknown);

            seeAssert(lr, expr.loc);
            // Evaluates to void
            return DFALatticeRef.init;

        case EXP.new_:
            auto ne = expr.isNewExp;

            DFALatticeRef ret = this.callFunction(ne.member, ne.thisexp,
                    ne.argprefix, ne.arguments, ne.loc);

            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(dfaCommon.getInfiniteLifetimeVariable);
            ret.setContext(c);

            c.truthiness = Truthiness.True;
            c.nullable = Nullable.NonNull;
            return ret;

        case EXP.andAnd:
            auto be = expr.isBinExp;

            stmtWalker.startScope;
            dfaCommon.currentDFAScope.sideEffectFree = true;
            DFALatticeRef inProgress;

            // assume rhs could be andAnd
            while (be !is null)
            {
                DFALatticeRef lhs = this.walk(be.e1);
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
                    inProgress = seeLogicalAnd(inProgress, rhs);
                    break;
                }
            }

            stmtWalker.endScope;
            return inProgress;

        case EXP.orOr:
            auto be = expr.isBinExp;
            DFALatticeRef inProgress, toNegate;
            DFAScopeRef inProgressScr;

            while (be !is null)
            {
                // Make sure any effects converged into the scope by and expressions ext. don't effect rhs
                stmtWalker.startScope;
                dfaCommon.currentDFAScope.sideEffectFree = true;

                dfaCommon.printStateln("Or expression lhs:");
                DFALatticeRef lhs = this.walk(be.e1);
                inProgressScr = stmtWalker.seeLoopyLabelAwareStage(inProgressScr,
                        stmtWalker.endScope);

                toNegate = this.adaptConditionForBranch(lhs.copy, be.e1.type, false);

                if (inProgress.isNull)
                    inProgress = lhs;
                else
                    inProgress = seeLogicalOr(inProgress, lhs);

                if (be.e2.op == EXP.orOr)
                {
                    be = be.e2.isBinExp;
                    continue;
                }
                else
                {
                    // Make sure any effects converged into the scope by and expressions ext. don't effect rhs or return
                    stmtWalker.startScope;
                    dfaCommon.currentDFAScope.sideEffectFree = true;

                    this.seeSilentAssert(toNegate, false, true);

                    dfaCommon.printStateln("Or expression rhs:");
                    DFALatticeRef rhs = this.walk(be.e2);
                    inProgressScr = stmtWalker.seeLoopyLabelAwareStage(inProgressScr,
                            stmtWalker.endScope);

                    inProgress = seeLogicalOr(inProgress, rhs);
                    break;
                }
            }

            return inProgress;

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

        case EXP.lessThan:
        case EXP.lessOrEqual:
        case EXP.greaterThan:
        case EXP.greaterOrEqual:
            auto be = expr.isBinExp;

            DFALatticeRef lr = this.walk(be.e1);
            lr.walkMaybeTops((DFAConsequence* c) {
                if (c.var !is null)
                {
                    c.var.walkRoots((root) {
                        root.unmodellable = true;
                    });
                }
                return true;
            });

            lr = this.walk(be.e2);
            lr.walkMaybeTops((DFAConsequence* c) {
                if (c.var !is null)
                {
                    c.var.walkRoots((root) {
                        root.unmodellable = true;
                    });
                }
                return true;
            });

            DFALatticeRef ret = dfaCommon.makeLatticeRef;
            ret.acquireConstantAsContext;
            return ret;

        case EXP.addAssign:
        case EXP.minAssign:
        case EXP.leftShiftAssign:
        case EXP.rightShiftAssign:
        case EXP.unsignedRightShiftAssign:
        case EXP.mulAssign:
        case EXP.divAssign:
        case EXP.modAssign:
        case EXP.andAssign:
        case EXP.orAssign:
        case EXP.xorAssign:
        case EXP.powAssign:
            // We don't support the operator itself, but we do support the assignment.
            // If we supported value range propergation this would need changing.
            auto be = expr.isBinExp;

            dfaCommon.printStateln("assigns lhs");
            DFALatticeRef lhs = this.walk(be.e1);
            dfaCommon.printStateln("assigns rhs");
            DFALatticeRef rhs = this.walk(be.e2);

            // Because we can't model it without VRP, we'll give it an unknown value.
            if (rhs.isNull)
                rhs = dfaCommon.makeLatticeRef;
            rhs.acquireConstantAsContext;
            return seeAssign(lhs, false, rhs);

        case EXP.concatenateAssign: // ~=
        case EXP.concatenateElemAssign:
        case EXP.concatenateDcharAssign:
            // Whatever lhs started out as, it'll be non-null once we're done with it.
            auto be = expr.isBinExp;

            dfaCommon.printStateln("concat assign lhs");
            DFALatticeRef lhs = this.walk(be.e1);
            dfaCommon.printStateln("concat assign rhs");
            DFALatticeRef rhs = this.walk(be.e2);

            DFAVar* lhsCtx;
            DFAConsequence* lhsCctx = lhs.getContext(lhsCtx), rhsCctx = rhs.getContext;
            if (lhsCctx is null)
            {
                // We can't analyse this.
                return DFALatticeRef.init;
            }

            const nullableResult = concatNullableResult(be.e1.type, be.e2.type);
            dfaCommon.printState((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("concat nullable result %d\n",
                    nullableResult));

            DFALatticeRef ret = this.seeAssign(lhs, false, rhs, false,
                    nullableResult == 1 || nullableResult == 2 ? 3 : 0);

            if (ret.isNull)
            {
                ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext;
            }
            return ret;

        case EXP.loweredAssignExp:
            // Used for changing the length of lhs.
            // While we can just walk the lowering and it'll "work",
            //  it won't be good enough.
            auto be = expr.isLoweredAssignExp;

            dfaCommon.printStateln("length assign lhs");
            DFALatticeRef lhs;

            // See: slice.length = ...
            if (auto ale = be.e1.isArrayLengthExp)
                lhs = this.walk(ale.e1);
            else
                lhs = this.walk(be.e1);

            dfaCommon.printStateln("length assign rhs");
            DFALatticeRef rhs = this.walk(be.e2);

            DFAConsequence* lhsCctx = lhs.getContext, rhsCctx = rhs.getContext;

            if (lhsCctx is null)
            {
                // Welp we can't analyse this.
                return DFALatticeRef.init;
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

            DFALatticeRef ret = this.seeAssign(lhs, false, rhs, false, alteredState);

            if (ret.isNull)
            {
                ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext;
            }
            else
                this.seeConvergeExpression(ret.copy, true);

            return ret;

        case EXP.leftShift:
        case EXP.rightShift:
        case EXP.unsignedRightShift:
        case EXP.add:
        case EXP.min:
        case EXP.mul:
        case EXP.div:
        case EXP.mod:
        case EXP.and:
        case EXP.or:
        case EXP.xor:
            // We don't support the operator itself, but we do support the walk.
            // If we supported value range propergation this would need changing.
            auto be = expr.isBinExp;

            DFALatticeRef lhs = this.walk(be.e1);
            lhs.check;

            DFALatticeRef rhs = this.walk(be.e2);
            rhs.check;

            DFAVar* lhsVar = lhs.getContextVar;

            DFALatticeRef ret = seeLogicalAnd(lhs, rhs);
            ret.check;

            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(lhsVar);
            ret.setContext(c);
            c.truthiness = Truthiness.Unknown;

            ret.check;
            return ret;

        case EXP.plusPlus:
        case EXP.prePlusPlus:
        case EXP.minusMinus:
        case EXP.preMinusMinus:
            auto be = expr.isBinExp;

            DFALatticeRef lhs = this.walk(be.e1);
            lhs.check;

            // be.e2 is actually the value 1, but we can ignore that
            DFALatticeRef rhs = dfaCommon.makeLatticeRef;
            rhs.acquireConstantAsContext;

            DFAVar* lhsVar = lhs.getContextVar;
            DFALatticeRef ret = seeAssign(lhs, false, rhs);

            if (lhsVar !is null)
            {
                DFALatticeRef effect = dfaCommon.makeLatticeRef;
                effect.acquireConstantAsContext;

                lhsVar.walkRoots((root) { effect.addConsequence(root); });

                this.seeConvergeExpression(effect, true);
            }

            return ret;

        case EXP.tilde:
            auto ue = expr.isUnaExp;

            DFALatticeRef ret = this.walk(ue.e1);
            if (ret.isNull)
            {
                ret = dfaCommon.makeLatticeRef;
                ret.acquireConstantAsContext;
            }
            return ret;

        case EXP.comma:
            auto ce = expr.isCommaExp;
            dfaCommon.printStateln("comma lhs");
            DFALatticeRef lhs = this.walk(ce.e1);
            dfaCommon.printStateln("comma rhs");
            DFALatticeRef rhs = this.walk(ce.e2);

            DFAVar* rhsVar = rhs.getContextVar;
            DFALatticeRef ret = this.seeLogicalAnd(lhs, rhs);

            if (rhsVar !is null)
                ret.setContext(rhsVar);
            return ret;

        case EXP.structLiteral:
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

        case EXP.tuple:
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

        case EXP.question:
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

            return this.seeConditional(conditionLR, scrTrue, lrTrue, scrFalse,
                    lrFalse, unknownBranchTaken, predicateNegation);

        case EXP.delegate_:
        case EXP.function_:
            // known no-op
            return DFALatticeRef.init;

        case EXP.concatenate:
            auto ce = expr.isCatExp;

            dfaCommon.printStateln("concatenate lhs");
            DFALatticeRef lhs = this.walk(ce.e1);
            dfaCommon.printStateln("concatenate rlhs");
            DFALatticeRef rhs = this.walk(ce.e2);

            DFAConsequence* lhsCctx = lhs.getContext, rhsCctx = rhs.getContext;
            const nullableResult = concatNullableResult(ce.e1.type, ce.e2.type);
            Truthiness expectedTruthiness;
            Nullable expectedNullable;

            if (nullableResult == 2)
            {
                expectedTruthiness = Truthiness.True;
                expectedNullable = Nullable.NonNull;
            }
            else if (nullableResult == 1)
            {
                if (lhsCctx !is null)
                    expectedNullable = lhsCctx.nullable;
                if (rhsCctx !is null && expectedNullable < rhsCctx.nullable)
                    expectedNullable = rhsCctx.nullable;

                if (expectedNullable == Nullable.NonNull)
                    expectedTruthiness = Truthiness.True;
            }

            DFALatticeRef ret = this.seeLogicalAnd(lhs, rhs);
            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            ret.acquireConstantAsContext(expectedTruthiness, expectedNullable);
            return ret;

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
        case EXP.pow:

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
    /// Returns: 0 for unknown negation, 1 or has been negated from gate variable or 2 if it hasn't been.
    DFALatticeRef walkCondition(Expression expr, out int predicateNegation)
    {
        bool allGateConditional = true;
        bool outComeNegated;

        scope (exit)
        {
            if (!allGateConditional)
                predicateNegation = 0;
            else
                predicateNegation = outComeNegated ? 1 : 2;
        }

        DFALatticeRef seeExp(Expression expr, ref bool negated)
        {
            switch (expr.op)
            {
            case EXP.not: // !x
            {
                    negated = !negated; // !!x
                    auto ue = expr.isUnaExp;

                    if (auto ie = ue.e1.isInExp)
                    {
                        DFALatticeRef lhs = this.walk(ie.e1);
                        lhs.check;

                        DFALatticeRef rhs = this.walk(ie.e2);
                        rhs.check;

                        DFAVar* rhsVar = rhs.getContextVar;

                        // change comparison to: lhs in rhs[...]
                        if (rhsVar !is null)
                            rhs.setContext(dfaCommon.findIndexVar(rhsVar));

                        allGateConditional = false;
                        return this.seeEqual(lhs, rhs, false, ie.e1.type, ie.e2.type);
                    }
                    else
                        return seeNegate(seeExp(ue.e1, negated));
                }

            case EXP.notEqual: // !=
            {
                    negated = !negated;
                    auto be = expr.isBinExp;

                    bool negated2;

                    dfaCommon.printStateln("!equal lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2);
                    dfaCommon.printStateln("!equal rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2);

                    return seeEqual(lhs, rhs, false, be.e1.type, be.e2.type);
                }

            case EXP.notIdentity: // !is
            {
                    negated = !negated;
                    auto be = expr.isBinExp;

                    bool negated2;

                    dfaCommon.printStateln("!is lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2);
                    dfaCommon.printStateln("!is rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2);

                    return seeEqual(lhs, rhs, false, be.e1.type, be.e2.type);
                }

            case EXP.equal: // ==
            {
                    auto be = expr.isBinExp;
                    bool negated2;

                    dfaCommon.printStateln("equal lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2);
                    dfaCommon.printStateln("equal rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2);

                    return seeEqual(lhs, rhs, true, be.e1.type, be.e2.type);
                }

            case EXP.identity: // is
            {
                    auto be = expr.isBinExp;
                    bool negated2;

                    dfaCommon.printStateln("is lhs");
                    DFALatticeRef lhs = seeExp(be.e1, negated2);
                    dfaCommon.printStateln("is rhs");
                    DFALatticeRef rhs = seeExp(be.e2, negated2);

                    return seeEqual(lhs, rhs, true, be.e1.type, be.e2.type);
                }

            case EXP.string_:
                {
                    // A string literal even when empty will be non-null and true.
                    DFALatticeRef ret = dfaCommon.makeLatticeRef;
                    //ret.acquireConstantAsContext(Truthiness.True, Nullable.NonNull);
                    ret.acquireConstantAsContext;
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
                            DFALatticeRef temp = this.walk(e);

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

                    ret.acquireConstantAsContext(Truthiness.True, Nullable.NonNull);
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
                            this.seeConvergeFunctionCallArgument(this.walk(ele),
                                    null, 0, null, ele.loc);
                        }

                        DFAConsequence* cctx = ret.addConsequence(
                                dfaCommon.getInfiniteLifetimeVariable);
                        ret.setContext(cctx);
                        cctx.truthiness = Truthiness.True;
                        cctx.nullable = Nullable.NonNull;
                    }
                    else
                        ret.acquireConstantAsContext(Truthiness.False, Nullable.Null);

                    return ret;
                }

            case EXP.assocArrayLiteral:
                {
                    auto aale = expr.isAssocArrayLiteralExp;
                    DFALatticeRef ret = dfaCommon.makeLatticeRef;

                    if (aale.keys !is null && aale.keys.length > 0)
                    {
                        DFAConsequence* cctx = ret.addConsequence(
                                dfaCommon.getInfiniteLifetimeVariable);
                        ret.setContext(cctx);
                        cctx.truthiness = Truthiness.True;
                        cctx.nullable = Nullable.NonNull;
                    }
                    else
                        ret.acquireConstantAsContext(Truthiness.False, Nullable.Null);

                    return ret;
                }

            case EXP.arrayLength:
                {
                    // This is supposed to be a read only,
                    // Lowered assign expression will handle the write version.

                    auto ue = expr.isUnaExp;

                    DFALatticeRef ret = seeExp(ue.e1, negated);
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

                    c.truthiness = b.get ? Truthiness.True : Truthiness.False;
                    return ret;
                }

            case EXP.cast_:
                {
                    auto ce = expr.isCastExp;

                    dfaCommon.printState((ref OutBuffer ob,
                            scope PrintPrefixType prefix) => ob.printf("cast to %d\n",
                            ce.to !is null ? ce.to.ty : -1));

                    DFALatticeRef ret = this.walk(ce.e1);
                    ret.check;

                    if (ce.to is null || ce.to.isTypeClass)
                    {
                        // ideally we'd model up casts, and only disallow down casts
                        ret = dfaCommon.makeLatticeRef;
                        ret.acquireConstantAsContext(Truthiness.Unknown, Nullable.Unknown);
                    }
                    else
                    {
                        if (ret.isNull)
                            ret = dfaCommon.makeLatticeRef;

                        DFAConsequence* cctx = ret.getContext;
                        if (cctx is null)
                            cctx = ret.acquireConstantAsContext;

                        if (cctx.var !is null && cctx.var.isNullable && !isTypeNullable(ce.to))
                        {
                            // This prevents pointer integer checks from infecting pointers

                            cctx = ret.acquireConstantAsContext(cctx.truthiness, cctx.nullable);
                        }
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
                            DFAVar* var = dfaCommon.findVariable(vd);

                            if (var !is null)
                            {
                                ret = dfaCommon.acquireLattice(var);
                                ret.check;
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
            return seeExp(expr, outComeNegated);

        default:
            return this.walk(expr);
        }
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
                    ret.acquireConstantAsContext(Truthiness.True, Nullable.NonNull);
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
}
