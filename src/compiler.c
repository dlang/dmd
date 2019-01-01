
/* Compiler implementation of the D programming language
 * Copyright (C) 2013-2019 by The D Language Foundation, All Rights Reserved
 * All Rights Reserved
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
 * Private helpers for Compiler::paintAsType.
 */

// Write the integer value of 'e' into a unsigned byte buffer.
static void encodeInteger(Expression *e, unsigned char *buffer)
{
    dinteger_t value = e->toInteger();
    int size = (int)e->type->size();

    for (int p = 0; p < size; p++)
    {
        int offset = p;     // Would be (size - 1) - p; on BigEndian
        buffer[offset] = ((value >> (p * 8)) & 0xFF);
    }
}

// Write the bytes encoded in 'buffer' into an integer and returns
// the value as a new IntegerExp.
static Expression *decodeInteger(Loc loc, Type *type, unsigned char *buffer)
{
    dinteger_t value = 0;
    int size = (int)type->size();

    for (int p = 0; p < size; p++)
    {
        int offset = p;     // Would be (size - 1) - p; on BigEndian
        value |= ((dinteger_t)buffer[offset] << (p * 8));
    }

    return new IntegerExp(loc, value, type);
}

// Write the real value of 'e' into a unsigned byte buffer.
static void encodeReal(Expression *e, unsigned char *buffer)
{
    switch (e->type->ty)
    {
        case Tfloat32:
        {
            float *p = (float *)buffer;
            *p = (float)e->toReal();
            break;
        }
        case Tfloat64:
        {
            double *p = (double *)buffer;
            *p = (double)e->toReal();
            break;
        }
        default:
            assert(0);
    }
}

// Write the bytes encoded in 'buffer' into a longdouble and returns
// the value as a new RealExp.
static Expression *decodeReal(Loc loc, Type *type, unsigned char *buffer)
{
    longdouble value;

    switch (type->ty)
    {
        case Tfloat32:
        {
            float *p = (float *)buffer;
            value = ldouble(*p);
            break;
        }
        case Tfloat64:
        {
            double *p = (double *)buffer;
            value = ldouble(*p);
            break;
        }
        default:
            assert(0);
    }

    return new RealExp(loc, value, type);
}

/******************************
 * Encode the given expression, which is assumed to be an rvalue literal
 * as another type for use in CTFE.
 * This corresponds roughly to the idiom *(Type *)&e.
 */

Expression *Compiler::paintAsType(Expression *e, Type *type)
{
    // We support up to 512-bit values.
    unsigned char buffer[64];

    memset(buffer, 0, sizeof(buffer));
    assert(e->type->size() == type->size());

    // Write the expression into the buffer.
    switch (e->type->ty)
    {
        case Tint32:
        case Tuns32:
        case Tint64:
        case Tuns64:
            encodeInteger(e, buffer);
            break;

        case Tfloat32:
        case Tfloat64:
            encodeReal(e, buffer);
            break;

        default:
            assert(0);
    }

    // Interpret the buffer as a new type.
    switch (type->ty)
    {
        case Tint32:
        case Tuns32:
        case Tint64:
        case Tuns64:
            return decodeInteger(e->loc, type, buffer);

        case Tfloat32:
        case Tfloat64:
            return decodeReal(e->loc, type, buffer);

        default:
            assert(0);
    }

    return NULL;    // avoid warning
}

/******************************
 * For the given module, perform any post parsing analysis.
 * Certain compiler backends (ie: GDC) have special placeholder
 * modules whose source are empty, but code gets injected
 * immediately after loading.
 */
void Compiler::loadModule(Module *)
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

