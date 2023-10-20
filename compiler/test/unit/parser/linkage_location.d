module parser.linkage_location;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.attrib : CPPMangleDeclaration, CPPNamespaceDeclaration, LinkDeclaration;
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

    override void visit(CPPMangleDeclaration md)
    {
        l = md.loc;
    }

    override void visit(CPPNamespaceDeclaration nd)
    {
        l = nd.loc;
    }
}

// Testing cpp mangling

@("extern (C++, struct) class")
unittest
{
    auto t = parseModule("test.d", "extern (C++, struct) class C {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

@("extern (C++, struct) struct")
unittest
{
    auto t = parseModule("test.d", "extern (C++, struct) struct S {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

@("extern (C++, class) class")
unittest
{
    auto t = parseModule("test.d", "extern (C++, class) class C {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

@("extern (C++, class) struct")
unittest
{
    auto t = parseModule("test.d", "extern (C++, class) struct C {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

@("extern (C++, struct) {}")
unittest
{
    auto t = parseModule("test.d", "extern (C++, struct) {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

@("extern (C++, class) {}")
unittest
{
    auto t = parseModule("test.d", "extern (C++, class) {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

// Testing namespaces

@(`"namespace"`)
unittest
{
    auto t = parseModule("test.d", `extern (C++, "namespace") {}`);

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

@(`"name"~"space"`)
unittest
{
    auto t = parseModule("test.d", `extern (C++, "name"~"space") {}`);

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 1);
}

extern (C++) static class NamespaceVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = typeof(super).visit;
    Loc[] l;

    override void visit(CPPNamespaceDeclaration nd)
    {
        l ~= nd.loc;
        if (nd.decl.length) {
            CPPNamespaceDeclaration next = cast(CPPNamespaceDeclaration)nd.decl.pop();
            next.accept(this);
        }
    }
}

@("multiple namespaces - comma separated")
unittest
{
    auto t = parseModule("test.d", `extern (C++, "ns1", "ns2", "ns3") {}`);

    scope visitor = new NamespaceVisitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 3);
    foreach (Loc l; visitor.l) {
        assert(l.linnum == 1);
        assert(l.charnum == 1);
    }
}

@("multiple namespaces - same line")
unittest
{
    auto t = parseModule("test.d", `extern (C++, "ns1") extern(C++, "ns2") {}`);

    scope visitor = new NamespaceVisitor;
    t.module_.accept(visitor);
    int charnum = 1;

    assert(visitor.l.length == 2);
    foreach (Loc l; visitor.l) {
        assert(l.linnum == 1);
        assert(l.charnum == charnum);
        charnum += 20;
    }
}

@("multiple namespaces - different lines")
unittest
{
    auto t = parseModule("test.d", "extern (C++, 'ns1')\nextern(C++, 'ns2') {}");

    scope visitor = new NamespaceVisitor;
    t.module_.accept(visitor);
    int linnum = 1;

    assert(visitor.l.length == 2);
    foreach (Loc l; visitor.l) {
        assert(l.linnum == linnum);
        assert(l.charnum == 1);
        linnum++;
    }
}

// Testing linkage

extern (C++) static class LinkVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = typeof(super).visit;
    Loc l;

    override void visit(LinkDeclaration ld)
    {
        l = ld.loc;
    }
}

@("extern(C++) variable")
unittest
{
    auto t = parseModule("test.d", "            extern(C++) int a;");

    scope visitor = new LinkVisitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 13);
}

@("extern(C++) function")
unittest
{
    auto t = parseModule("test.d", "            extern(C++) void f();");

    scope visitor = new LinkVisitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 13);
}

@("extern(C++) struct")
unittest
{
    auto t = parseModule("test.d", "            extern(C++) struct C {}");

    scope visitor = new LinkVisitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 13);
}

@("extern(C++) class")
unittest
{
    auto t = parseModule("test.d", "            extern(C++) class C {}");

    scope visitor = new LinkVisitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 13);
}

@("alias t = extern(C++) void f();")
unittest
{
    auto t = parseModule("test.d", "alias t = extern(C++) void f();");

    scope visitor = new LinkVisitor;
    t.module_.accept(visitor);

    assert(visitor.l.linnum == 1);
    assert(visitor.l.charnum == 11);
}
