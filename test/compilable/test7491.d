// PERMUTE_ARGS:

module test7491;
import imports.test7491a;
import imports.test7491b;   // std.stdio;
import io = imports.test7491b;

class C1 : B1
{
    void foo()
    {
        writeln();
        imports.test7491b.writeln();
        io.writeln();

        static assert(!__traits(compiles, map!(a=>a)([1,2,3])));
        static assert(!__traits(compiles, imports.test7491c.map!(a=>a)([1,2,3])));
        static assert(!__traits(compiles, algorithm.map!(a=>a)([1,2,3])));
    }
}

class C2 : B2
{
    void foo()
    {
        writeln();
        imports.test7491b.writeln();
        io.writeln();

        map!(a=>a)([1,2,3]);
        imports.test7491c.map!(a=>a)([1,2,3]);
        algorithm.map!(a=>a)([1,2,3]);
    }
}

class C3 : B3
{
    void foo()
    {
        writeln();
        imports.test7491b.writeln();
        io.writeln();

        map!(a=>a)([1,2,3]);
        imports.test7491c.map!(a=>a)([1,2,3]);
        algorithm.map!(a=>a)([1,2,3]);
    }
}
