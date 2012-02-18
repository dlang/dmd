module test73;

import imports.test73;

// test overloads with mixed protection
void baz()
{
    foo();
    bar(0);
    foot();
    bart(0);

    static assert(!__traits(compiles, foo(0)));
    static assert(!__traits(compiles, bar()));
    static assert(!__traits(compiles, foot(0)));
    static assert(!__traits(compiles, bart()));
}
