module parser.conditionalcompilation_location;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.attrib : ConditionalDeclaration, StaticIfDeclaration;
import dmd.globals : Loc;
import dmd.visitor : SemanticTimeTransitiveVisitor;

@beforeEach
void initializeFrontend()
{
    import dmd.frontend : initDMD;

    initDMD();
}

@afterEach
void deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

extern (C++) class Visitor : SemanticTimeTransitiveVisitor
{
    alias visit = typeof(super).visit;
    Loc l;

    override void visit(ConditionalDeclaration cd)
    {
        l = cd.loc;
    }

    override void visit(StaticIfDeclaration sif)
    {
        l = sif.loc;
    }
}

immutable struct Test
{
    /*
     * The description of the unit test.
     *
     * This will go into the UDA attached to the `unittest` block.
     */
    string description_;

    /*
     * The code to parse.
     *
     */
    string code_;

    string code()
    {
        return code_;
    }

    string description()
    {
        return description_;
    }
}

enum tests = [
    Test("`version` symbol and condition on the same line", "version(a)"),
    Test("`version` symbol and condition different lines", "version\n(a)"),
    Test("`version` symbol, condition and parantheses on different lines", "version\n(\na\n)"),

    Test("`debug` symbol and condition on the same line", "debug(a)"),
    Test("`debug` symbol and condition different lines", "debug\n(a)"),
    Test("`debug` symbol, condition and parantheses on different lines", "debug\n(\na\n)"),

    Test("`static if` and condition on the same line", "static if(a)"),
    Test("`static if` and condition different lines", "static if\n(a)"),
    Test("`static if`, condition and parantheses on different lines", "static if\n(\na\n)"),
    Test("`static` and `if` on different lines", "static\nif\n(a)"),
];

static foreach (test; tests)
{
    @(test.description)
    unittest
    {
        auto t = parseModule("test.d", "first_token " ~ test.code);

        scope visitor = new Visitor;
        t.module_.accept(visitor);

        assert(visitor.l.linnum == 1);
        assert(visitor.l.charnum == 13);
        assert(visitor.l.fileOffset == 12);
    }
}
