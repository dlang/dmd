module parser.dvcondition_location;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.cond : VersionCondition, DebugCondition;
import dmd.location;
import dmd.visitor : SemanticTimeTransitiveVisitor;

@beforeEach initializeFrontend()
{
    import dmd.frontend : initDMD;

    initDMD();
}

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

extern (C++) static class Visitor : SemanticTimeTransitiveVisitor
{
    alias visit = typeof(super).visit;
    Loc l;

    override void visit(VersionCondition vc)
    {
        l = vc.loc;
    }

    override void visit(DebugCondition dc)
    {
        l = dc.loc;
    }
}

@("version(identifier)")
unittest
{
    auto t = parseModule("test.d", "version(a)");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 9);
}

@("debug(identifier)")
unittest
{
    auto t = parseModule("test.d", "debug(a)");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 7);
}
