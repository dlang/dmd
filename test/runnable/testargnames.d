/*
PERMUTE_ARGS:
*/

// to optionally avoid depending on phobos
version (easy_debug)
    enum easy_debug = true;
else
    enum easy_debug = false;

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

string getLoc(string file = __FILE__, int line = __LINE__)
{
    return text(file, ":", line, " ");
}

void check(string[] name, string[] expected, string file = __FILE__, int line = __LINE__)
{
    assert(name.length == expected.length, text(getLoc(file, line), name, " ", expected));
    foreach (i; 0 .. name.length)
        check(name[i], expected[i], file, line);
}

void check(string name, string expected, string file = __FILE__, int line = __LINE__)
{
    if (name == expected)
        return;
    assert(0, text(getLoc(file, line), "expected {", expected, "} got {", name, "}"));
}

void fun1(int a, string expected, string name = __traits(getCallerSource, a),
        string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

void fun2(int a, string b, double c, string expected,
        string name = __traits(getCallerSource, b), string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

void fun_UFCS(int a, string expected, string name = __traits(getCallerSource, a),
        string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

void fun_template(T)(T a, string expected, string name = __traits(getCallerSource, a),
        string file = __FILE__, int line = __LINE__)
{
    check(name, expected, file, line);
}

auto fun_variadic(T...)(T a_var, string[T.length] names = __traits(getCallerSource, a_var))
{
    return names;
}

// more complex variadic
auto fun_variadic2(T...)(int a0, T a1, int a2, int a3 = 1000,
        string[T.length] names = __traits(getCallerSource, a1),
        string name_a2 = __traits(getCallerSource, a2), int a6 = 10000)
{
    return names ~ "-" ~ name_a2;
}

struct A
{
    int x = 1;

    int myfun()
    {
        return x * x;
    }
}

// Simple yet useful log function
static if (easy_debug)
{

    string log(T...)(T a, string[T.length] names = __traits(getCallerSource, a),
            string file = __FILE__, int line = __LINE__)
    {
        string ret = getLoc(file, line);
        static foreach (i; 0 .. T.length)
                {
                ret ~= text(" ", names[i], ":", a[i]);
            }
        return ret;
    }

    string logSimple(T...)(T a, string[T.length] names = __traits(getCallerSource, a))
    {
        import std.conv;

        return text(names, ": ", a);
    }

}

void main()
{
    int a = 42;

    static if (easy_debug)
    {
        {
            check(log(a), text(getLoc, ` a:42`));
            string b = "bar";
            check(log(a + 1, b), text(getLoc, ` a + 1:43 b:bar`));

            double x = 1.5;
            check(logSimple(x * 2, 'a'), `["x * 2", "'a'"]: 3a`);
            check(logSimple(__LINE__), text(`["__LINE__"]: `, __LINE__));
        }
    }

    fun1(41 + a, `41 + a`);

    string bar = "bob";
    fun2(41 + a, "foo" ~ bar, 0.0, `"foo" ~ bar`);

    (1 + 1).fun_UFCS("1 + 1");

    fun_template(1 + 3, `1 + 3`);

    fun1(a + a + a, `a + a + a`);

    // Checks that no constant folding happens
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

    // variadic test
    {
        auto ret = fun_variadic(1 + 1 + 1, "foo");
        static assert(ret.length == 2);
        check(ret, [`1 + 1 + 1`, `"foo"`]);
    }
    {
        auto ret = fun_variadic(1 + 1 + 1);
        static assert(ret.length == 1);
        check(ret, [`1 + 1 + 1`]);
    }
    {
        auto ret = fun_variadic();
        static assert(ret.length == 0);
        check(ret, []);
    }
    // complex variadic test
    {
        check(fun_variadic2(-0, 11, 12, 13, 100), ["11", "12", "13", "-", "100"]);
        check(fun_variadic2(-0, 11, 12, 100), ["11", "12", "-", "100"]);
        check(fun_variadic2(-0, 11, 100), ["11", "-", "100"]);
        // UFCS
        check(0.fun_variadic2(11, 100), ["11", "-", "100"]);
        // empty tuple
        check(fun_variadic2(0, 100), ["-", "100"]);

        // explicit instantiation
        check(fun_variadic2!int(0, 11, 100), ["11", "-", "100"]);
    }

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
