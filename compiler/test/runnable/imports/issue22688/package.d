module issue22688;

import issue22688.bar;

struct bar
{
    static int zen() => 2;
}

void test22688()
{
    // The module function and the struct function must have
    // different mangled names to avoid linker collisions.
    // The struct parent component gets a leading zero prefix:
    // module bar -> "3bar", struct bar -> "03bar".
    static assert(zen.mangleof != bar.zen.mangleof,
        "Module and struct functions must have different mangles");

    // Module-level zen: issue22688.bar.zen (bar is a module)
    // Struct-level zen: issue22688.bar.zen (bar is a struct, gets leading zero)
    static assert(zen.mangleof == "_D10issue226883bar3zenFZi",
        "Module function zen should use normal module mangling");
    static assert(bar.zen.mangleof == "_D10issue2268803bar3zenFZi",
        "Struct function zen should use zero-padded struct mangling");

    assert(zen() == 1);
    assert(bar.zen() == 2);
}
