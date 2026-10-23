// https://github.com/dlang/dmd/issues/20709
// EXTRA_SOURCES: imports/imports20709_c.c

/+ A C header imported via ImportC that declares its own `size_t` with a
 + different width than object.d's convenience alias used to be rejected
 + as an ambiguous symbol. The C header's own declaration should take
 + priority over object.d's implicit import. +/

import imports20709_c;

static assert(size_t.sizeof == 4);

void test()
{
    size_t x = 5;
    accept_size_t(x);
}
