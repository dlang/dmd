// https://issues.dlang.org/show_bug.cgi?id=22228

auto f()
{   immutable int i;
    auto p = (() => &i)();

    return 0;
}

enum ctfeInvocation = f;
