// PERMUTE_ARGS:

module test7491;

struct Struct
{
    import object;
    import imports.test7491a;
    import renamed = imports.test7491b;
}

struct AliasThis
{
    Struct _struct;
    alias _struct this;
}

class Base
{
    import object;
    import imports.test7491a;
    import renamed = imports.test7491b;
}

class Derived : Base
{
}

interface Interface
{
    import object;
    import imports.test7491a;
    import renamed = imports.test7491b;
}

class Impl : Interface
{
}

static assert(!__traits(compiles, Struct.object));
static assert(!__traits(compiles, Struct.imports));
static assert(!__traits(compiles, Struct.renamed));
static assert(!__traits(compiles, AliasThis.object));
static assert(!__traits(compiles, AliasThis.imports));
static assert(!__traits(compiles, AliasThis.renamed));
static assert(!__traits(compiles, Base.object));
static assert(!__traits(compiles, Base.imports));
static assert(!__traits(compiles, Base.renamed));
static assert(!__traits(compiles, Derived.object));
static assert(!__traits(compiles, Derived.imports));
static assert(!__traits(compiles, Derived.renamed));
static assert(!__traits(compiles, Interface.object));
static assert(!__traits(compiles, Interface.imports));
static assert(!__traits(compiles, Interface.renamed));
static assert(!__traits(compiles, Impl.object));
static assert(!__traits(compiles, Impl.imports));
static assert(!__traits(compiles, Impl.renamed));

/***************************************************/

import imports.test7491c;
import imports.test7491d;   // std.stdio;
import io = imports.test7491d;

class C1 : B1
{
    void foo()
    {
        writeln();
        imports.test7491d.writeln();
        io.writeln();

        static assert(!__traits(compiles, map!(a=>a)([1,2,3])));
        static assert(!__traits(compiles, imports.test7491e.map!(a=>a)([1,2,3])));
        static assert(!__traits(compiles, algorithm.map!(a=>a)([1,2,3])));
    }
}

class C2 : B2
{
    void foo()
    {
        writeln();
        imports.test7491d.writeln();
        io.writeln();

        map!(a=>a)([1,2,3]);
        imports.test7491e.map!(a=>a)([1,2,3]);
        algorithm.map!(a=>a)([1,2,3]);
    }
}

class C3 : B3
{
    void foo()
    {
        writeln();
        imports.test7491d.writeln();
        io.writeln();

        map!(a=>a)([1,2,3]);
        imports.test7491e.map!(a=>a)([1,2,3]);
        algorithm.map!(a=>a)([1,2,3]);
    }
}
