// https://issues.dlang.org/show_bug.cgi?id=22057

struct CodepointSet
{
    static void* ptr;

    CodepointSet opBinary(string op, U)(U)
    {
        return this;
    }

    this(this) { }
}

CodepointSet memoizeExpr(string expr)()
{
    if (false)
        return mixin(expr);
    CodepointSet slot;
    CodepointSet.ptr = &slot;
    return slot;
}

struct unicode
{
    static CodepointSet opDispatch(string name)()
    {
        return CodepointSet();
    }
}

void main()
{
    auto result = memoizeExpr!"unicode.A | unicode.M";
    assert(CodepointSet.ptr == &result); // NRVO
}
