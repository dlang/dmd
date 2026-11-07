module parser.seh_catch_flag;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.statement : Catch, TryCatchStatement;
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
    Catch found;

    override void visit(TryCatchStatement s)
    {
        found = (*s.catches)[0];
        super.visit(s);
    }
}

@("__try/__except sets fromSEH")
unittest
{
    auto t = parseModule("seh_catch_flag_1.c",
        "void f(void) { __try { } __except (1) { } }");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.found !is null);
    assert(visitor.found.fromSEH);
    assert(visitor.found.internalCatch);
}

@("a freshly constructed Catch is not from SEH")
unittest
{
    import dmd.location : Loc;

    auto c = new Catch(Loc.initial, null, null, null);
    assert(!c.fromSEH);
}
