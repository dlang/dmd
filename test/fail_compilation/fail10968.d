/*
TEST_OUTPUT:
---
fail_compilation/fail10968.d(44): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(44): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(45): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(45): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(46): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(46): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(49): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(49): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(49): Error: declaration `fail10968.bar.ss2` is already defined
fail_compilation/fail10968.d(50): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(50): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(50): Error: declaration `fail10968.bar.sa2` is already defined
fail_compilation/fail10968.d(51): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(51): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
fail_compilation/fail10968.d(65): Error: struct `fail10968.SD` is not copyable because it is annotated with `@disable`
fail_compilation/fail10968.d(66): Error: struct `fail10968.SD` is not copyable because it is annotated with `@disable`
fail_compilation/fail10968.d(67): Error: cannot implicitly convert expression `sa` of type `SD[1]` to `SA[]`
fail_compilation/fail10968.d(70): Error: struct `fail10968.SD` is not copyable because it is annotated with `@disable`
fail_compilation/fail10968.d(70): Error: declaration `fail10968.baz.ss2` is already defined
fail_compilation/fail10968.d(71): Error: struct `fail10968.SD` is not copyable because it is annotated with `@disable`
fail_compilation/fail10968.d(71): Error: declaration `fail10968.baz.sa2` is already defined
fail_compilation/fail10968.d(72): Error: struct `fail10968.SD` is not copyable because it is annotated with `@disable`

---
*/

struct SA
{
    this(this)
    {
        throw new Exception("BOOM!");
    }
}

void bar() pure @safe
{
    SA    ss;
    SA[1] sa;

    // TOKassign
    auto ss2 = ss;
    sa = ss;
    SA[1] sa2 = sa;

    // TOKconstruct
    SA    ss2 = ss;
    SA[1] sa2 = ss;
    SA[1] sa3 = sa;
}

struct SD
{
    this(this) @disable;
}

void baz()
{
    SD    ss;
    SD[1] sa;

    // TOKassign
    auto ss2 = ss;
    sa = ss;
    SA[1] sa2 = sa;

    // TOKconstruct
    SD    ss2 = ss;
    SD[1] sa2 = ss;
    SD[1] sa3 = sa;
}
