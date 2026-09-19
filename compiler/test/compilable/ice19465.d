enum string s = "__traits(compiles, mixin(s))";

static if (__traits(compiles, mixin(s)))
{
    enum b = 2;
}
