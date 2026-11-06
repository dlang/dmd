// EXTRA_SOURCES: imports/cinline_unanalysed.c

// The ImportC unreferenced-inline scan must only walk analysed code: enum members
// without a value have a null initializer until semantic assigns one.

import cinline_unanalysed;

version (none)
{
    enum InExcludedVersion { a }
}

static if (false)
{
    enum InExcludedStaticIf { a }
}
else
{
    enum InIncludedStaticIf { a }
}

static foreach (i; 0 .. 1)
{
    enum InStaticForeach { a }
    int call_from_static_foreach() { return from_static_foreach(); }
}

template Uninstantiated()
{
    enum InTemplate { a }
}

template Instantiated()
{
    enum InTemplate { a }
    int call() { return from_template(); }
}

void main()
{
    assert(call_from_static_foreach() == 1);
    assert(Instantiated!().call() == 2);
}
