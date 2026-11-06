// https://github.com/dlang/dmd/issues/24131
// EXTRA_SOURCES: imports/c24131.c

import c24131;

void main()
{
    *get() = 0;
    set();
}
