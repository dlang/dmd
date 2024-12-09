// https://issues.dlang.org/show_bug.cgi?id=20800

/*
TEST_OUTPUT:
----
fail_compilation/fail20800.d(27): Error: function `fun` is not callable using argument types `(string)`
    fun(m.index);
       ^
fail_compilation/fail20800.d(27):        cannot pass argument `(m()).index()` of type `string` to parameter `int a`
fail_compilation/fail20800.d(23):        `fail20800.fun(int a)` declared here
void fun(int a);
     ^
----
*/

struct RegexMatch
{
    string index() { return null; }
    ~this() { }
}
static m() { return RegexMatch(); }

void fun(int a);

void initCommands()
{
    fun(m.index);
}
