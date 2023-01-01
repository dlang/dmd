module parser.visibilitydeclaration_location;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.attrib : VisibilityDeclaration;
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

    override void visit(VisibilityDeclaration vd)
    {
        l = vd.loc;
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
    Test("`public` symbol and curly braces on the next line", q{class C
    {
    public
    {
        void foo() {}
    }
    }}),
    Test("`public` symbol and colon on the same line", q{class C
    {
    public:
        void foo() {}
    }}),
    Test("`public` symbol and function declaration on the same line", q{class C
    {
    public void foo() {}
    }}),
];

static foreach (test; tests)
{
    @(test.description)
    unittest
    {
        auto t = parseModule("test.d", test.code);

        scope visitor = new Visitor;
        t.module_.accept(visitor);

        assert(visitor.l.linnum == 3);
        assert(visitor.l.charnum == 5);
    }
}
