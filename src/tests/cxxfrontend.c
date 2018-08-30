/**
 * Test the C++ compiler interface of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2017-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     Iain Buclaw
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/tests/cxxfrontend.c, _cxxfrontend.c)
 */

#include "root/array.h"
#include "root/ctfloat.h"
#include "root/dcompat.h"
#include "root/file.h"
#include "root/filename.h"
#include "root/longdouble.h"
#include "root/object.h"
#include "root/outbuffer.h"
#include "root/port.h"
#include "root/rmem.h"
#include "root/root.h"
#include "root/stringtable.h"
#include "root/thread.h"

#include "aggregate.h"
#include "aliasthis.h"
#include "arraytypes.h"
#include "attrib.h"
#include "compiler.h"
#include "complex_t.h"
#include "cond.h"
#include "ctfe.h"
#include "declaration.h"
#include "dsymbol.h"
#include "enum.h"
#include "errors.h"
#include "expression.h"
#include "globals.h"
#include "hdrgen.h"
#include "identifier.h"
#include "id.h"
#include "import.h"
#include "init.h"
#include "intrange.h"
#include "json.h"
#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "nspace.h"
#include "objc.h"
#include "scope.h"
#include "statement.h"
#include "staticassert.h"
#include "target.h"
#include "template.h"
#include "tokens.h"
#include "version.h"
#include "visitor.h"

/**********************************/

extern "C" int rt_init();
extern "C" void gc_disable();

static void frontend_init()
{
    rt_init();
    gc_disable();

    global._init();
    global.params.isLinux = true;

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

    TestVisitor() : expr(false), package(false), stmt(false), type(false),
        aggr(false), attrib(false), decl(false), typeinfo(false)
    {
    }

    void visit(Expression *)
    {
        expr = true;
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

int main(int argc, char **argv)
{
    frontend_init();

    test_visitors();
    test_semantic();

    frontend_term();

    return 0;
}
