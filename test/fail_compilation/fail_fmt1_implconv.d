// REQUIRED_ARGS: -verror-format-level=1

/*
TEST_OUTPUT:
---
fail_compilation/fail_fmt1_implconv.d(20): Error: cannot implicitly convert expression `bd` of type
fail_compilation/fail_fmt1_implconv.d(20):            `void delegate() nothrow @nogc`
fail_compilation/fail_fmt1_implconv.d(20):        to
fail_compilation/fail_fmt1_implconv.d(20):            `void delegate() pure nothrow @nogc`
---
*/

void fail_fmt1_implconv()
{
    alias a = @safe @nogc nothrow pure void delegate();
    alias b = @safe @nogc nothrow void delegate();

    a ad;
    b bd;
    ad = bd;
}