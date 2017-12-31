/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/compiler.d, _compiler.d)
 * Documentation:  https://dlang.org/phobos/dmd_compiler.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/compiler.d
 */

module dmd.compiler;

import dmd.astcodegen;
import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbolsem;
import dmd.expression;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.parse;
import dmd.root.ctfloat;
import dmd.semantic2;
import dmd.semantic3;
import dmd.tokens;

/// DMD-generated module `__entrypoint` where the C main resides
package __gshared Module entrypoint = null;
/// Module in which the D main is
package __gshared Module rootHasMain = null;

/**
 * A data structure that describes a back-end compiler and implements
 * compiler-specific actions.
 */
struct Compiler
{
    /**
     * Generate C main() in response to seeing D main().
     *
     * This function will generate a module called `__entrypoint`,
     * and set the globals `entrypoint` and `rootHasMain`.
     *
     * This used to be in druntime, but contained a reference to _Dmain
     * which didn't work when druntime was made into a dll and was linked
     * to a program, such as a C++ program, that didn't have a _Dmain.
     *
     * Params:
     *   sc = Scope which triggered the generation of the C main,
     *        used to get the module where the D main is.
     */
    extern (C++) static void genCmain(Scope* sc)
    {
        if (entrypoint)
            return;
        /* The D code to be generated is provided as D source code in the form of a string.
         * Note that Solaris, for unknown reasons, requires both a main() and an _main()
         */
        immutable cmaincode =
        q{
            extern(C)
            {
                int _d_run_main(int argc, char **argv, void* mainFunc);
                int _Dmain(char[][] args);
                int main(int argc, char **argv)
                {
                    return _d_run_main(argc, argv, &_Dmain);
                }
                version (Solaris) int _main(int argc, char** argv) { return main(argc, argv); }
            }
        };
        Identifier id = Id.entrypoint;
        auto m = new Module("__entrypoint.d", id, 0, 0);
        scope p = new Parser!ASTCodegen(m, cmaincode, false);
        p.scanloc = Loc.initial;
        p.nextToken();
        m.members = p.parseModule();
        assert(p.token.value == TOK.endOfFile);
        assert(!p.errors); // shouldn't have failed to parse it
        bool v = global.params.verbose;
        global.params.verbose = false;
        m.importedFrom = m;
        m.importAll(null);
        m.dsymbolSemantic(null);
        m.semantic2(null);
        m.semantic3(null);
        global.params.verbose = v;
        entrypoint = m;
        rootHasMain = sc._module;
    }

    /******************************
     * Encode the given expression, which is assumed to be an rvalue literal
     * as another type for use in CTFE.
     * This corresponds roughly to the idiom *(Type *)&e.
     */
    extern (C++) static Expression paintAsType(Expression e, Type type)
    {
        // We support up to 512-bit values.
        ubyte[64] buffer;
        assert(e.type.size() == type.size());
        // Write the expression into the buffer.
        switch (e.type.ty)
        {
        case Tint32:
        case Tuns32:
        case Tint64:
        case Tuns64:
            encodeInteger(e, buffer.ptr);
            break;
        case Tfloat32:
        case Tfloat64:
            encodeReal(e, buffer.ptr);
            break;
        default:
            assert(0);
        }
        // Interpret the buffer as a new type.
        switch (type.ty)
        {
        case Tint32:
        case Tuns32:
        case Tint64:
        case Tuns64:
            return decodeInteger(e.loc, type, buffer.ptr);
        case Tfloat32:
        case Tfloat64:
            return decodeReal(e.loc, type, buffer.ptr);
        default:
            assert(0);
        }
    }

    /******************************
     * For the given module, perform any post parsing analysis.
     * Certain compiler backends (ie: GDC) have special placeholder
     * modules whose source are empty, but code gets injected
     * immediately after loading.
     */
    extern (C++) static void loadModule(Module m)
    {
    }
}

/******************************
 * Private helpers for Compiler::paintAsType.
 */
// Write the integer value of 'e' into a unsigned byte buffer.
private void encodeInteger(Expression e, ubyte* buffer)
{
    dinteger_t value = e.toInteger();
    int size = cast(int)e.type.size();
    for (int p = 0; p < size; p++)
    {
        int offset = p; // Would be (size - 1) - p; on BigEndian
        buffer[offset] = ((value >> (p * 8)) & 0xFF);
    }
}

// Write the bytes encoded in 'buffer' into an integer and returns
// the value as a new IntegerExp.
private Expression decodeInteger(const ref Loc loc, Type type, ubyte* buffer)
{
    dinteger_t value = 0;
    int size = cast(int)type.size();
    for (int p = 0; p < size; p++)
    {
        int offset = p; // Would be (size - 1) - p; on BigEndian
        value |= (cast(dinteger_t)buffer[offset] << (p * 8));
    }
    return new IntegerExp(loc, value, type);
}

// Write the real_t value of 'e' into a unsigned byte buffer.
private void encodeReal(Expression e, ubyte* buffer)
{
    switch (e.type.ty)
    {
    case Tfloat32:
        {
            float* p = cast(float*)buffer;
            *p = cast(float)e.toReal();
            break;
        }
    case Tfloat64:
        {
            double* p = cast(double*)buffer;
            *p = cast(double)e.toReal();
            break;
        }
    default:
        assert(0);
    }
}

// Write the bytes encoded in 'buffer' into a real_t and returns
// the value as a new RealExp.
private Expression decodeReal(const ref Loc loc, Type type, ubyte* buffer)
{
    real_t value;
    switch (type.ty)
    {
    case Tfloat32:
        {
            float* p = cast(float*)buffer;
            value = real_t(*p);
            break;
        }
    case Tfloat64:
        {
            double* p = cast(double*)buffer;
            value = real_t(*p);
            break;
        }
    default:
        assert(0);
    }
    return new RealExp(loc, value, type);
}
