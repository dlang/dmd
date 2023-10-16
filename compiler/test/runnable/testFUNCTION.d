// https://issues.dlang.org/show_bug.cgi?id=23403
struct Context
{
    string pretty_function;
}

void test23403(Context ctx = Context(__FUNCTION__))
{
    assert(ctx.pretty_function == "testFUNCTION.main");
}

// https://issues.dlang.org/show_bug.cgi?id=23408
string foo(string arg)
{
    return arg;
}

void test23408(string s = foo(__FUNCTION__))
{
    assert(s == "testFUNCTION.main");
}

void main()
{
    test23403();
    test23408();
}
