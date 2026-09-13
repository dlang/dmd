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

// A goto can jump into a statically unreachable branch, making it
// reachable at runtime -- such branches must not be treated as
// trivially unreachable for NRVO purposes.
struct S22057
{
    static void* ptr;
    this(this) { }
}

S22057 gotoIntoDeadBranch(bool cond)
{
    if (false)
    {
    Lret:
        S22057 b;
        return b;
    }
    S22057 a;
    S22057.ptr = &a;
    if (cond)
        goto Lret;
    return a;
}

void main()
{
    auto result = memoizeExpr!"unicode.A | unicode.M";
    assert(CodepointSet.ptr == &result); // NRVO

    auto r = gotoIntoDeadBranch(false);
    assert(S22057.ptr != &r); // NRVO correctly disabled: goto makes the dead branch reachable
}
