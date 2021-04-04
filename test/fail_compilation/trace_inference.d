/*
TEST_OUTPUT:
---
fail_compilation/trace_inference.d(25): Error: `@nogc` function `trace_inference.foo` cannot call non-@nogc function `trace_inference.bar!int.bar`
fail_compilation/trace_inference.d(29): Error: |
fail_compilation/trace_inference.d(29):          inferred non-`@nogc` for `trace_inference.bar!int.bar` because:
fail_compilation/trace_inference.d(31):          - calling function `trace_inference.factory!int.factory` may cause a GC allocation
fail_compilation/trace_inference.d(36): Error: |
fail_compilation/trace_inference.d(36):            inferred non-`@nogc` for `trace_inference.factory!int.factory` because:
fail_compilation/trace_inference.d(38):            - calling function `trace_inference.helper!().helper` may cause a GC allocation
fail_compilation/trace_inference.d(42): Error: |
fail_compilation/trace_inference.d(42):              inferred non-`@nogc` for `trace_inference.helper!().helper` because:
fail_compilation/trace_inference.d(44):              - associative array literal may cause a GC allocation
fail_compilation/trace_inference.d(42): Error: |
fail_compilation/trace_inference.d(39):            - `new` causes a GC allocation
fail_compilation/trace_inference.d(36): Error: |
fail_compilation/trace_inference.d(33):          - setting `length` may cause a GC allocation
fail_compilation/trace_inference.d(29): Error: |
fail_compilation/trace_inference.d(26): Error: `@nogc` function `trace_inference.foo` cannot call non-@nogc function `trace_inference.factory!int.factory`
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
fail_compilation/trace_inference.d(108): Error: |
fail_compilation/trace_inference.d(108):          inferred non-`@nogc` for `trace_inference.g2!().g2` because:
fail_compilation/trace_inference.d(111):          - calling function `trace_inference.f2` may cause a GC allocation
fail_compilation/trace_inference.d(108): Error: |
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
fail_compilation/trace_inference.d(206): Error: |
fail_compilation/trace_inference.d(206):          inferred non-`@nogc` for `trace_inference.rec!().rec` because:
fail_compilation/trace_inference.d(208):          - `new` causes a GC allocation
fail_compilation/trace_inference.d(209):          - calling function `trace_inference.rec!().rec` may cause a GC allocation
fail_compilation/trace_inference.d(206): Error: |
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
