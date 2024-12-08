/*
TEST_OUTPUT:
---
fail_compilation/ctfe14465.d(25): Error: uncaught CTFE exception `ctfe14465.E("message")`
    throw new E("message");
          ^
fail_compilation/ctfe14465.d(28):        called from here: `foo()`
static assert(foo());
                 ^
fail_compilation/ctfe14465.d(28):        while evaluating: `static assert(foo())`
static assert(foo());
^
---
*/
class E : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

bool foo()
{
    throw new E("message");
}

static assert(foo());
