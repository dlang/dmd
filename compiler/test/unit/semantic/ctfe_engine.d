// Tests for the CTFE engine hook

module semantic.ctfe_engine;

import dmd.arraytypes : Expressions;
import dmd.dinterpret : ctfeEngine;
import dmd.expression : Expression, IntegerExp;
import dmd.frontend : deinitializeDMD, initDMD;
import dmd.func : FuncDeclaration;
import dmd.typesem : nextOf;

import support : afterEach, beforeEach, compiles;

@beforeEach void initializeFrontend()
{
    initDMD();
}

@afterEach void deinitializeFrontend()
{
    ctfeEngine = null;
    deinitializeDMD();
}

// Minimal engine, only handles `a + b` on two integers.
// The sum is wrong on purpose, to check that it ran and not the interpreter.
Expression addEngine(FuncDeclaration fd, Expressions* arguments)
{
    auto cs = fd.fbody.isCompoundStatement();
    if (!cs || cs.statements.length != 1)
        return null;

    auto rs = cs.statements[0].isReturnStatement();
    if (!rs || !rs.exp.isAddExp() || arguments.length != 2)
        return null;

    auto a = (*arguments)[0].isIntegerExp();
    auto b = (*arguments)[1].isIntegerExp();
    if (!a || !b)
        return null;

    return new IntegerExp(fd.loc, a.getInteger() + b.getInteger() + 2, fd.type.nextOf());
}

@("ctfe engine - additions tests only")
unittest
{
    ctfeEngine = &addEngine;

    auto result = compiles(q{
        int add(int a, int b) { return a + b; }
        int mul(int a, int b) { return a * b; }
        int twice(int a) { return add(a, a); }

        static assert(add(3, 3) == 8);
        static assert(mul(3, 3) == 9);
        static assert(twice(3) == 6); // the inner call to add is not top-level
    });
    assert(result, result.toString());
}
