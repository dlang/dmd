// REQUIRED_ARGS: -Irunnable/imports
// EXTRA_SOURCES: imports/standalone_b.d
// PERMUTE_ARGS: -cov

import standalone_b;
import core.attribute : standalone;

immutable int* x;

// https://github.com/dlang/dmd/issues/23117
// a standalone ctor must run exactly once, even when several modules in the
// same compilation define one and form an import cycle.
__gshared int aCount;

@standalone @system shared static this()
{
    x = new int(1);
    ++aCount;
}

void main()
{
    assert(*x == 1);
    assert(*y == 2);
    assert(aCount == 1);
    assert(bCount == 1);
}
