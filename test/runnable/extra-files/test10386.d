module test10386;

// import lib.foo.bar;  // ok
import lib10386.foo;  // linker failure

void main()
{
    static assert(foo.mangleof == "_D8lib103863foo3bar3fooFiZv");
    foo(1);
}

