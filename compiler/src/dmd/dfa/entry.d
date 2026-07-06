/**
 * Entry point into Data Flow Analysis engine.
 *
 * This engine performs a structural analysis of the code to detect
 * issues like nullability and truthiness.
 *
 * Design:
 * - Structural Definition Algorithm: It performs a single forward pass
 * over the AST (O(1) cost per node), minimizing compilation time.
 * - Non-Iterative: Unlike "chaotic iteration" solvers (which can be O(n^2)),
 * this engine does not loop until convergence. It tries to limit its visitation of each node to once.
 *
 * See_Also:
 * https://forum.dlang.org/post/xmssfygefvldeiyodfya@forum.dlang.org
 * (Why we should not enable a slow DFA by default)
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dfa/entry.d, dfa/entry.d)
 * Documentation: https://dlang.org/phobos/dmd_dfa_entry.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dfa/entry.d
 */
module dmd.dfa.entry;
import dmd.common.outbuffer;
import dmd.func;
import dmd.astenums;
import dmd.globals;
import dmd.mangle;
import dmd.dscope;
import dmd.dsymbol;
import dmd.attribsem;
import dmd.expression;
import dmd.id;
import dmd.timetrace;
import core.stdc.stdio;
import core.stdc.string;

void dfaEntry(FuncDeclaration fd, Scope* sc)
{
    version (none)
    {
        import core.memory;

        auto before = GC.stats;

        fastDFA(fd, sc);

        auto after = GC.stats;
        if (before.allocatedInCurrentThread != after.allocatedInCurrentThread)
            printf("edelta %lld\n", after.allocatedInCurrentThread - before
                    .allocatedInCurrentThread);
    }
    else
    {
        fastDFA(fd, sc);
    }
}

private:
/***********************************************************
 * Performs the fast Data Flow Analysis on a function declaration.
 *
 * This function acts as the coordinator. It:
 * 1. Checks if the function needs analysis (skips CTFE-only code).
 * 2. Instantiates the components:
 *  - StatementWalker: Traverses statements (if, while, return).
 *  - ExpressionWalker: Traverses expressions (a + b, func()).
 *  - DFAAnalyzer: Tracks the state of variables (The Brain).
 *  - DFAReporter: Reports errors and handles inferring.
 * 3. Wires them together but separates them for separation of concerns reasons.
 * 4. Starts the single-pass walk.
 *
 * Params:
 *      fd = The function to analyze.
 *      sc = The scope of the function.
 */
void fastDFA(FuncDeclaration fd, Scope* sc)
{
    import dmd.dfa.fast.structure;
    import dmd.dfa.fast.expression;
    import dmd.dfa.fast.statement;
    import dmd.dfa.fast.analysis;
    import dmd.dfa.fast.report;
    import dmd.dfa.utils;

    if (fd.skipCodegen)
    {
        // No point running DFA on code that'll never run but has already passed CTFE.
        // Takes into account CTFE, typeof, traits compiles, CTFE, and static if/assert.
        return;
    }
    else if (fd.isInstantiated)
    {
        // If its a template instantiation,
        //  we'll also check the scopes to see if it known to have a CT only access.

        if (sc.isKnownToHaveACompileTimeContext)
            return;
    }

    // Use these if statements for debugging specific things.
    //if (fd.ident.toString != "theSitchFinally2") return;
    //if (!(fd.ident.toString == "checkViaObjNullDeref" || fd.ident.toString == "typeNextIterate")) return;
    //if (fd.loc.linnum != 54) return;
    //if (fd.getModule.ident.toString != "doc") return;
    //if (strcmp(mangleExact(fd), "_D5ocean4util9container5cache16ExpiringLRUCache__TQvTSQCaQBxQBvQBo20ExpiredCacheReloader__TQzTSQDpQDmQDkQDd25ExpiredCacheReloader_test7TrivialZQCz10CacheValueZQFa19getExpiringOrCreateMFmJbbZPQFi") != 0) return;
    //if (!(strcmp(mangleExact(fd), "?visit@DeduceType@deduceType@@UEAAXPEAVType@@@Z") == 0 || fd.ident.toString == "deduceWildHelper") )return;

    // used in CI to skip tests that do need to error
    version (none)
    {
        if (fd.getModule.ident.toString == "testassert")
            return;
        else if (fd.getModule.ident.toString == "xtest46")
            return;
        else if (fd.getModule.ident.toString == "xtest46_gc")
            return;
        else if (fd.getModule.ident.toString == "b3841")
            return;
        else if (fd.getModule.ident.toString == "fail329")
            return;
        else if (fd.getModule.ident.toString == "fail_scope")
            return;
        else if (fd.getModule.ident.toString == "failcstuff2")
            return;
        else if (fd.getModule.ident.toString == "exe1")
            return;
        else if (fd.getModule.ident.toString == "exe2")
            return;
        else if (fd.getModule.ident.toString == "exe3")
            return;
        else if (fd.getModule.ident.toString == "nullderefcheck_safeonly")
            return;
        else if (fd.getModule.ident.toString == "nullderefcheck")
            return;
        else if (fd.getModule.ident.toString == "testcontracts")
            return;
        else if (fd.getModule.ident.toString == "arraytopointer")
            return;
        else if (fd.getModule.ident.toString == "compile1")
            return;
        else if (fd.getModule.ident.toString == "ctests2")
            return;
        else if (fd.getModule.ident.toString == "fix20425")
            return;
        else if (fd.getModule.ident.toString == "revert_dip1000")
            return;
        else if (fd.getModule.ident.toString == "test19873")
            return;
        else if (fd.getModule.ident.toString == "test22875")
            return;
        else if (fd.getModule.ident.toString == "test22842")
            return;
        else if (fd.getModule.ident.toString == "test22904")
            return;
        else if (fd.getModule.ident.toString == "test23034")
            return;
        else if (fd.getModule.ident.toString == "test23034b")
            return;
        else if (fd.getModule.ident.toString == "test23044")
            return;
        else if (fd.getModule.ident.toString == "test23875")
            return;
        else if (fd.getModule.ident.toString == "test24069")
            return;
        else if (fd.getModule.ident.toString == "testcstuff2")
            return;
        else if (fd.getModule.ident.toString == "testcstuff1")
            return;
        else if (fd.getModule.ident.toString == "complex")
            return;
        else if (fd.getModule.ident.toString == "a12874")
            return;
        else if (fd.getModule.ident.toString == "noreturn2")
            return;
        else if (fd.getModule.ident.toString == "utf") // std.utf
            return;
        else if (fd.getModule.ident.toString == "json") // std.json
            return;
    }

    // Protect functions based upon safetiness of it.
    // It may be desirable to disable some behaviors in @system code, or completely.
    version (none)
    {
        auto ty = fd.type.isTypeFunction;
        assert(ty !is null);
        if (ty.trust != TRUST.safe)
            return;
    }

    DFACommon dfaCommon;
    scope StatementWalker stmtWalker = new StatementWalker;
    ExpressionWalker expWalker;
    DFAAnalyzer analyzer;
    DFAReporter reporter;

    dfaCommon.allocator.dfaCommon = &dfaCommon;
    dfaCommon.currentFunction = fd;

    if (auto ag = fd.isThis)
    {
        if (ag.isClassDeclaration)
            dfaCommon.isCurrentFunctionClassConstructor = fd.ident is Id.ctor;
    }

    stmtWalker.dfaCommon = &dfaCommon;
    expWalker.dfaCommon = &dfaCommon;
    analyzer.dfaCommon = &dfaCommon;
    reporter.dfaCommon = &dfaCommon;

    stmtWalker.expWalker = &expWalker;
    expWalker.stmtWalker = stmtWalker;

    stmtWalker.analyzer = &analyzer;
    expWalker.analyzer = &analyzer;

    analyzer.reporter = &reporter;
    reporter.errorSink = global.errorSink;

    bool errorsPrinted;

    void printOnError()
    {
        if (errorsPrinted)
            return;
        errorsPrinted = true;

        dfaCommon.printIfStructure((ref OutBuffer ob, scope void delegate(const(char)*) prefix) {
            prefix("");
            ob.printf("function dfa %s : %s = %s at %s\n", fd.getModule.ident.toChars,
                mangleExact(fd), fd.toFullSignature, fd.loc.toChars);

            dfaCommon.allocator.allVariables((DFAVar* var) {
                prefix("var");
                ob.printf(" %p base1=%p, base2=%p, dereferenceVar=%p, oldestLifeTimeAllowedDepth=%d<%d, writeCount=%d, unmodel=%d, isScope=%d, isByRef=%d, mayEscapeInitialValue=%d",
                var, var.base1, var.base2, var.dereferenceVar, var.oldestLifeTimeAllowedDepth,
                var.youngestLifeTimeAllowedDepth, var.writeCount, var.unmodellable,
                var.isScope, var.isByRef, var.mayEscapeInitialValue);

                if (var.var !is null)
                {
                    ob.printf(", `%s` at ", var.var.ident.toChars);
                    appendLoc(ob, var.var.loc);
                }

                ob.printf("\n");
            });
            dfaCommon.allocator.allObjects((DFAObject* obj) {
                prefix("object");
                ob.printf(" %p base1=%p, base2=%p, storageFor=%p, derivedFrom=%p, inCell=%p, constrainedBy=%p, mayNotBeExactPointer=%d, minimumDeclaredAtDepth=%d, onTheStack=%d, lifeTimeUnderstood=%d, delayOnReadErrorOfEscape=%d\n",
                obj, obj.base1, obj.base2, obj.storageFor, obj.derivedFrom,
                obj.inCell, obj.constrainedBy, obj.mayNotBeExactPointer, obj.minimumDeclaredAtDepth,
                obj.onTheStack, obj.lifeTimeUnderstood, obj.delayOnReadErrorOfEscape);
            });
        });

        dfaCommon.printIfStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            if (fd.parametersDFAInfo !is null)
                printDFAParameters(fd.parametersDFAInfo);
        });
    }

    dfaCommon.printIfStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
        ob.printf("============================== %s : %s = %s at ",
            fd.getModule.ident.toChars, mangleExact(fd), fd.toFullSignature);

        appendLoc(ob, fd.loc);
        ob.writestring("\n");
    });

    scope (failure)
    {
        if (!dfaCommon.debugStructure)
        {
            printf("ICE: ERROR %s : %s = %s at %s\n", fd.getModule.ident.toChars,
                    mangleExact(fd), fd.toFullSignature, fd.loc.toChars);
            fflush(stdout);
        }
    }

    version (none)
    {
        import dmd.hdrgen;

        OutBuffer buf;
        HdrGenState hgs;
        hgs.vcg_ast = true;
        toCBuffer(fd, buf, hgs);
        printf(buf.extractChars);
    }

    int currentErrors = global.errors;

    try
    {
        timeTraceBeginEvent(TimeTraceEventType.dfa);
        stmtWalker.start(fd);
    }
    finally
    {
        timeTraceEndEvent(TimeTraceEventType.dfa, fd);
    }

    if (currentErrors != global.errors)
    {
        version (none)
        {
            printf("function dfa %s : %s = %s at %s\n", fd.getModule.ident.toChars,
                    mangleExact(fd), fd.toFullSignature, fd.loc.toChars);
        }

        printOnError;
    }

    version (all)
        printOnError;

    version (all)
    {
        if (checkEscapes(fd, sc))
            printOnError;
    }
}

bool checkEscapes(FuncDeclaration fd, Scope* sc)
{
    import dmd.dfa.utils;
    import dmd.printast;

    if (fd.getModule.ident.toString != "__fastdfa_escape_test")
        return false;

    Expression[] expecteds;
    bool found, error;

    foreachUda(fd, sc, (Expression uda) {
        if (auto sl = uda.isStructLiteralExp)
        {
            ArrayLiteralExp al;

            if (sl.sd.ident.toString() == "__FastDFAEscapeTest")
            {
                if ((al = (*sl.elements)[0].isArrayLiteralExp) !is null)
                {
                    if (al.elements !is null)
                        expecteds = (*al.elements)[];
                }

                found = true;
            }
        }

        return 0;
    });

    if (found)
    {
        struct TestParam
        {
            bool present;
            bool escapeIntoNothing;
            bool escapeIntoUnknown;
            ParameterDFAInfo.Inferrable inferrable;
        }

        TestParam nextTestParam()
        {
            if (expecteds.length == 0)
                return TestParam(false);

            TestParam ret = TestParam(true);

            StructLiteralExp sl = expecteds[0].isStructLiteralExp;
            expecteds = expecteds[1 .. $];
            if (sl is null || sl.elements is null)
                return TestParam(true);
            else if (sl.elements.length != 2)
                return TestParam(false);

            IntegerExp ie;

            ret.escapeIntoNothing = (ie = (*sl.elements)[0].isIntegerExp) !is null && ie.value == 1;
            ret.inferrable.escapesInto = (ie = (*sl.elements)[1].isIntegerExp) !is null ? ie.value
                : 0;

            return ret;
        }

        void checkEscapeTest(ref ParameterDFAInfo paramDFAInfo)
        {
            TestParam tp = nextTestParam();
            if (!tp.present)
            {
                printf("Missing UDA param info for param %d\n", paramDFAInfo.parameterId);
                error = true;
                return;
            }

            if (tp.escapeIntoNothing && !paramDFAInfo.inferred.escapeIntoNothing)
            {
                printf("UDA param info param %d missing escapeIntoNothing\n",
                        paramDFAInfo.parameterId);
                error = true;
            }

            if (tp.inferrable.escapesInto != 0 && paramDFAInfo.inferred.escapesInto == 0)
            {
                printf("UDA param info param %d missing escapesInto\n", paramDFAInfo.parameterId);
                error = true;
            }
            else if (tp.inferrable.escapesInto != paramDFAInfo.inferred.escapesInto)
            {
                printf("UDA param info param %d incorrect escapesInto\n", paramDFAInfo.parameterId);
                error = true;
            }
        }

        if (fd.parametersDFAInfo.thisPointer.parameterId == -2)
            checkEscapeTest(fd.parametersDFAInfo.thisPointer);

        foreach (ref paramDFAInfo; fd.parametersDFAInfo.parameters)
            checkEscapeTest(paramDFAInfo);

        foreach (expected; expecteds)
            printAST(expected);
    }
    else
        error = true;

    if (error && !fd.isGenerated && fd.loc.linnum > 999)
    {
        printf("%s test UDA: function %s : %s = %s at #%d\n", found ? "Incompatible".ptr : "Missing".ptr,
                fd.getModule.ident.toChars, mangleExact(fd), fd.toFullSignature, fd.loc.linnum);
        printDFAParameters(fd.parametersDFAInfo);
        return true;
    }
    else
        return false;
}
