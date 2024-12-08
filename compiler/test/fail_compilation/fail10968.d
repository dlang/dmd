/*
TEST_OUTPUT:
---
fail_compilation/fail10968.d(128): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
    ss = ss;
         ^
fail_compilation/fail10968.d(128): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
    ss = ss;
         ^
fail_compilation/fail10968.d(116):        `fail10968.SA.__postblit` is declared here
    this(this)
    ^
fail_compilation/fail10968.d(129): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
    sa = ss;
    ^
fail_compilation/fail10968.d(129): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
    sa = ss;
    ^
fail_compilation/fail10968.d(116):        `fail10968.SA.__postblit` is declared here
    this(this)
    ^
fail_compilation/fail10968.d(129): Error: `pure` function `fail10968.bar` cannot call impure function `core.internal.array.arrayassign._d_arraysetassign!(SA[], SA)._d_arraysetassign`
    sa = ss;
       ^
$p:druntime/import/core/internal/array/arrayassign.d$($n$):        which calls `core.lifetime.copyEmplace!(SA, SA).copyEmplace`
            copyEmplace(value, dst);
                       ^
$p:druntime/import/core/lifetime.d$($n$):        which calls `fail10968.SA.__postblit`
            (cast() target).__xpostblit();
                                       ^
fail_compilation/fail10968.d(130): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
    sa = sa;
    ^
fail_compilation/fail10968.d(130): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
    sa = sa;
    ^
fail_compilation/fail10968.d(116):        `fail10968.SA.__postblit` is declared here
    this(this)
    ^
fail_compilation/fail10968.d(130): Error: `pure` function `fail10968.bar` cannot call impure function `core.internal.array.arrayassign._d_arrayassign_l!(SA[], SA)._d_arrayassign_l`
    sa = sa;
       ^
$p:druntime/import/core/internal/array/arrayassign.d$-mixin-$n$($n$):        which calls `core.lifetime.copyEmplace!(SA, SA).copyEmplace`
$p:druntime/import/core/lifetime.d$($n$):        which calls `fail10968.SA.__postblit`
            (cast() target).__xpostblit();
                                       ^
fail_compilation/fail10968.d(133): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
    SA    ss2 = ss;
          ^
fail_compilation/fail10968.d(133): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
    SA    ss2 = ss;
          ^
fail_compilation/fail10968.d(116):        `fail10968.SA.__postblit` is declared here
    this(this)
    ^
fail_compilation/fail10968.d(134): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
    SA[1] sa2 = ss;
          ^
fail_compilation/fail10968.d(134): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
    SA[1] sa2 = ss;
          ^
fail_compilation/fail10968.d(116):        `fail10968.SA.__postblit` is declared here
    this(this)
    ^
fail_compilation/fail10968.d(134): Error: `pure` function `fail10968.bar` cannot call impure function `core.internal.array.construction._d_arraysetctor!(SA[], SA)._d_arraysetctor`
    SA[1] sa2 = ss;
          ^
$p:druntime/import/core/internal/array/construction.d$($n$):        which calls `core.lifetime.copyEmplace!(SA, SA).copyEmplace`
            copyEmplace(value, p[i]);
                       ^
$p:druntime/import/core/lifetime.d$($n$):        which calls `fail10968.SA.__postblit`
            (cast() target).__xpostblit();
                                       ^
fail_compilation/fail10968.d(135): Error: `pure` function `fail10968.bar` cannot call impure function `fail10968.SA.__postblit`
    SA[1] sa3 = sa;
          ^
fail_compilation/fail10968.d(135): Error: `@safe` function `fail10968.bar` cannot call `@system` function `fail10968.SA.__postblit`
    SA[1] sa3 = sa;
          ^
fail_compilation/fail10968.d(116):        `fail10968.SA.__postblit` is declared here
    this(this)
    ^
fail_compilation/fail10968.d(135): Error: `pure` function `fail10968.bar` cannot call impure function `core.internal.array.construction._d_arrayctor!(SA[], SA)._d_arrayctor`
    SA[1] sa3 = sa;
          ^
$p:druntime/import/core/internal/array/construction.d$($n$):        which calls `core.lifetime.copyEmplace!(SA, SA).copyEmplace`
                copyEmplace(from[i], to[i]);
                           ^
$p:druntime/import/core/lifetime.d$($n$):        which calls `fail10968.SA.__postblit`
            (cast() target).__xpostblit();
                                       ^
fail_compilation/fail10968.d(149): Error: struct `fail10968.SD` is not copyable because it has a disabled postblit
    ss = ss;
         ^
fail_compilation/fail10968.d(150): Error: struct `fail10968.SD` is not copyable because it has a disabled postblit
    sa = ss;
    ^
fail_compilation/fail10968.d(151): Error: struct `fail10968.SD` is not copyable because it has a disabled postblit
    sa = sa;
    ^
fail_compilation/fail10968.d(154): Error: struct `fail10968.SD` is not copyable because it has a disabled postblit
    SD    ss2 = ss;
          ^
fail_compilation/fail10968.d(155): Error: struct `fail10968.SD` is not copyable because it has a disabled postblit
    SD[1] sa2 = ss;
          ^
fail_compilation/fail10968.d(156): Error: struct `fail10968.SD` is not copyable because it has a disabled postblit
    SD[1] sa3 = sa;
          ^
---
*/

// Line 29 starts here
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
    ss = ss;
    sa = ss;
    sa = sa;

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
    ss = ss;
    sa = ss;
    sa = sa;

    // TOKconstruct
    SD    ss2 = ss;
    SD[1] sa2 = ss;
    SD[1] sa3 = sa;
}
