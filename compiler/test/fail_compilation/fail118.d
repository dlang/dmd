/*
TEST_OUTPUT:
---
fail_compilation/fail118.d(59): Error: invalid `foreach` aggregate `Iter` of type `Iter`
    foreach (int i; f.oldIterMix.Iter) {}
    ^
fail_compilation/fail118.d(59):        `foreach` works with input ranges (implementing `front` and `popFront`), aggregates implementing `opApply`, or the result of an aggregate's `.tupleof` property
fail_compilation/fail118.d(59):        https://dlang.org/phobos/std_range_primitives.html#isInputRange
fail_compilation/fail118.d(60): Error: invalid `foreach` aggregate `Iter` of type `Iter`
    foreach (    i; f.oldIterMix.Iter) {}
    ^
fail_compilation/fail118.d(60):        `foreach` works with input ranges (implementing `front` and `popFront`), aggregates implementing `opApply`, or the result of an aggregate's `.tupleof` property
fail_compilation/fail118.d(60):        https://dlang.org/phobos/std_range_primitives.html#isInputRange
fail_compilation/fail118.d(63): Error: invalid `foreach` aggregate `s` of type `S*`
    foreach (const i; s) {}
    ^
fail_compilation/fail118.d(65): Error: undefined identifier `unknown`
    foreach(const i; unknown) {}
                     ^
fail_compilation/fail118.d(53): Error: undefined identifier `doesNotExist`
    doesNotExist();
    ^
fail_compilation/fail118.d(67): Error: template instance `fail118.error!()` error instantiating
    foreach (const i; error()) {}
                           ^
fail_compilation/fail118.d(67): Error: invalid `foreach` aggregate `error()` of type `void`
    foreach (const i; error()) {}
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=441
// Crash on foreach of mixed-in aggregate.
template opHackedApply()
{
    struct Iter
    {
    }
}

class Foo
{
    mixin opHackedApply!() oldIterMix;
}

struct S
{
    int opApply(scope int delegate(const int) dg);
}

auto error()()
{
    doesNotExist();
}

void main()
{
    Foo f = new Foo;
    foreach (int i; f.oldIterMix.Iter) {}
    foreach (    i; f.oldIterMix.Iter) {}

    S* s;
    foreach (const i; s) {}

    foreach(const i; unknown) {}

    foreach (const i; error()) {}
}
