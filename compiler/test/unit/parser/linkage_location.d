module parser.linkage_location;

import dmd.frontend : parseModule, initDMD, deinitializeDMD;
import dmd.attrib : CPPMangleDeclaration, CPPNamespaceDeclaration, LinkDeclaration;
import dmd.location;
import dmd.visitor : SemanticTimeTransitiveVisitor;

extern (C++) static class LinkVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = typeof(super).visit;
    Loc[] locs;

    override void visit(CPPMangleDeclaration md)
    {
        locs ~= md.loc;
    }

    override void visit(CPPNamespaceDeclaration nd)
    {
        locs ~= nd.loc;

        if (nd.decl.length)
        {
            CPPNamespaceDeclaration next = cast(CPPNamespaceDeclaration)nd.decl.pop();
            next.accept(this);
        }
    }

    override void visit(LinkDeclaration ld)
    {
        locs ~= ld.loc;
    }
}

void testLocs(string src, int[2][] lineCols...)
{
    initDMD();

    auto t = parseModule("test.d", src);

    scope visitor = new LinkVisitor;
    t.module_.accept(visitor);

    // import std; writeln(visitor.locs.map!SourceLoc);

    assert(visitor.locs.length == lineCols.length);
    foreach (i, lineCol; lineCols)
    {
        assert(visitor.locs[i].linnum == lineCol[0]);
        assert(visitor.locs[i].charnum == lineCol[1]);
    }

    deinitializeDMD();
}

unittest
{
    testLocs("extern (C++, struct) class C {}",  [1, 1]);
    testLocs("extern (C++, struct) struct S {}", [1, 1]);
    testLocs("extern (C++, class) class C {}",   [1, 1]);
    testLocs("extern (C++, class) struct C {}",  [1, 1]);
    testLocs("extern (C++, struct) {}",          [1, 1]);
    testLocs("extern (C++, class) {}",           [1, 1]);
    testLocs(`extern (C++, "namespace") {}`,     [1, 1]);
    testLocs(`extern (C++, "name"~"space") {}`,  [1, 1]);

    testLocs("            extern(C++) int a;",      [1, 13]);
    testLocs("            extern(C++) void f();",   [1, 13]);
    testLocs("            extern(C++) struct C {}", [1, 13]);
    testLocs("            extern(C++) class C {}",  [1, 13]);
    testLocs("alias t = extern(C++) void f();",     [1, 11]);

    testLocs(`extern (C++, "ns1", "ns2", "ns3") {}`, [1, 1], [1, 1], [1, 1]);
    testLocs("extern (C++, 'ns1')\nextern(C++, 'ns2') {}", [1, 1], [2, 1]);
    testLocs(`extern (C++, "ns1") extern(C++, "ns2") {}`, [1, 1], [1, 21]);
}
