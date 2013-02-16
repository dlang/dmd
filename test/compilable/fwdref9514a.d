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

import imports.fwdref9514 : find;  // selective import without aliasing

template FieldNames()
{
    static if (find!`true`([1])) enum int FieldNames = 1;
}
