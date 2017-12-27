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
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.parse;
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
}
