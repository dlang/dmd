module parser.uda_location;

import dmd.frontend : parseModule;
import support : afterEach, beforeEach;
import dmd.expression : UDAItem;
import dmd.declaration : VarDeclaration;
import dmd.func : FuncDeclaration;
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
    Loc[] l;

    this()
    {
        l = [];
    }

    override void visit(UDAItem i)
    {
        l ~= i.loc;
    }
}

@("variable declaration: @(3) int a;")
unittest
{
    auto t = parseModule("test.d", "@(3) int a;");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("identifier: @(3) a")
unittest
{
    auto t = parseModule("test.d", "@(3) a");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("function declaration: @(3) int a(){ return 0; }")
unittest
{
    auto t = parseModule("test.d", "@(3) int a(){ return 0; }");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    import std.stdio;
    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("struct: @(3) struct a{}")
unittest
{
    auto t = parseModule("test.d", "@(3) struct a{}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("function declaration: @(3) int a(){ return 0; }")
unittest
{
    auto t = parseModule("test.d", "@(3) int a(){ return 0; }");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("constructor: this() @(3) {}")
unittest
{
    auto t = parseModule("test.d", "this() @(3) {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 8);
}

@("destructor: ~this() @(3) {}")
unittest
{
    auto t = parseModule("test.d", "~this() @(3) {}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 9);
}

@("module declaration: @(3) module test")
unittest
{
    auto t = parseModule("test.d", "@(3) module test;");

    scope visitor = new Visitor;
    t.module_.userAttribDecl.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("multiple separated attributes: @(3) @b int a;")
unittest
{
    auto t = parseModule("test.d", "@(3) @b int a;");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 2);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
    assert(visitor.l[1].linnum == 1);
    assert(visitor.l[1].charnum == 6);
}

@("multiple attributes in same array: @(3, b) int a;")
unittest
{
    auto t = parseModule("test.d", "@(3, b) int a;");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("atributes on multiple lines: @(3) @b int a;")
unittest
{
    auto t = parseModule("test.d", "@(3)\r\n@b\r\nint a;");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 2);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
    assert(visitor.l[1].linnum == 2);
    assert(visitor.l[1].charnum == 1);
}

@("declaration in block: @(3) { int a; }")
unittest
{
    auto t = parseModule("test.d", "@(3) { int a; }");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("mltiple declarations in block: @(3) { int a; int b;}")
unittest
{
    auto t = parseModule("test.d", "@(3) { int a; int b;}");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("declaration after colon: @(3): int a;")
unittest
{
    auto t = parseModule("test.d", "@(3): int a;");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("multiple declarations after colon: @(3): int a; int b;")
unittest
{
    auto t = parseModule("test.d", "@(3):\r\n int a;\r\n int b;");

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 1);
    assert(visitor.l[0].linnum == 1);
    assert(visitor.l[0].charnum == 1);
}

@("mixed")
unittest
{
    auto t = parseModule("test.d", q{
        @(3):
        @(4) {
            @(5)
            @(6) int a;
        }
    });

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.l.length == 4);
    assert(visitor.l[0].linnum == 2);
    assert(visitor.l[0].charnum == 9);
    assert(visitor.l[1].linnum == 3);
    assert(visitor.l[1].charnum == 9);
    assert(visitor.l[2].linnum == 4);
    assert(visitor.l[2].charnum == 13);
    assert(visitor.l[3].linnum == 5);
    assert(visitor.l[3].charnum == 13);
}
