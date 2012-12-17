// PERMUTE_ARGS:
// REQUIRED_ARGS: -M -Mdtest_results/compilable
// POST_SCRIPT: compilable/extra-files/mixin-postscript.sh

module foo.bar;

void foo()
{
    auto a = mixin("5 + 3");
    mixin(
        "int a1 = 5;\n"
        "int b1 = 10;\n"
        "auto res1 = a1 * b1;\n"
    );

    mixin("
          int a2 = 5;
          int b2 = 10;
          auto res2 = a2 * b2;
");
}

string exp1()
{
    return "5 + 3";
}

string stmt1()
{
    string s = "int s1a = 5;\n";
    s ~= "int s1b = 10;\n";
    s ~= "auto s1res = s1a * s1b;\n";
    return s;
}

enum e1 = exp1();
enum s1 = stmt1();

void bar()
{
    auto e1res = mixin(e1);
    mixin(s1);
}

// Only generate output for string mixins
mixin template Foo()
{
    int x = 5;
}

mixin Foo;

struct Bar {
    mixin Foo;
}

mixin template Foo2()
{
    int a = 5;
    int b = 3;
    mixin(bar2nested());
}

mixin("
int bar2()
{
    mixin Foo2;
    return result();
}
");

string bar2nested()
{
    return "
    int result()
    {
        auto tmp = a + mixin(bar2nested2());
        return tmp;
    };";
}

string bar2nested2()
{
    return "getb";
}

@property int getb()
{
    return 6;
}

void main()
{
    bar();
    bar2();
}
