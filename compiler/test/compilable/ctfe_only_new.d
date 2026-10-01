/*
DFLAGS:
REQUIRED_ARGS: -conf= -betterC
EXTRA_SOURCES: extra-files/ctfe_only_new/object.d
LINK:
*/

// A `@__ctfe` function is never code generated, so its `new` must not be lowered to
// the `_d_newclassT` runtime hook, which this minimal runtime does not have.
// Linked, so that no reference to the hook is emitted either.

class C
{
    int x;
    this(int x) { this.x = x; }
}

int make(int x) @__ctfe
{
    auto c = new C(x);
    return c.x;
}

static assert(make(3) == 3);

extern (C) int main()
{
    return 0;
}
