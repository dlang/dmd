module dmd.dfa.entry;
import dmd.dfa.common;
import dmd.dfa.fast.expression;
import dmd.dfa.fast.statement;
import dmd.dfa.fast.analysis;
import dmd.func;
import dmd.astenums;
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

    //if (fd.ident.toString != "__lambda_L345_C1") return;
    //if (fd.loc.linnum != 244) return;

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
        printf("==============================\n");

    scope (exit)
    {
        if (dfaCommon.debugStructure)
            printf("------------------------------\n");
    }

    stmtWalker.start(fd);
}
