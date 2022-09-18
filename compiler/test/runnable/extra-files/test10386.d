module test10386;

// import lib.foo.bar;  // ok
import lib10386.foo;  // linker failure

import imports.testmangle;

void main()
{
    static assert(equalDemangle(foo.mangleof, "_D8lib103863foo3bar3fooFiZv"));
    foo(1);
}

