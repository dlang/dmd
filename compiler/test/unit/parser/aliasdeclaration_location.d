module parser.aliasdeclaration_location;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.declaration : AliasDeclaration;
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

    override void visit(AliasDeclaration ad)
    {
        l = ad.loc;
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

    /*
     * Test index.
     *
     */
    int index_;

    string code()
    {
        return code_;
    }

    string description()
    {
        return description_;
    }

    int index()
    {
        return index_;
    }
}

enum tests = [
    Test("alias type identifier", q{
    alias int a;}, 1),
    Test("alias identifier = type", q{
    import foo.bar;
    alias a = int;
    }, 2),
    Test("alias identifier = type in local scope", q{
struct MyType {
    string foo;
    alias a = Alias!(123);
}
    }, 3),
];

static foreach (test; tests)
{
    @(test.description)
    unittest
    {
        auto t = parseModule("test.d", "            " ~ test.code);

        scope visitor = new Visitor;
        t.module_.accept(visitor);

        static if (test.index == 1)
        {
            assert(visitor.l.linnum == 2);
            assert(visitor.l.charnum  == 5);
        }

        static if (test.index == 2)
        {
            assert(visitor.l.linnum == 3);
            assert(visitor.l.charnum  == 5);
        }

        static if (test.index == 3)
        {
            assert(visitor.l.linnum == 4);
            assert(visitor.l.charnum  == 5);
        }
    }
}
