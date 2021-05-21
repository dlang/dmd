/*
TEST_OUTPUT:
---
fail_compilation/trace_inference.d(18): Error: `@nogc` function `trace_inference.foo` cannot call non-@nogc function `trace_inference.bar!int.bar`
fail_compilation/trace_inference.d(22):          could not infer `@nogc` for `trace_inference.bar!int.bar` because:
fail_compilation/trace_inference.d(24):          - calling `trace_inference.factory!int.factory` which is not `@nogc`
fail_compilation/trace_inference.d(29):            could not infer `@nogc` for `trace_inference.factory!int.factory` because:
fail_compilation/trace_inference.d(31):            - calling `trace_inference.helper!().helper` which is not `@nogc`
fail_compilation/trace_inference.d(35):              could not infer `@nogc` for `trace_inference.helper!().helper` because:
fail_compilation/trace_inference.d(37):              - `[1:1]` is not `@nogc`
fail_compilation/trace_inference.d(26):          - `_d_arraysetlengthT(arr, 1LU)` is not `@nogc`
fail_compilation/trace_inference.d(19): Error: `@nogc` function `trace_inference.foo` cannot call non-@nogc function `trace_inference.factory!int.factory`
---
*/

void foo() @nogc
{
    bar!int();
    factory!int();
}

void bar(T)()
{
    factory!T();
    T[] arr;
    arr.length = 1;
}

auto factory(T)()
{
    helper();
    return new T();
}

auto helper()()
{
    return [ 1: 1 ];
}

/*
TEST_OUTPUT:
---
fail_compilation/trace_inference.d(103): Error: `@nogc` function `trace_inference.entry` cannot call non-@nogc function `trace_inference.g2!().g2`
fail_compilation/trace_inference.d(108):          could not infer `@nogc` for `trace_inference.g2!().g2` because:
fail_compilation/trace_inference.d(111):          - calling `trace_inference.f2` which is not `@nogc`
---
*/
#line 100

void entry() @nogc
{
    g2(null);
}

void f2() {}

void g2()(char[] s)
{
    foreach (dchar dc; s)
        f2();
}

/*
TEST_OUTPUT:
---
fail_compilation/trace_inference.d(203): Error: `@nogc` function `trace_inference.entryRec` cannot call non-@nogc function `trace_inference.rec!().rec`
fail_compilation/trace_inference.d(206):          could not infer `@nogc` for `trace_inference.rec!().rec` because:
fail_compilation/trace_inference.d(208):          - `new int(1)` is not `@nogc`
---
*/
#line 200

void entryRec() @nogc
{
    rec();
}

void rec()()
{
    new int(1);
    rec();
}

/*
TEST_OUTPUT:
---
fail_compilation/trace_inference.d(303): Error: function `trace_inference.doesThrow!().doesThrow` is not `nothrow`
fail_compilation/trace_inference.d(307):          could not infer `nothrow` for `trace_inference.doesThrow!().doesThrow` because:
fail_compilation/trace_inference.d(309):          - throwing `object.Exception` here
fail_compilation/trace_inference.d(304): Error: function `trace_inference.doesCallThrow!().doesCallThrow` is not `nothrow`
fail_compilation/trace_inference.d(312):          could not infer `nothrow` for `trace_inference.doesCallThrow!().doesCallThrow` because:
fail_compilation/trace_inference.d(314):          - calling `trace_inference.entryRec` which is not `nothrow`
fail_compilation/trace_inference.d(301): Error: `nothrow` function `trace_inference.entryRec300` may throw
---
*/
#line 300

void entryRec300() nothrow
{
    doesThrow();
    doesCallThrow();
}

void doesThrow()()
{
    throw new Exception("");
}

void doesCallThrow()()
{
    entryRec();
}

/*
TEST_OUTPUT:
---
fail_compilation/trace_inference.d(403): Error: function `trace_inference.doesThrowInTry!().doesThrowInTry` is not `nothrow`
fail_compilation/trace_inference.d(406):          could not infer `nothrow` for `trace_inference.doesThrowInTry!().doesThrowInTry` because:
fail_compilation/trace_inference.d(415):          - throwing `object.Exception` here
fail_compilation/trace_inference.d(401): Error: `nothrow` function `trace_inference.entryRec400` may throw
---

The following hints are emitted because the current implementation of blockExit makes
it impossible to determine whether a throw in a try-catch is caught.
---
fail_compilation/trace_inference.d(420):          - throwing `object.Exception` here
---
*/
#line 400

void entryRec400() nothrow
{
    doesThrowInTry(1);
}

void doesThrowInTry()(int i)
{
    try
        // Must not be reported!
        throw new Exception("");
    catch (Exception e) {}

    try
        // Must be reported!
        throw new Exception("");
    catch (Custom e) {}
}

class Custom : Exception
{
    this() { super(""); }
}

/*
TEST_OUTPUT:
---
fail_compilation/trace_inference.d(503): Error: function `trace_inference.doesCallThrowInTry!().doesCallThrowInTry` is not `nothrow`
fail_compilation/trace_inference.d(506):          could not infer `nothrow` for `trace_inference.doesCallThrowInTry!().doesCallThrowInTry` because:
fail_compilation/trace_inference.d(513):          - calling `trace_inference.entryRec` which is not `nothrow`
fail_compilation/trace_inference.d(501): Error: `nothrow` function `trace_inference.entryRec500` may throw
---

See above for an explanation of:
---
fail_compilation/trace_inference.d(509):          - calling `trace_inference.entryRec` which is not `nothrow`
---
*/
#line 500

void entryRec500() nothrow
{
    doesCallThrowInTry(1);
}

void doesCallThrowInTry()(int i)
{
    try
        entryRec();
    catch (Exception e) {}

    try
        entryRec();
    catch (Custom e) {}
}
