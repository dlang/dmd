// PERMUTE_ARGS:
// REQUIRED_ARGS: -o-

template TStructHelpers()
{
    void opEquals(Foo)
    {
        auto n = FieldNames!();
    }
}

struct Foo
{
    mixin TStructHelpers!();
}

import imports.fwdref9514 : foo = find;  // selective import with aliasing

template FieldNames()
{
    static if (foo!`true`([1])) enum int FieldNames = 1;
}
