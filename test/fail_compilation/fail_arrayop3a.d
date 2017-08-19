// REQUIRED_ARGS: -o-

/*
example output from druntime
----
../../druntime/import/core/internal/arrayop.d(160): Error: static assert  "Binary op `*` not supported for element type X."
../../druntime/import/core/internal/arrayop.d(145):        instantiated from here: opsSupported!(true, X, "*")
../../druntime/import/core/internal/arrayop.d(20):        instantiated from here: opsSupported!(true, X, "*", "=")
../../druntime/import/object.d(3640):        instantiated from here: arrayOp!(X[], X[], X[], "*", "=")
fail_compilation/fail_arrayop3a.d(28):        instantiated from here: _arrayOp!(X[], X[], X[], "*", "=")
../../druntime/import/core/internal/arrayop.d(160): Error: static assert  "Binary op `+=` not supported for element type string."
../../druntime/import/core/internal/arrayop.d(20):        instantiated from here: opsSupported!(true, string, "+=")
../../druntime/import/object.d(3640):        instantiated from here: arrayOp!(string[], string[], "+=")
fail_compilation/fail_arrayop3a.d(32):        instantiated from here: _arrayOp!(string[], string[], "+=")
../../druntime/import/core/internal/arrayop.d(160): Error: static assert  "Binary op `*=` not supported for element type int*."
../../druntime/import/core/internal/arrayop.d(20):        instantiated from here: opsSupported!(true, int*, "*=")
../../druntime/import/object.d(3640):        instantiated from here: arrayOp!(int*[], int*[], "*=")
fail_compilation/fail_arrayop3a.d(36):        instantiated from here: _arrayOp!(int*[], int*[], "*=")
----
*/
void test11376()
{
    struct X { }

    auto x1 = [X()];
    auto x2 = [X()];
    auto x3 = [X()];
    x1[] = x2[] * x3[];

    string[] s1;
    string[] s2;
    s2[] += s1[];

    int*[] pa1;
    int*[] pa2;
    pa1[] *= pa2[];
}
