// REQUIRED_ARGS: -o-

/*
example output from druntime
----
../../druntime/import/core/internal/arrayop.d(160): Error: static assert  "Binary op `*=` not supported for element type int*."
../../druntime/import/core/internal/arrayop.d(20):        instantiated from here: `opsSupported!(true, int*, "*=")``
../../druntime/import/object.d(3640):        instantiated from here: `arrayOp!(int*[], int*[], "*=")`
fail_compilation/fail_arrayop3c.d(16):        instantiated from here: `_arrayOp!(int*[], int*[], "*=")`
----
*/
void test11376()
{
    int*[] pa1;
    int*[] pa2;
    pa1[] *= pa2[];
}
