// REQUIRED_ARGS: -m64
/*
TEST_OUTPUT:
---
fail_compilation/fail238_m64.d(31): Error: cannot implicitly convert expression `"a"` of type `string` to `ulong`
    static if (D!(str[str]))
               ^
fail_compilation/fail238_m64.d(34): Error: cannot implicitly convert expression `X!()` of type `void` to `const(string)`
        const string A = .X!();
                         ^
fail_compilation/fail238_m64.d(39): Error: template instance `fail238_m64.A!"a"` error instantiating
    const string M = A!("a");
                     ^
fail_compilation/fail238_m64.d(45):        instantiated from here: `M!(q)`
    pragma(msg, M!(q));
                ^
fail_compilation/fail238_m64.d(45):        while evaluating `pragma(msg, M!(q))`
    pragma(msg, M!(q));
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=581
// Error message w/o line number in dot-instantiated template
template X(){}

template D(string str){}

template A(string str)
{
    static if (D!(str[str]))
    {}
    else
        const string A = .X!();
}

template M(alias B)
{
    const string M = A!("a");
}

void main()
{
    int q = 3;
    pragma(msg, M!(q));
}
