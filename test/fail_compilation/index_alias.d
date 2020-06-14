/*
TEST_OUTPUT:
---
fail_compilation/index_alias.d(104): Error: variable `one` cannot be read at compile time
fail_compilation/index_alias.d(104): Error: alias `a1` , symbol `a` cannot be indexed using `[one]`
fail_compilation/index_alias.d(104): Error: alias `a1` cannot alias an expression `a[one]`
fail_compilation/index_alias.d(110): Error: cannot use `[]` operator on expression of type `int`
fail_compilation/index_alias.d(118): Error: module `core.stdc.stdio` is used as a type
fail_compilation/index_alias.d(125): Error: cannot interpret `1..2` at compile time
fail_compilation/index_alias.d(125): Error: alias `a1` , symbol `a` cannot be indexed using `[1..2]`
fail_compilation/index_alias.d(125): Error: alias `a1` cannot alias an expression `a[1..2]`
fail_compilation/index_alias.d(126): Error: alias `a2` , symbol `a` cannot be indexed using `[]`
fail_compilation/index_alias.d(126): Error: alias `a2` cannot alias an expression `a[]`
fail_compilation/index_alias.d(132): Error: alias `a` , cannot index `"NoSymbol"` using `[0]` because it is not a symbol
fail_compilation/index_alias.d(132): Error: alias `a` cannot alias an expression `"NoSymbol"[0]`
fail_compilation/index_alias.d(139): Error: cannot modify constant `a0`
---
*/
module index_alias;

#line 100
void test1()
{
    int[] a;
    int one;
    alias a1 = a[one];
}

void test2()
{
    int a;
    alias a1 = a[1];
    a1 = 0;
}

void test3()
{
    import core.stdc.stdio;
    alias io = core.stdc.stdio;
    alias a1 = io[1];
}

void test4()
{
    int[] a;
    int one;
    alias a1 = a[1..2];
    alias a2 = a[];
}

void test6()
{
    enum v = "NoSymbol";
    alias a = v[0];
}

void test7()
{
    enum int[1] a = [1];
    alias a0 = a[0];
    a0 = 2;
}
