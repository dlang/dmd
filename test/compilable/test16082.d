// https://issues.dlang.org/show_bug.cgi?id=16082

module modulename;

struct S
{
    struct Inner
    {
        int any_name_but_modulename;
        int modulename;
    }

    Inner inner;
    alias inner this;

    auto works()
    {
        return any_name_but_modulename;
    }
    auto fails()
    {
        return modulename;  // Line 20
    }
}
