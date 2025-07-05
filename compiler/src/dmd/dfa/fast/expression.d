module dmd.dfa.fast.expression;
import dmd.dfa.fast.analysis;
import dmd.dfa.fast.report;
import dmd.dfa.fast.statement;
import dmd.dfa.utils;
import dmd.dfa.common;
import dmd.location;
import dmd.expression;
import dmd.astenums;
import dmd.tokens;
import dmd.func;
import dmd.declaration;
import dmd.mtype;
import core.stdc.stdio;

struct ExpressionWalker
{
    DFACommon* dfaCommon;
    StatementWalker stmtWalker;
    DFAAnalyzer* analyzer;
    int depth;

    void print(Args...)(const(char)* fmt, Args args)
    {
        if (!dfaCommon.debugIt)
            return;
        else
        {
            printf("%.*s[%p];%.*s> ", stmtWalker.depth, PrintPipeText.ptr,
                    stmtWalker.currentFunction, depth, PrintPipeText.ptr);
            printf(fmt, args);
            fflush(stdout);
        }
    }

    void seeConvergeExpression(DFALatticeRef lr)
    {
        print("Converging expression:\n");
        lr.print("", stmtWalker.depth, stmtWalker.currentFunction, this.depth);
        lr.check;

        analyzer.convergeExpression(lr);

        dfaCommon.currentDFAScope.print("so far", stmtWalker.depth,
                stmtWalker.currentFunction, this.depth);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeFunctionCallArgument(DFALatticeRef lr, ParameterDFAInfo* paramInfo,
            Parameter paramVar, FuncDeclaration calling, ref Loc loc)
    {
        print("Converging argument:\n");
        lr.print("", stmtWalker.depth, stmtWalker.currentFunction, this.depth);
        lr.check;

        analyzer.convergeFunctionCallArgument(lr, paramInfo, paramVar, calling, loc);

        dfaCommon.currentDFAScope.print("so far", stmtWalker.depth,
                stmtWalker.currentFunction, this.depth);
        dfaCommon.currentDFAScope.check;
    }

    DFALatticeRef seeAssign(DFAVar* assignTo, bool construct, DFALatticeRef lr, bool isBlit = false)
    {
        DFALatticeRef assignTo2 = dfaCommon.makeLatticeRef;
        assignTo2.setContext(assignTo);

        return seeAssign(assignTo2, construct, lr, isBlit);
    }

    DFALatticeRef seeAssign(DFALatticeRef assignTo, bool construct,
            DFALatticeRef lr, bool isBlit = false)
    {
        print("Assigning construct?%d:%d\n", construct, isBlit);
        assignTo.print("to", stmtWalker.depth, stmtWalker.currentFunction, depth);
        assignTo.check;
        lr.print("from", stmtWalker.depth, stmtWalker.currentFunction, depth);
        lr.check;

        assert(analyzer !is null);
        DFALatticeRef ret = analyzer.transferAssign(assignTo, construct, isBlit, lr);
        ret.check;
        ret.print("result", stmtWalker.depth, stmtWalker.currentFunction, depth);
        return ret;
    }

    DFALatticeRef seeEqual(DFALatticeRef lhs, DFALatticeRef rhs,
            bool truthiness, bool pointerBitEqual)
    {
        print("Equal iff %d %d\n", truthiness, pointerBitEqual);
        lhs.print("lhs", stmtWalker.depth, stmtWalker.currentFunction, depth);
        rhs.print("rhs", stmtWalker.depth, stmtWalker.currentFunction, depth);

        DFALatticeRef ret = analyzer.transferEqual(lhs, rhs, truthiness, pointerBitEqual);
        ret.print("result", stmtWalker.depth, stmtWalker.currentFunction, depth);
        return ret;
    }

    DFALatticeRef seeNegate(DFALatticeRef lr, bool protectElseNegate = false)
    {
        lr.print("Negate", stmtWalker.depth, stmtWalker.currentFunction, depth);
        return analyzer.transferNegate(lr, protectElseNegate);
    }

    DFALatticeRef seeDereference(ref Loc loc, DFALatticeRef lr)
    {
        print("Dereferencing\n");
        lr.print("Dereference", stmtWalker.depth, stmtWalker.currentFunction, depth);

        DFALatticeRef ret = analyzer.transferDereference(lr, loc);
        ret.print("result", stmtWalker.depth, stmtWalker.currentFunction, depth);
        return ret;
    }

    void seeAssert(DFALatticeRef lr, ref const Loc loc, bool dueToConditional = false)
    {
        lr.print("Assert", stmtWalker.depth, stmtWalker.currentFunction, depth);

        dfaCommon.currentDFAScope.print("scope", stmtWalker.depth,
                stmtWalker.currentFunction, depth);
        dfaCommon.currentDFAScope.check;

        analyzer.transferAssert(lr, loc, false, dueToConditional);

        dfaCommon.currentDFAScope.print("so far", stmtWalker.depth,
                stmtWalker.currentFunction, depth);
        dfaCommon.currentDFAScope.check;
    }

    void seeSilentAssert(DFALatticeRef lr, bool ignoreWriteCount = false,
            bool dueToConditional = false)
    {
        lr.print("Assert silent", stmtWalker.depth, stmtWalker.currentFunction, depth);

        dfaCommon.currentDFAScope.print("scope", stmtWalker.depth,
                stmtWalker.currentFunction, depth);
        dfaCommon.currentDFAScope.check;

        Loc loc;
        analyzer.transferAssert(lr, loc, ignoreWriteCount, dueToConditional);

        dfaCommon.currentDFAScope.print("so far", stmtWalker.depth,
                stmtWalker.currentFunction, depth);
        dfaCommon.currentDFAScope.check;
    }

    DFALatticeRef seeLogicalAnd(DFALatticeRef lhs, DFALatticeRef rhs)
    {
        print("Logical and:\n");
        lhs.print("lhs", stmtWalker.depth, stmtWalker.currentFunction, depth);
        lhs.check;
        rhs.print("rhs", stmtWalker.depth, stmtWalker.currentFunction, depth);
        rhs.check;

        DFALatticeRef ret = analyzer.transferLogicalAnd(lhs, rhs);
        ret.print("result", stmtWalker.depth, stmtWalker.currentFunction, depth);
        ret.check;

        return ret;
    }

    DFALatticeRef seeLogicalOr(DFALatticeRef lhs, DFALatticeRef rhs)
    {
        print("Logical or:\n");
        lhs.print("lhs", stmtWalker.depth, stmtWalker.currentFunction, depth);
        rhs.print("rhs", stmtWalker.depth, stmtWalker.currentFunction, depth);

        DFALatticeRef ret = analyzer.transferLogicalOr(lhs, rhs);
        ret.print("result", stmtWalker.depth, stmtWalker.currentFunction, depth);

        return ret;
    }

    DFALatticeRef seeConditional(DFAScopeRef scrTrue, DFALatticeRef lrTrue,
            DFAScopeRef scrFalse, DFALatticeRef lrFalse)
    {
        print("Condition:\n");
        scrTrue.print("true sc", stmtWalker.depth, stmtWalker.currentFunction, depth);
        lrTrue.print("true lr", stmtWalker.depth, stmtWalker.currentFunction, depth);
        scrFalse.print("false sc", stmtWalker.depth, stmtWalker.currentFunction, depth);
        lrFalse.print("false lr", stmtWalker.depth, stmtWalker.currentFunction, depth);

        DFALatticeRef ret = analyzer.transferConditional(scrTrue, lrTrue, scrFalse, lrFalse);
        ret.print("result", stmtWalker.depth, stmtWalker.currentFunction, depth);

        dfaCommon.currentDFAScope.print("so far", stmtWalker.depth,
                stmtWalker.currentFunction, depth);

        ret.check;
        dfaCommon.currentDFAScope.check;
        return DFALatticeRef.init;
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

    DFALatticeRef walk(Expression expr)
    {
        if (expr is null)
            return DFALatticeRef.init;

        print("[%p]%3d: at %s\n", expr, expr.op, expr.loc.toChars);
        depth++;
        dfaCommon.check;

        scope (exit)
        {
            dfaCommon.check;
            depth--;
        }

        final switch (expr.op)
        {
        case EXP.variable:
            auto ve = expr.isVarExp;
            assert(ve !is null);

            if (ve.var !is null)
            {
                if (auto vd = ve.var.isVarDeclaration)
                {
                    DFAVar* var = dfaCommon.findVariable(vd);

                    if (var !is null)
                    {
                        DFALatticeRef ret = dfaCommon.acquireLattice(var);
                        ret.check;
                        return ret;
                    }
                }
            }

            // no other declarations really apply for the DFA
            return DFALatticeRef.init;

        case EXP.this_:
            auto vd = expr.isThisExp.var;

            if (vd is null)
                vd = stmtWalker.currentFunction.vthis;

            if (!dfaCommon.debugUnknownAST && vd is null)
                return DFALatticeRef.init;
            else if (vd is null)
                assert(0);

            DFAVar* var = dfaCommon.findVariable(vd);
            return dfaCommon.acquireLattice(var);

        case EXP.dotVariable:
            auto dve = expr.isDotVarExp;
            if (dve.var.isVarDeclaration is null)
                return DFALatticeRef.init;

            DFALatticeRef ret = this.walk(dve.e1);
            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* context = ret.getContext;
            DFAVar* var;

            // for indirection we start with a clean slate on each access
            if (context is null || context.var is null)
                var = dfaCommon.findVariable(dve.var.isVarDeclaration);
            else
                var = dfaCommon.findVariable(dve.var.isVarDeclaration, context.var);

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
                assert(varOffset is null || varOffset.base !is null);

                DFAConsequence* c = ret.addConsequence(varOffset);
                ret.setContext(c);
            }
            else if (auto fd = soe.var.isFuncDeclaration)
            {
                // if its not offset of zero something is real funky here!
                // this is inherently non-null unless there is something wrong with compiler/linker.
                assert(soe.offset == 0);

                ret = dfaCommon.makeLatticeRef;
                DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
                ret.setContext(c);
                c.nullable = Nullable.NonNull;
                c.truthiness = Truthiness.True;
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
                DFAConsequence* cctx = ret.getContext;
                DFAVar* ctx = cctx !is null ? cctx.var : null;

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
                        if (!ei.exp.isConstructExp)
                            return seeAssign(dfaVar, true, lr);
                        return lr;

                    case InitKind.array:
                        auto ai = var._init.isArrayInitializer;
                        DFALatticeRef lr = dfaCommon.makeLatticeRef;
                        DFAConsequence* c = lr.addConsequence(dfaVar);
                        lr.setContext(c);

                        if (ai.value.length > 0)
                        {
                            c.truthiness = Truthiness.True;
                            c.nullable = Nullable.NonNull;
                        }
                        else
                        {
                            c.truthiness = Truthiness.False;
                            c.nullable = Nullable.Null;
                        }

                        return seeAssign(dfaVar, true, lr);

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

            print("construct lhs\n");
            DFALatticeRef lhs = this.walk(ce.e1);

            print("construct rhs\n");
            DFALatticeRef rhs = this.walk(ce.e2);
            return seeAssign(lhs, true, rhs);

        case EXP.cast_:
            DFALatticeRef ret = this.walk(expr.isCastExp.e1);
            ret.check;
            return ret;

        case EXP.equal:
            auto be = expr.isBinExp;

            this.print("equal lhs\n");
            DFALatticeRef lhs = this.walk(be.e1);
            this.print("equal rhs\n");
            DFALatticeRef rhs = this.walk(be.e2);

            return seeEqual(lhs, rhs, true, false);

        case EXP.notEqual:
            auto be = expr.isBinExp;

            this.print("!equal lhs\n");
            DFALatticeRef lhs = this.walk(be.e1);
            this.print("!equal rhs\n");
            DFALatticeRef rhs = this.walk(be.e2);

            return seeEqual(lhs, rhs, false, false);

        case EXP.identity: // is
        case EXP.is_: // is
            auto be = expr.isBinExp;

            this.print("is lhs\n");
            DFALatticeRef lhs = this.walk(be.e1);
            this.print("is rhs\n");
            DFALatticeRef rhs = this.walk(be.e2);

            return seeEqual(lhs, rhs, true, true);

        case EXP.notIdentity: // !is
            auto be = expr.isBinExp;

            this.print("!is lhs\n");
            DFALatticeRef lhs = this.walk(be.e1);
            this.print("!is rhs\n");
            DFALatticeRef rhs = this.walk(be.e2);

            return seeEqual(lhs, rhs, false, true);

        case EXP.negate:
        case EXP.not:
            auto ue = expr.isUnaExp;
            return seeNegate(walk(ue.e1));

            // Basic types
        case EXP.void_:
        case EXP.float64:
        case EXP.complex80:
            return DFALatticeRef.init;

        case EXP.int64:
            auto ie = expr.isIntegerExp;

            auto b = ie.toBool;
            if (!b.isPresent)
                return DFALatticeRef.init;

            DFALatticeRef ret = dfaCommon.makeLatticeRef;
            DFAConsequence* c = ret.addConsequence(null);
            ret.setContext(c);

            c.truthiness = b.get ? Truthiness.True : Truthiness.False;
            return ret;

        case EXP.call:
            auto ce = expr.isCallExp;
            assert(ce !is null);
            assert(ce.e1 !is null);

            if (ce.f is null)
                return DFALatticeRef.init;

            if (ce.f.ident !is null)
                print("Calling function `%s` at %s\n", ce.f.ident.toChars, ce.loc.toChars);
            else if (ce.loc.isValid)
                print("Calling function at %s\n", ce.loc.toChars);
            else
                print("Calling function\n");

            ParametersDFAInfo* calledFunctionInfo = ce.f.parametersDFAInfo;

            if (auto ve = ce.e1.isVarExp)
            {
                assert(ve.var.isFuncDeclaration() !is null);
            }
            else if (calledFunctionInfo !is null)
            {
                ParameterDFAInfo* info = &calledFunctionInfo.thisPointer;

                this.print("This\n");
                DFALatticeRef thisExp = this.walk(ce.e1);

                this.seeConvergeFunctionCallArgument(thisExp, info, null, ce.f, ce.e1.loc);
            }

            if (ce.arguments !is null && ce.arguments.length > 0)
            {
                TypeFunction functionType = ce.f.type.toTypeFunction;

                Parameter[] allParameters;
                Parameter lastParameter;

                if (functionType.parameterList.parameters is null
                        || functionType.parameterList.parameters.length == 0)
                {
                    printf("Parameter list is empty at %s\n", ce.loc.toChars);
                    assert(0);
                }

                if (functionType.parameterList.parameters !is null)
                {
                    allParameters = (*functionType.parameterList.parameters)[];
                    lastParameter = allParameters[$ - 1];
                }

                assert(allParameters.length > 0);

                this.print("Calling function parameter info\n");
                this.print("    %zd %zd %p %p %zd\n", ce.arguments.length,
                        allParameters.length, lastParameter, calledFunctionInfo,
                        calledFunctionInfo !is null ? calledFunctionInfo.parameters.length : 0);

                if (calledFunctionInfo is null || calledFunctionInfo.parameters.length == 0)
                {
                    // cyclic no info

                    foreach (i, arg; *ce.arguments)
                    {
                        Parameter param = i >= allParameters.length
                            ? lastParameter : allParameters.ptr[i];

                        this.print("Argument %zd\n", i);

                        DFALatticeRef argExp = this.walk(arg);
                        this.seeConvergeFunctionCallArgument(argExp, null, param, ce.f, ce.e1.loc);
                    }
                }
                else
                {
                    ParameterDFAInfo[] allInfos = calledFunctionInfo.parameters[];
                    ParameterDFAInfo* lastInfo = &allInfos[$ - 1];

                    foreach (i, arg; *ce.arguments)
                    {
                        Parameter param = i >= allParameters.length
                            ? lastParameter : allParameters.ptr[i];
                        ParameterDFAInfo* info = i >= allInfos.length ? lastInfo : &allInfos.ptr[i];

                        this.print("Argument %zd\n", i);
                        if (info !is null)
                            this.print("    info %d:%d\n", info.notNullIn, info.notNullOut);

                        DFALatticeRef argExp = this.walk(arg);
                        this.seeConvergeFunctionCallArgument(argExp, info, param, ce.f, ce.e1.loc);
                    }
                }
            }

            DFALatticeRef ret = dfaCommon.makeLatticeRef;
            DFAConsequence* retC = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(retC);

            if (calledFunctionInfo !is null
                    && calledFunctionInfo.returnValue.notNullOut == Fact.Guaranteed)
            {
                retC.nullable = Nullable.NonNull;
                retC.truthiness = Truthiness.True;
            }

            return ret;

        case EXP.blit:
            auto be = expr.isBlitExp;

            DFALatticeRef lhs = this.walk(be.e1), rhs;

            if (auto e2ve = be.e2.isVarExp)
            {
                if (auto sd = e2ve.var.isSymbolDeclaration)
                {
                    // this evaluates out to a type, NOPE
                }
                else
                    rhs = this.walk(be.e2);
            }

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

            print("assign lhs\n");
            DFALatticeRef lhs = this.walk(lhsContext);
            DFAVar* lhsContextVar;

            if (lhsIndex !is null)
            {
                print("assign lhs index\n");
                DFALatticeRef index = this.walk(lhsIndex);

                DFAConsequence* lhsCctx = lhs.getContext;
                lhsContextVar = lhsCctx !is null ? lhsCctx.var : null;

                if (lhsCctx !is null)
                {
                    lhsCctx.nullable = Nullable.NonNull;
                    lhsCctx.truthiness = Truthiness.True;
                }

                lhs = this.seeLogicalAnd(lhs, index);
            }

            print("assign rhs\n");
            DFALatticeRef rhs = this.walk(ae.e2);

            DFALatticeRef ret = seeAssign(lhs, false, rhs);

            if (lhsContextVar !is null)
            {
                // for AA's we apply the knowledge that the result assignment will be non-null
                DFAConsequence* newCctx = ret.addConsequence(lhsContextVar);
                ret.setContext(newCctx);

                if (lhsContextVar !is null)
                {
                    newCctx.nullable = Nullable.NonNull;
                    newCctx.truthiness = Truthiness.True;
                }
                else
                {
                    newCctx.nullable = Nullable.Unknown;
                    newCctx.truthiness = Truthiness.Unknown;
                }
            }

            return ret;

        case EXP.null_:
            DFALatticeRef ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(null);
            ret.setContext(c);

            c.truthiness = Truthiness.False;
            c.nullable = Nullable.Null;
            return ret;

        case EXP.star:
            auto pe = expr.isPtrExp;
            return seeDereference(pe.loc, walk(pe.e1));

        case EXP.index:
            auto ie = expr.isIndexExp;

            print("index lhs\n");
            DFALatticeRef lhs = this.walk(ie.e1);
            print("index rhs\n");
            DFALatticeRef index = this.walk(ie.e2);

            DFAConsequence* lhsCctx = lhs.getContext;
            DFAVar* lhsCtx = lhsCctx !is null ? lhsCctx.var : null;

            Nullable oldLHSNullable;
            Truthiness oldLHSTruthiness;

            if (lhsCctx !is null)
            {
                if (ie.indexIsInBounds)
                {
                    if (lhsCctx.nullable != Nullable.NonNull)
                    {
                        lhsCctx.nullable = Nullable.NonNull;
                        lhsCctx.truthiness = Truthiness.True;
                    }
                }

                oldLHSNullable = lhsCctx.nullable;
                oldLHSTruthiness = lhsCctx.truthiness;
            }

            DFALatticeRef combined = this.seeLogicalAnd(lhs, index);
            DFAConsequence* newCctx = combined.addConsequence(lhsCtx);
            combined.setContext(newCctx);

            if (lhsCtx !is null)
            {
                newCctx.nullable = oldLHSNullable;
                newCctx.truthiness = oldLHSTruthiness;
            }
            else
            {
                newCctx.nullable = Nullable.Unknown;
                newCctx.truthiness = Truthiness.Unknown;
            }

            DFALatticeRef ret = seeDereference(ie.loc, combined);
            return ret;

        case EXP.assert_:
            auto ae = expr.isAssertExp;
            seeAssert(this.walk(ae.e1), ae.e1.loc);
            return DFALatticeRef.init;

        case EXP.halt:
            DFALatticeRef lr = dfaCommon.makeLatticeRef;
            DFAConsequence* c = lr.addConsequence(cast(DFAVar*) null);
            lr.setContext(c);

            c.truthiness = Truthiness.False;
            seeAssert(lr, expr.loc);

            return DFALatticeRef.init;

        case EXP.new_:
            DFALatticeRef ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(null);
            ret.setContext(c);

            c.truthiness = Truthiness.True;
            c.nullable = Nullable.NonNull;
            return ret;

        case EXP.andAnd:
        case EXP.in_:
            auto be = expr.isBinExp;

            DFALatticeRef lhs = this.walk(be.e1);
            lhs.check;

            DFALatticeRef rhs = this.walk(be.e2);
            rhs.check;

            DFALatticeRef ret = seeLogicalAnd(lhs, rhs);
            ret.check;
            return ret;

        case EXP.orOr:
            auto be = expr.isBinExp;

            DFALatticeRef lhs = this.walk(be.e1);
            DFALatticeRef rhs = this.walk(be.e2);
            return seeLogicalOr(lhs, rhs);

        case EXP.lessThan:
        case EXP.greaterThan:
        case EXP.lessOrEqual:
        case EXP.greaterOrEqual:
            // We do not support this,
            // However...
            //  it just so happens to look an awful like a logical or, so run that.
            auto be = expr.isBinExp;
            DFALatticeRef lhs = this.walk(be.e1);
            DFALatticeRef rhs = this.walk(be.e2);

            DFALatticeRef ret = seeLogicalOr(lhs, rhs);
            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(c);
            c.truthiness = Truthiness.Unknown;
            return ret;

        case EXP.addAssign:
        case EXP.minAssign:
        case EXP.leftShiftAssign:
        case EXP.rightShiftAssign:
        case EXP.unsignedRightShiftAssign:
        case EXP.concatenateAssign: // ~=
        case EXP.concatenateElemAssign:
        case EXP.concatenateDcharAssign:
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
            DFALatticeRef lhs = this.walk(be.e1);
            DFALatticeRef rhs = this.walk(be.e2);
            return seeAssign(lhs, false, rhs);

        case EXP.loweredAssignExp:
            // Ditto except even though this is a BinExp it doesn't have the flag set.
            auto be = expr.isLoweredAssignExp;
            DFALatticeRef lhs = this.walk(be.e1);
            DFALatticeRef rhs = this.walk(be.e2);
            return seeAssign(lhs, false, rhs);

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
        case EXP.plusPlus:
        case EXP.minusMinus:
            // We don't support the operator itself, but we do support the walk.
            // If we supported value range propergation this would need changing.
            auto be = expr.isBinExp;

            DFALatticeRef lhs = this.walk(be.e1);
            lhs.check;

            DFALatticeRef rhs = this.walk(be.e2);
            rhs.check;

            DFAConsequence* lhsCctx = lhs.getContext;
            DFAVar* lhsVar = lhsCctx !is null ? lhsCctx.var : null;

            DFALatticeRef ret = seeLogicalAnd(lhs, rhs);
            ret.check;

            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(lhsVar);
            ret.setContext(c);
            c.truthiness = Truthiness.Unknown;

            ret.check;
            return ret;

        case EXP.arrayLength:
        case EXP.tilde:
        case EXP.prePlusPlus:
        case EXP.preMinusMinus:
            auto ue = expr.isUnaExp;

            DFALatticeRef ret = this.walk(ue.e1);
            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(c);
            c.truthiness = Truthiness.Unknown;
            return ret;

        case EXP.comma:
            auto ce = expr.isCommaExp;
            print("comma lhs\n");
            DFALatticeRef lhs = this.walk(ce.e1);
            print("comma rhs\n");
            DFALatticeRef rhs = this.walk(ce.e2);

            DFAConsequence* lhsCtx = lhs.getContext;
            DFAVar* lhsVar = lhsCtx !is null ? lhsCtx.var : null;

            DFALatticeRef ret = this.seeLogicalAnd(lhs, rhs);
            if (lhsVar !is null)
                ret.setContext(lhsVar);
            return ret;

        case EXP.slice:
            auto se = expr.isSliceExp;
            DFALatticeRef ret = this.walk(se.e1);
            DFAConsequence* cctx = ret.getContext;
            DFAVar* var = cctx !is null ? cctx.var : null;

            if (se.lwr is null)
            {
                if (se.lengthVar !is null)
                {
                    DFAVar* lengthVar = dfaCommon.findVariable(se.lengthVar);
                    ret = this.seeLogicalAnd(ret, dfaCommon.acquireLattice(lengthVar));
                }
            }
            else
                ret = this.seeLogicalAnd(ret, this.walk(se.lwr));

            if (se.upr !is null)
                ret = this.seeLogicalAnd(ret, this.walk(se.upr));

            if (var !is null)
                ret.setContext(var);
            return ret;

        case EXP.structLiteral:
            auto sle = expr.isStructLiteralExp;
            DFALatticeRef ret;

            if (sle.elements !is null)
            {

                foreach (ele; *sle.elements)
                {
                    DFALatticeRef temp = this.walk(ele);

                    if (ret.isNull)
                        ret = temp;
                    else
                        ret = this.seeLogicalAnd(ret, temp);
                }
            }

            if (ret.isNull)
                ret = dfaCommon.makeLatticeRef;

            DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(c);
            c.truthiness = Truthiness.Unknown;
            c.nullable = Nullable.Unknown;
            return ret;

        case EXP.string_:
        case EXP.typeid_:
            // unless there is a compiler/linker bug this will be non-null
            DFALatticeRef ret = dfaCommon.makeLatticeRef;
            DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(c);
            c.nullable = Nullable.NonNull;
            c.truthiness = Truthiness.True;
            return ret;

        case EXP.tuple:
            auto te = expr.isTupleExp;

            DFAVar* expectedContext;
            DFALatticeRef inProgress;

            if (te.e0 !is null)
            {
                inProgress = this.walk(te.e0);
                DFAConsequence* cctx = inProgress.getContext;
                expectedContext = cctx !is null ? cctx.var : null;
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
            print("Condition expression %p:%p %s\n", dfaCommon.currentDFAScope,
                    origScope, qe.loc.toChars);

            // qe.econd

            stmtWalker.startScope;
            bool ignoreTrueBranch, ignoreFalseBranch;

            {
                DFALatticeRef condition = this.walk(qe.econd);

                DFAConsequence* c = condition.getContext;
                if (c !is null)
                {
                    if (c.truthiness == Truthiness.False)
                        ignoreTrueBranch = true;
                    else if (c.truthiness == Truthiness.True)
                        ignoreFalseBranch = true;
                }

                if (!ignoreTrueBranch)
                    this.seeAssert(condition, qe.econd.loc, true);
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
                stmtWalker.startScope;

                if (!ignoreFalseBranch && qe.econd !is null)
                {
                    DFALatticeRef condition = this.walk(qe.econd);
                    condition = this.seeNegate(condition, true);
                    this.seeSilentAssert(condition, false, true);

                    lrFalse = this.walk(qe.e2);
                }
                else
                {

                    DFALatticeRef condition = this.walk(qe.econd);
                    condition = this.seeNegate(condition);
                    this.seeSilentAssert(condition, true, true);
                }

                scrFalse = stmtWalker.endScope;
                scrFalse.check;
            }

            return this.seeConditional(scrTrue, lrTrue, scrFalse, lrFalse);

        case EXP.delegate_:
        case EXP.function_:
            // known no-op
            return DFALatticeRef.init;

        case EXP.arrayLiteral:
            auto ale = expr.isArrayLiteralExp;

            DFALatticeRef ret = dfaCommon.makeLatticeRef;
            DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(c);

            if (ale.elements !is null && ale.elements.length > 0)
            {
                c.truthiness = Truthiness.True;
                c.nullable = Nullable.NonNull;
            }
            else
            {
                c.truthiness = Truthiness.False;
                c.nullable = Nullable.Null;
            }

            return ret;

        case EXP.assocArrayLiteral:
            auto aale = expr.isAssocArrayLiteralExp;

            DFALatticeRef ret = dfaCommon.makeLatticeRef;
            DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(c);

            if (aale.keys !is null && aale.keys.length > 0)
            {
                c.truthiness = Truthiness.True;
                c.nullable = Nullable.NonNull;
            }
            else
            {
                c.truthiness = Truthiness.False;
                c.nullable = Nullable.Null;
            }

            return ret;

        case EXP.concatenate:
            auto ce = expr.isCatExp;

            DFALatticeRef lhs = this.walk(ce.e1), rhs = this.walk(ce.e2);
            DFAConsequence* lhsCctx = lhs.getContext, rhsCctx = rhs.getContext;

            const have = (lhsCctx !is null && lhsCctx.nullable == Nullable.NonNull)
                || (rhsCctx !is null && rhsCctx.nullable == Nullable.NonNull);

            DFALatticeRef ret = this.seeLogicalAnd(lhs, rhs);
            DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
            ret.setContext(c);

            if (have)
            {
                c.truthiness = Truthiness.True;
                c.nullable = Nullable.NonNull;
            }
            else
            {
                c.truthiness = Truthiness.False;
                c.nullable = Nullable.Null;
            }

            return ret;

        case EXP.vector:
        case EXP.vectorArray:
        case EXP.delegatePointer:
        case EXP.delegateFunctionPointer:
            auto ue = expr.isUnaExp;
            return this.walk(ue.e1);

        case EXP.type:
            // holds a type, known no-op
            return DFALatticeRef.init;

        case EXP.reserved:

            // Other
        case EXP.array:
        case EXP.throw_:
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
}
