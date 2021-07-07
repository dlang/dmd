/**
 * Test the C++ compiler interface of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2017-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     Iain Buclaw
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/tests/cxxfrontend.c, _cxxfrontend.c)
 */

#include "root/array.h"
#include "root/bitarray.h"
#include "root/ctfloat.h"
#include "root/dcompat.h"
#include "root/dsystem.h"
#include "root/file.h"
#include "root/filename.h"
#include "root/longdouble.h"
#include "root/object.h"
#include "root/outbuffer.h"
#include "root/port.h"
#include "root/rmem.h"

#include "aggregate.h"
#include "aliasthis.h"
#include "arraytypes.h"
#include "ast_node.h"
#include "attrib.h"
#include "compiler.h"
#include "complex_t.h"
#include "cond.h"
#include "ctfe.h"
#include "declaration.h"
#include "doc.h"
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
#include "json.h"
#include "mangle.h"
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
    global.vendor = "Front-End Tester";
    global.params.objname = NULL;

    target.os = Target::OS_linux;
    target.is64bit = true;
    target.cpu = CPU::native;
    target._init(global.params);

    Type::_init();
    Id::initialize();
    Module::_init();
    Expression::_init();
    Objc::_init();
    CTFloat::initialize();
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

void test_tokens()
{
    // First valid TOK value
    assert(TOKlparen == 1);
    assert(strcmp(Token::toChars(TOKlparen), "(") == 0);

    // Last valid TOK value
    assert(TOK__attribute__ == TOKMAX - 1);
    assert(strcmp(Token::toChars(TOKvectorarray), "vectorarray") == 0);
}

void test_compiler_globals()
{
    // only check constant prefix of version
    assert(strncmp(global.versionChars(), "v2.", 3) == 0);
    unsigned versionNumber = global.versionNumber();
    assert(versionNumber >= 2060 && versionNumber <= 3000);

    assert(strcmp(target.architectureName.ptr, "X86_64") == 0 ||
           strcmp(target.architectureName.ptr, "X86") == 0);
}

/**********************************/

class TestVisitor : public Visitor
{
  using Visitor::visit;

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
    bool function;

    TestVisitor() : expr(false), package(false), stmt(false), type(false),
        aggr(false), attrib(false), decl(false), typeinfo(false), idexpr(false),
        function(false)
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

    void visit(FuncDeclaration *)
    {
        function = true;
    }
};

void test_visitors()
{
    TestVisitor tv;
    Loc loc;
    Identifier *ident = Identifier::idPool("test");

    IntegerExp *ie = IntegerExp::create(loc, 42, Type::tint32);
    ie->accept(&tv);
    assert(tv.expr == true);

    IdentifierExp *id = IdentifierExp::create (loc, ident);
    id->accept(&tv);
    assert(tv.idexpr == true);

    Module *mod = Module::create("test", ident, 0, 0);
    assert(mod->isModule() == mod);
    mod->accept(&tv);
    assert(tv.package == true);

    ExpStatement *es = ExpStatement::create(loc, ie);
    assert(es->isExpStatement() == es);
    es->accept(&tv);
    assert(tv.stmt == true);

    TypePointer *tp = TypePointer::create(Type::tvoid);
    assert(tp->hasPointers() == true);
    tp->accept(&tv);
    assert(tv.type == true);

    LinkDeclaration *ld = LinkDeclaration::create(loc, LINK::d, NULL);
    assert(ld->isAttribDeclaration() == static_cast<AttribDeclaration *>(ld));
    assert(ld->linkage == LINK::d);
    ld->accept(&tv);
    assert(tv.attrib == true);

    ClassDeclaration *cd = ClassDeclaration::create(loc, Identifier::idPool("TypeInfo"), NULL, NULL, true);
    assert(cd->isClassDeclaration() == cd);
    assert(cd->vtblOffset() == 1);
    cd->accept(&tv);
    assert(tv.aggr == true);

    AliasDeclaration *ad = AliasDeclaration::create(loc, ident, tp);
    assert(ad->isAliasDeclaration() == ad);
    ad->storage_class = STCabstract;
    assert(ad->isAbstract() == true);
    ad->accept(&tv);
    assert(tv.decl == true);

    cd = ClassDeclaration::create(loc, Identifier::idPool("TypeInfo_Pointer"), NULL, NULL, true);
    TypeInfoPointerDeclaration *ti = TypeInfoPointerDeclaration::create(tp);
    assert(ti->isTypeInfoDeclaration() == ti);
    assert(ti->tinfo == tp);
    ti->accept(&tv);
    assert(tv.typeinfo == true);

    Parameters *args = new Parameters;
    TypeFunction *tf = TypeFunction::create(args, Type::tvoid, VARARGnone, LINK::c);
    FuncDeclaration *fd = FuncDeclaration::create(Loc (), Loc (), Identifier::idPool("test"),
                                                  STCextern, tf);
    assert(fd->isFuncDeclaration() == fd);
    assert(fd->type == tf);
    fd->accept(&tv);
    assert(tv.function == true);
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

    FileBuffer *srcBuffer = FileBuffer::create(); // free'd in Module::parse()
    srcBuffer->data = DArray<unsigned char>(strlen(buf), (unsigned char *)mem.xstrdup(buf));

    Module *m = Module::create("object.d", Identifier::idPool("object"), 0, 0);

    unsigned errors = global.startGagging();

    m->srcBuffer = srcBuffer;
    m->parse();
    m->importedFrom = m;
    m->importAll(NULL);
    dsymbolSemantic(m, NULL);
    semantic2(m, NULL);
    semantic3(m, NULL);

    Dsymbol *s = m->search(Loc(), Identifier::idPool("Error"));
    assert(s);
    AggregateDeclaration *ad = s->isAggregateDeclaration();
    assert(ad && ad->ctor && ad->sizeok == Sizeok::done);
    CtorDeclaration *ctor = ad->ctor->isCtorDeclaration();
    assert(ctor->isMember() && !ctor->isNested());
    assert(0 == strcmp(ctor->type->toChars(), "Error(string)"));

    ClassDeclaration *cd = ad->isClassDeclaration();
    assert(cd && cd->hasMonitor());

    assert(!global.endGagging(errors));
}

/**********************************/

void test_skip_importall()
{
    /* Similar to test_semantic(), but importAll step is skipped.  */
    const char *buf =
        "module rootobject;\n"
        "class RootObject : Object { }";

    FileBuffer *srcBuffer = FileBuffer::create(); // free'd in Module::parse()
    srcBuffer->data = DArray<unsigned char>(strlen(buf), (unsigned char *)mem.xstrdup(buf));

    Module *m = Module::create("rootobject.d", Identifier::idPool("rootobject"), 0, 0);

    unsigned errors = global.startGagging();

    m->srcBuffer = srcBuffer;
    m->parse();
    m->importedFrom = m;
    dsymbolSemantic(m, NULL);
    semantic2(m, NULL);
    semantic3(m, NULL);

    assert(!global.endGagging(errors));
}

/**********************************/

void test_expression()
{
    Loc loc;
    IntegerExp *ie = IntegerExp::create(loc, 42, Type::tint32);
    Expression *e = ie->ctfeInterpret();

    assert(e);
    assert(e->isConst());
}

/**********************************/

void test_target()
{
    assert(target.isVectorOpSupported(Type::tint32, TOKpow));
}

/**********************************/

void test_emplace()
{
    Loc loc;
    UnionExp ue;

    IntegerExp::emplace(&ue, loc, 1065353216, Type::tint32);
    Expression *e = ue.exp();
    assert(e->op == TOKint64);
    assert(e->toInteger() == 1065353216);

    UnionExp ure;
    Expression *re = Compiler::paintAsType(&ure, e, Type::tfloat32);
    assert(re->op == TOKfloat64);
    assert(re->toReal() == CTFloat::one);

    UnionExp uie;
    Expression *ie = Compiler::paintAsType(&uie, re, Type::tint32);
    assert(ie->op == TOKint64);
    assert(ie->toInteger() == e->toInteger());
}

/**********************************/

void test_parameters()
{
    Parameters *args = new Parameters;
    args->push(Parameter::create(STCundefined, Type::tint32, NULL, NULL, NULL));
    args->push(Parameter::create(STCundefined, Type::tint64, NULL, NULL, NULL));

    TypeFunction *tf = TypeFunction::create(args, Type::tvoid, VARARGnone, LINK::c);

    assert(tf->parameterList.length() == 2);
    assert(tf->parameterList[0]->type == Type::tint32);
    assert(tf->parameterList[1]->type == Type::tint64);
    assert(!tf->isDstyleVariadic());
}

/**********************************/

void test_types()
{
    Parameters *args = new Parameters;
    StorageClass stc = STCnothrow|STCproperty|STCreturn|STCreturninferred|STCtrusted;
    TypeFunction *tfunction = TypeFunction::create(args, Type::tvoid, VARARGnone, LINK::d, stc);

    assert(tfunction->isnothrow());
    assert(!tfunction->isnogc());
    assert(tfunction->isproperty());
    assert(!tfunction->isref());
    tfunction->isref(true);
    assert(tfunction->isref());
    assert(tfunction->isreturn());
    assert(!tfunction->isScopeQual());
    assert(tfunction->isreturninferred());
    assert(!tfunction->isscopeinferred());
    assert(tfunction->linkage == LINK::d);
    assert(tfunction->trust == TRUST::trusted);
    assert(tfunction->purity == PURE::impure);
}

/**********************************/

void test_location()
{
    Loc loc1 = Loc("test.d", 24, 42);
    assert(loc1.equals(Loc("test.d", 24, 42)));
    assert(strcmp(loc1.toChars(true, MESSAGESTYLEdigitalmars), "test.d(24,42)") == 0);
    assert(strcmp(loc1.toChars(true, MESSAGESTYLEgnu), "test.d:24:42") == 0);
}

/**********************************/

void test_array()
{
    Array<double> array;
    array.setDim(4);
    array.shift(10);
    array.push(20);
    array[2] = 15;
    assert(array[0] == 10);
    assert(array.find(10) == 0);
    assert(array.find(20) == 5);
    assert(!array.contains(99));
    array.remove(1);
    assert(array.length == 5);
    assert(array[1] == 15);
    assert(array.pop() == 20);
    assert(array.length == 4);
    array.insert(1, 30);
    assert(array[1] == 30);
    assert(array[2] == 15);

    Array<int> arrayA;
    array.setDim(0);
    int buf[3] = {10, 15, 20};
    arrayA.push(buf[0]);
    arrayA.push(buf[1]);
    arrayA.push(buf[2]);
    assert(memcmp(arrayA.tdata(), buf, sizeof(buf)) == 0);
    Array<int> *arrayPtr = arrayA.copy();
    assert(arrayPtr);
    assert(memcmp(arrayPtr->tdata(), arrayA.tdata(), arrayA.length * sizeof(int)) == 0);
    assert(arrayPtr->tdata() != arrayA.tdata());

    arrayPtr->setDim(0);
    int buf2[2] = {100, 200};
    arrayPtr->push(buf2[0]);
    arrayPtr->push(buf2[1]);

    arrayA.append(arrayPtr);
    assert(memcmp(arrayA.tdata() + 3, buf2, sizeof(buf2)) == 0);
    arrayA.insert(0, arrayPtr);
    assert(arrayA[0] == 100);
    assert(arrayA[1] == 200);
    assert(arrayA[2] == 10);
    assert(arrayA[3] == 15);
    assert(arrayA[4] == 20);
    assert(arrayA[5] == 100);
    assert(arrayA[6] == 200);

    arrayA.zero();
    for (size_t i = 0; i < arrayA.length; i++)
        assert(arrayA[i] == 0);
}

void test_outbuffer()
{
    OutBuffer buf;
    mangleToBuffer(Type::tint64, &buf);
    assert(strcmp(buf.peekChars(), "l") == 0);
    buf.reset();

    buf.reserve(16);
    buf.writestring("hello");
    buf.writeByte(' ');
    buf.write(&buf);
    buf.writenl();
    assert(buf.length() == 13);

    const char *data = buf.extractChars();
    assert(buf.length() == 0);
    assert(strcmp(data, "hello hello \n") == 0);
}

void test_cppmangle()
{
    // Based off runnable_cxx/cppa.d.
    const char *buf =
        "module cppa;\n"
        "extern (C++):\n"
        "class Base { void based() { } }\n"
        "interface Interface { int MethodCPP(); int MethodD(); }\n"
        "class Derived : Base, Interface { int MethodCPP(); int MethodD() { return 3; } }";

    FileBuffer *srcBuffer = FileBuffer::create(); // free'd in Module::parse()
    srcBuffer->data = DArray<unsigned char>(strlen(buf), (unsigned char *)mem.xstrdup(buf));

    Module *m = Module::create("cppa.d", Identifier::idPool("cppa"), 0, 0);

    unsigned errors = global.startGagging();
    FuncDeclaration *fd;
    const char *mangle;

    m->srcBuffer = srcBuffer;
    m->parse();
    m->importedFrom = m;
    m->importAll(NULL);
    dsymbolSemantic(m, NULL);
    semantic2(m, NULL);
    semantic3(m, NULL);

    Dsymbol *s = m->search(Loc(), Identifier::idPool("Derived"));
    assert(s);
    ClassDeclaration *cd = s->isClassDeclaration();
    assert(cd && cd->sizeok == Sizeok::done);
    assert(cd->members && cd->members->length == 2);
    assert(cd->vtblInterfaces && cd->vtblInterfaces->length == 1);
    BaseClass *b = (*cd->vtblInterfaces)[0];

    fd = (*cd->members)[0]->isFuncDeclaration();
    assert(fd);
    mangle = cppThunkMangleItanium(fd, b->offset);
    assert(strcmp(mangle, "_ZThn8_N7Derived9MethodCPPEv") == 0);

    fd = (*cd->members)[1]->isFuncDeclaration();
    assert(fd);
    mangle = cppThunkMangleItanium(fd, b->offset);
    assert(strcmp(mangle, "_ZThn8_N7Derived7MethodDEv") == 0);

    assert(!global.endGagging(errors));
}

void test_module()
{
    unsigned errors = global.startGagging();
    Module *mod = Module::load(Loc(), NULL, Identifier::idPool("doesnotexist.d"));
    assert(mod == NULL);
    assert(global.endGagging(errors));
}

/**********************************/

int main(int argc, char **argv)
{
    frontend_init();

    test_tokens();
    test_compiler_globals();
    test_visitors();
    test_semantic();
    test_skip_importall();
    test_expression();
    test_target();
    test_emplace();
    test_parameters();
    test_types();
    test_location();
    test_array();
    test_outbuffer();
    test_cppmangle();
    test_module();

    frontend_term();

    return 0;
}
