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
    //if (fd.ident.toString != "checkFloatInit5") return;
    //if (!(fd.ident.toString == "replaceReferenceDefinition" || fd.ident.toString == "extractReferences")) return;
    //if (fd.loc.linnum != 54) return;
    //if (fd.getModule.ident.toString != "start") return;
    //if (strcmp(mangleExact(fd), "_D4core9exception15ArraySliceError6__ctorMFNaNbNiNfmmmAyamC6object9ThrowableZCQCyQCwQCp") != 0) return;

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
        printf("function s %s : %s = %s at %s\n", fd.getModule.ident.toChars,
                mangleExact(fd), fd.toFullSignature, fd.loc.toChars);
        fflush(stdout);
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

    stmtWalker.start(fd);

    version (none)
    {
        printf("function e %s : %s = %s at %s\n", fd.getModule.ident.toChars,
                mangleExact(fd), fd.toFullSignature, fd.loc.toChars);
        fflush(stdout);
    }

    dfaCommon.printIfStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
        ob.printf("------------------------------ %s : %s = %s at ",
            fd.getModule.ident.toChars, mangleExact(fd), fd.toFullSignature);

        appendLoc(ob, fd.loc);
        ob.writestring("\n");
    });
}
