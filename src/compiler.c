
/* Compiler implementation of the D programming language
 * Copyright (C) 2013-2020 by The D Language Foundation, All Rights Reserved
 * written by Iain Buclaw
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/compiler.c
 */

#include "root/dsystem.h" // for std::numeric_limits

#include "expression.h"
#include "id.h"
#include "module.h"
#include "mtype.h"
#include "parse.h"
#include "tokens.h"
#include "scope.h"

/******************************
 * Encode the given expression, which is assumed to be an rvalue literal
 * as another type for use in CTFE.
 * This corresponds roughly to the idiom *(Type *)&e.
 */

Expression *Compiler::paintAsType(UnionExp *pue, Expression *e, Type *type)
{
    union U
    {
        d_int32 int32value;
        d_int64 int64value;
        float float32value;
        double float64value;
    };
    U u;

    assert(e->type->size() == type->size());

    switch (e->type->ty)
    {
        case Tint32:
        case Tuns32:
            u.int32value = (d_int32)e->toInteger();
            break;
        case Tint64:
        case Tuns64:
            u.int64value = (d_int64)e->toInteger();
            break;

        case Tfloat32:
            u.float32value = (float)e->toReal();
            break;

        case Tfloat64:
            u.float64value = (double)e->toReal();
            break;

        default:
            assert(0);
    }

    switch (type->ty)
    {
        case Tint32:
        case Tuns32:
            new(pue) IntegerExp(e->loc, u.int32value, type);
            break;

        case Tint64:
        case Tuns64:
            new(pue) IntegerExp(e->loc, u.int64value, type);
            break;

        case Tfloat32:
            new(pue) RealExp(e->loc, ldouble(u.float32value), type);
            break;

        case Tfloat64:
            new(pue) RealExp(e->loc, ldouble(u.float64value), type);
            break;

        default:
            assert(0);
    }

    return pue->exp();
}

/******************************
 * For the given module, perform any post parsing analysis.
 * Certain compiler backends (ie: GDC) have special placeholder
 * modules whose source are empty, but code gets injected
 * immediately after loading.
 */
void Compiler::onParseModule(Module *)
{
}

Module *entrypoint = NULL;
Module *rootHasMain = NULL;

/************************************
 * Generate C main() in response to seeing D main().
 * This used to be in druntime, but contained a reference to _Dmain
 * which didn't work when druntime was made into a dll and was linked
 * to a program, such as a C++ program, that didn't have a _Dmain.
 */

void Compiler::genCmain(Scope *sc)
{
    if (entrypoint)
        return;

    /* The D code to be generated is provided as D source code in the form of a string.
     * Note that Solaris, for unknown reasons, requires both a main() and an _main()
     */
    static const utf8_t cmaincode[] = "extern(C) {\n\
        int _d_run_main(int argc, char **argv, void* mainFunc);\n\
        int _Dmain(char[][] args);\n\
        int main(int argc, char **argv) { return _d_run_main(argc, argv, &_Dmain); }\n\
        version (Solaris) int _main(int argc, char** argv) { return main(argc, argv); }\n\
        }\n\
        ";

    Identifier *id = Id::entrypoint;
    Module *m = new Module("__entrypoint.d", id, 0, 0);

    Parser p(m, cmaincode, strlen((const char *)cmaincode), 0);
    p.scanloc = Loc();
    p.nextToken();
    m->members = p.parseModule();
    assert(p.token.value == TOKeof);
    assert(!p.errors);                  // shouldn't have failed to parse it

    bool v = global.params.verbose;
    global.params.verbose = false;
    m->importedFrom = m;
    m->importAll(NULL);
    m->semantic(NULL);
    m->semantic2(NULL);
    m->semantic3(NULL);
    global.params.verbose = v;

    entrypoint = m;
    rootHasMain = sc->_module;
}

