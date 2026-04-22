/*
REQUIRED_ARGS: -w
TEST_OUTPUT:
----
----
*/

struct LintParams {
    bool enabled = true;
    bool constSpecial = true;
    bool unusedParams = true;
}

enum MyLintParams = LintParams(true, false, false);

pragma(lint, MyLintParams);

struct TestStruct
{
    bool opEquals(ref const TestStruct other) { return true; }
}

class A
{
    void foo(int x)
    {
    }
}

void main()
{
}
