// REQUIRED_ARGS: -o-

/*
example output from druntime
----
../../druntime/import/core/internal/arrayop.d(160): Error: static assert  "Binary op `+=` not supported for element type string."
../../druntime/import/core/internal/arrayop.d(20):        instantiated from here: opsSupported!(true, string, "+=")
../../druntime/import/object.d(3640):        instantiated from here: arrayOp!(string[], string[], "+=")
fail_compilation/fail_arrayop3b.d(16):        instantiated from here: _arrayOp!(string[], string[], "+=")
---
*/
void test11376()
{
    string[] s1;
    string[] s2;
    s2[] += s1[];
}
