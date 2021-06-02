ForeachType!Range[] array(Range)(Range r)
if (isIterable!Range && !isNarrowString!Range && !isInfinite!Range)
{
    if (__ctfe)
    {
        // Compile-time version to avoid memcpy calls.
        // Also used to infer attributes of array().
        typeof(return) result;
        foreach (e; r)
            result ~= e;
        return result;
    }

    alias E = ForeachType!Range;
    static if (hasLength!Range)
    {
        auto length = r.length;
        if (length == 0)
            return null;

        import std.conv : emplaceRef;

        auto result = (() @trusted => uninitializedArray!(Unqual!E[])(length))();

        // Every element of the uninitialized array must be initialized
        size_t i;
        foreach (e; r)
        {
            emplaceRef!E(result[i], e);
            ++i;
        }
        return (() @trusted => cast(E[]) result)();
    }
    else
    {
        auto a = appender!(E[])();
        foreach (e; r)
        {
            a.put(e);
        }
        return a.data;
    }
}
void foo()
{
    int a;
    int b;
}

void bar()
{
}

void foobar()
{}

void gigi() {
}

void nothing() {}
