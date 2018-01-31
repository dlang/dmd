/*
PERMUTE_ARGS:
*/

// to optionally avoid depending on phobos
enum easy_debug = true;

static if (easy_debug)
{
    import std.conv : text;
    import core.stdc.stdio;
}
else
{
    string text(T...)(T a)
    {
        return "";
    }
}

void check(string name, string expected, string file = __FILE__, int line = __LINE__)
{
    if (name == expected)
        return;
    assert(0, text("expected {", expected, "} got {", name, "} at ", file, ":", line));
}

// Simple yet useful log function
string log(T)(T a, string name = __ARG_STRING__!a)
{
    return text(name, ":", a);
}

void fun1(int a, string expected, string name = __ARG_STRING__!a,
        string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

void fun2(int a, string b, double c, string expected,
        string name = __ARG_STRING__!b, string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

void fun_UFCS(int a, string expected, string name = __ARG_STRING__!a,
        string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

void fun_template(T)(T a, string expected, string name = __ARG_STRING__!a,
        string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

struct A
{
    int x = 1;

    int myfun()
    {
        return x * x;
    }
}

void main()
{
    int a = 42;

    check(log(1 + a), `1 + a:43`);

    fun1(41 + a, `41 + a`);

    string bar = "bob";
    fun2(41 + a, "foo" ~ bar, 0.0, `"foo" ~ bar`);

    (1 + 1).fun_UFCS("1 + 1");

    fun_template(1 + 3, `1 + 3`);

    fun1(a + a + a, `a + a + a`);

    // Checks that no constant folding happens, cf D20180130T161632.
    fun1(1 + 1 + 2, `1 + 1 + 2`);

    static const int x = 44;
    fun1(x + x + x, `x + x + x`);

    fun1(A.init.x + A(a).myfun(), `A.init.x + A(a).myfun()`);

    enum t = 44;
    fun1(t + t, `t + t`);

    // parenthesis are removed:
    fun1((t + t), `t + t`);

    // Check that special tokens dont't get expanded
    fun1(__LINE__, "__LINE__");
    fun_template(__FILE__, "__FILE__");

    // Formatting intentionally bad to test behavior
    {
        // dfmt off
    // Tests behavior when argument is not pretty-printed, eg: `t+t` instead of `t + t`
    fun1(t+t, `t+t`);

    // Tests behavior with trailing whitespace
    fun_template(1 ,`1`);

    // Tests behavior with weird whitespace
    fun_template(
      "foo"  
~ " bar", `"foo"  
~ " bar"`);

    // Tests behavior with comments
    fun_template(  "foo" ~ /+ comment +/ "bar", `"foo" ~ /+ comment +/ "bar"`);
    // dfmt on
    }

    // Tests that still works with #line primitive
    // dfmt bug:https://github.com/dlang-community/dfmt/issues/321
    // dfmt off
    #line 100
    fun1(t + 1, `t + 1`);

    #line 200 "anotherfile"
    fun1(t + 1, `t + 1`);
    // dfmt on
}
