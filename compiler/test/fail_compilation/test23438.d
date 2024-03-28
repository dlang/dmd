/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test23438.d(114): Error: scope variable `x` assigned to global variable `escaped`
---
*/

// https://github.com/dlang/dmd/pull/14601

#line 100

int global;
int* escaped;

void quxfail() @safe
{
    int stack=1337;
    int* foo(return scope int* x) @safe
    {
        int* bar(return scope int* y) @safe
        {
            return x;
        }
        auto p = &bar;
        escaped = bar(&global); // fail
        return x;
    }
    foo(&stack);
}

void quxsucceed() @safe
{
    int stack=1337;
    int* foo(return scope int* x) @safe
    {
        int* bar(return scope int* y) @safe
        {
            return x;
        }
        auto dg = &bar; // causes closure to be GC allocated
        escaped = dg(&global); // so this should succeed
        return x;
    }
    foo(&stack);
}
