/**
 * Test the C++ compiler interface of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2017-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     Iain Buclaw
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/tests/cxxfrontend.c, _cxxfrontend.c)
 */

#include "array.h"
#include "ctfloat.h"
#include "file.h"
#include "filename.h"
#include "longdouble.h"
#include "object.h"
// FIXME: UINT64_MAX
//#include "outbuffer.h"
//#include "port.h"
#include "rmem.h"
//#include "root.h"
//#include "stringtable.h"
#include "thread.h"

#include "visitor.h"
#include "frontend.h"

/**********************************/

extern "C" int rt_init();
extern "C" void gc_disable();

static void frontend_init()
{
    rt_init();
    gc_disable();

    global._init();
    global.params.isLinux = true;
    global.vendor = "Front-End Tester";

    Type::_init();
    Id::initialize();
    Module::_init();
    Expression::_init();
    Objc::_init();
    Target::_init();
}

/**********************************/

extern "C" int rt_term();
extern "C" void gc_enable();

static void frontend_term()
{
  gc_enable();
  rt_term();
}

/**********************************/

class TestVisitor : public Visitor
{
  public:
    bool expr;
    bool package;
    bool stmt;
    bool type;
    bool aggr;
    bool attrib;
    bool decl;
    bool typeinfo;
    bool idexpr;

    TestVisitor() : expr(false), package(false), stmt(false), type(false),
        aggr(false), attrib(false), decl(false), typeinfo(false), idexpr(false)
    {
    }

    void visit(Expression *)
    {
        expr = true;
    }

    void visit(IdentifierExp *)
    {
        idexpr = true;
    }

    void visit(Package *)
    {
        package = true;
    }

    void visit(Statement *)
    {
        stmt = true;
    }

    void visit(AttribDeclaration *)
    {
        attrib = true;
    }

    void visit(Declaration *)
    {
        decl = true;
    }

    void visit(AggregateDeclaration *)
    {
        aggr = true;
    }

    void visit(TypeNext *)
    {
        type = true;
    }

    void visit(TypeInfoDeclaration *)
    {
        typeinfo = true;
    }
};

void test_visitors()
{
    TestVisitor tv;
    Loc loc;
    Identifier *ident = Identifier::idPool("test");

    IntegerExp *ie = IntegerExp::createi(loc, 42, Type::tint32);
    ie->accept(&tv);
    assert(tv.expr == true);

    IdentifierExp *id = IdentifierExp::create (loc, ident);
    id->accept(&tv);
    assert(tv.idexpr == true);

    Module *mod = Module::create("test", ident, 0, 0);
    mod->accept(&tv);
    assert(tv.package == true);

    ExpStatement *es = ExpStatement::create(loc, ie);
    es->accept(&tv);
    assert(tv.stmt == true);

    TypePointer *tp = TypePointer::create(Type::tvoid);
    tp->accept(&tv);
    assert(tv.type == true);

    LinkDeclaration *ld = LinkDeclaration::create(LINKd, NULL);
    ld->accept(&tv);
    assert(tv.attrib == true);

    ClassDeclaration *cd = ClassDeclaration::create(loc, Identifier::idPool("TypeInfo"), NULL, NULL, true);
    cd->accept(&tv);
    assert(tv.aggr = true);

    AliasDeclaration *ad = AliasDeclaration::create(loc, ident, tp);
    ad->accept(&tv);
    assert(tv.decl == true);

    cd = ClassDeclaration::create(loc, Identifier::idPool("TypeInfo_Pointer"), NULL, NULL, true);
    TypeInfoPointerDeclaration *ti = TypeInfoPointerDeclaration::create(tp);
    ti->accept(&tv);
    assert(tv.typeinfo == true);
}

/**********************************/

void test_semantic()
{
    /* Mini object.d source. Module::parse will add internal members also. */
    const char *buf =
        "module object;\n"
        "class Object { }\n"
        "class Throwable { }\n"
        "class Error : Throwable { this(immutable(char)[]); }";

    Module *m = Module::create("object.d", Identifier::idPool("object"), 0, 0);

    unsigned errors = global.startGagging();

    m->srcfile->setbuffer((void*)buf, strlen(buf));
    m->srcfile->ref = 1;
    m->parse();
    m->importedFrom = m;
    m->importAll(NULL);
    dsymbolSemantic(m, NULL);
    semantic2(m, NULL);
    semantic3(m, NULL);

    assert(!global.endGagging(errors));
}

/**********************************/

void test_expression()
{
    Loc loc;
    IntegerExp *ie = IntegerExp::createi(loc, 42, Type::tint32);
    Expression *e = ie->ctfeInterpret();

    assert(e);
    assert(e->isConst());
}

/**********************************/

int main(int argc, char **argv)
{
    frontend_init();

    test_visitors();
    test_semantic();
    test_expression();

    frontend_term();

    return 0;
}
