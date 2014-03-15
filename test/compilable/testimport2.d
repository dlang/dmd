// REQUIRED_ARGS: -Icompilable/extra-files
// PERMUTE_ARGS:
// EXTRA_SOURCE: imports/imp2a.d
// EXTRA_SOURCE: imports/imp2b.d
// EXTRA_SOURCE: imports/imp2c.d

import imports.imp2a;

void main()
{
    // public symbols which directly imported are visible
    foo();
    imports.imp2a.foo(); // by FQN
    {
        alias A = imports.imp2a;
        A.foo();
        static assert(!__traits(compiles, A.bar()));
        A.baz();
    }

    // public symbols through private import are invisible
    static assert(!__traits(compiles, bar()));
    static assert(!__traits(compiles, imports.imp2b.bar()));
    // FQN of privately imported module is invisible
    static assert(!__traits(compiles, imports.imp2b.stringof));
    {
        static assert(!__traits(compiles, { alias B = imports.imp2b; }));
    }

    // public symbols which indirectly imported through public import are visible
    baz();
    imports.imp2c.baz(); // by FQN
    // FQN of publicly imported module is visible
    static assert(imports.imp2c.stringof == "module imp2c");
    {
        alias C = imports.imp2c;
        static assert(!__traits(compiles, C.foo()));
        static assert(!__traits(compiles, C.bar()));
        C.baz();
    }

    // Import Declaration itself should not have FQN
    static assert(!__traits(compiles, imports.imp2a.imports.imp2b.bar()));
    static assert(!__traits(compiles, imports.imp2a.imports.imp2c.baz()));

    // Applying Module Scope Operator to package/module FQN
    .imports.imp2a.foo();
    static assert(!__traits(compiles, .imports.imp2b.bar()));
    .imports.imp2c.baz();
}
