module dmd.dfa.entry;
import dmd.dfa.common;
import dmd.dfa.fast.expression;
import dmd.dfa.fast.statement;
import dmd.dfa.fast.analysis;
import dmd.func;
import dmd.astenums;
import dmd.globals;
import dmd.mangle;
import core.stdc.stdio;

void dfaEntry(FuncDeclaration fd)
{
    fastDFA(fd);
}

private:

void fastDFA(FuncDeclaration fd)
{
    if (fd.skipCodegen)
        return; // no point running DFA on code that'll never run but has already passed CTFE

    //if (fd.ident.toString != "inreal") return;
    //if (!(fd.ident.toString == "test3632" || fd.ident.toString == "test")) return;
    //if (fd.loc.linnum < 1380) return;
    //if (fd.getModule.ident.toString != "start") return;

    version (none)
    {
        auto ty = fd.type.isTypeFunction;
        assert(ty !is null);
        if (ty.trust == TRUST.system)
            return;
    }

    DFACommon dfaCommon;
    scope StatementWalker stmtWalker = new StatementWalker;
    ExpressionWalker expWalker;
    DFAAnalyzer analyzer;

    stmtWalker.dfaCommon = &dfaCommon;
    expWalker.dfaCommon = &dfaCommon;
    analyzer.dfaCommon = &dfaCommon;

    stmtWalker.expWalker = &expWalker;
    expWalker.stmtWalker = stmtWalker;

    stmtWalker.analyzer = &analyzer;
    expWalker.analyzer = &analyzer;

    if (dfaCommon.debugStructure)
    {
        printf("============================== %s : %s = %s at %s\n",
                fd.getModule.ident.toChars, mangleExact(fd), fd.toFullSignature, fd.loc.toChars);
        fflush(stdout);
    }

    scope (exit)
    {
        if (dfaCommon.debugStructure)
        {
            printf("------------------------------ %s : %s = %s at %s\n",
                    fd.getModule.ident.toChars, mangleExact(fd),
                    fd.toFullSignature, fd.loc.toChars);
            fflush(stdout);
        }
    }

    scope (failure)
    {
        if (!dfaCommon.debugStructure)
        {
            printf("ICE: ERROR %s : %s = %s at %s\n", fd.getModule.ident.toChars,
                    mangleExact(fd), fd.toFullSignature, fd.loc.toChars);
            fflush(stdout);
        }
    }

    stmtWalker.start(fd);
}
