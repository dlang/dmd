module ddmd.gencmain;

import ddmd.dmodule;
import ddmd.dscope;
import ddmd.parse;
import ddmd.astcodegen;

import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.tokens;

/// DMD-generated module `__entrypoint` where the C main resides
extern (C++) __gshared Module entrypoint = null;
/// Module in which the D main is
extern (C++) __gshared Module rootHasMain = null;


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
extern (C++) void genCmain(Scope* sc)
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
    p.scanloc = Loc();
    p.nextToken();
    m.members = p.parseModule();
    assert(p.token.value == TOKeof);
    assert(!p.errors); // shouldn't have failed to parse it
    bool v = global.params.verbose;
    global.params.verbose = false;
    m.importedFrom = m;
    m.importAll(null);
    m.semantic(null);
    m.semantic2(null);
    m.semantic3(null);
    global.params.verbose = v;
    entrypoint = m;
    rootHasMain = sc._module;
}
