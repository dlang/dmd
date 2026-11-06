// https://github.com/dlang/dmd/issues/20709
// EXTRA_SOURCES: imports/imports20709_c.c
// A C header's size_t/ptrdiff_t/hash_t should win over object.d's aliases.

import imports20709_c;

static assert(size_t.sizeof == 4);
static assert(ptrdiff_t.sizeof == 4);
static assert(hash_t.sizeof == 4);

void main()
{
    size_t x = 5;
    accept_size_t(x);

    ptrdiff_t y = -5;
    accept_ptrdiff_t(y);

    hash_t z = 5;
    accept_hash_t(z);
}
