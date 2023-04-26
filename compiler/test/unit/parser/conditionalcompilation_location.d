module parser.conditionalcompilation_location;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.attrib : ConditionalDeclaration, StaticIfDeclaration, StaticForeachDeclaration;
import dmd.location;
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

    override void visit(StaticForeachDeclaration sfd)
    {
        l = sfd.loc;
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

    Test("`static foreach` and condition on the same line", "static foreach(a; b)"),
    Test("`static foreach` and condition different lines", "static foreach\n(a; b)"),
    Test("`static foreach`, condition and parantheses on different lines", "static foreach\n(\na; b\n)"),
    Test("`static` and `foreach` on different lines", "static\nforeach\n(a; b)"),

    Test("`static foreach_reverse` and condition on the same line", "static foreach_reverse(a; b)"),
    Test("`static foreach_reverse` and condition different lines", "static foreach_reverse\n(a; b)"),
    Test("`static foreach_reverse`, condition and parantheses on different lines", "static foreach_reverse\n(\na; b\n)"),
    Test("`static` and `foreach_reverse` on different lines", "static\nforeach_reverse\n(a; b)"),
];

static foreach (test; tests)
{
    @(test.description)
    unittest
    {
        auto t = parseModule("test.d", "            " ~ test.code);

        scope visitor = new Visitor;
        t.module_.accept(visitor);

        assert(visitor.l.linnum == 1);
        assert(visitor.l.charnum == 13);
        assert(visitor.l.fileOffset == 12);
    }
}
