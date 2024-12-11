/+
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/fail24208.d(23): Error: reference to local variable `n` assigned to non-scope parameter `p` calling `escape`
    escape(&n);
           ^
fail_compilation/fail24208.d(19):        which is not `scope` because of `escaped = p`
        escaped = p;
                ^
---
+/
void test() @safe
{
    int* escaped;

    void escape(int* p) @safe
    {
        escaped = p;
    }

    int n;
    escape(&n);
}
