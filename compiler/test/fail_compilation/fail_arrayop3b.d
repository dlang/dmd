/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
----
$p:druntime/import/core/internal/array/operations.d$($n$): Error: static assert:  "Binary op `+=` not supported for types `string` and `string`."
                    static assert(0,
                    ^
$p:druntime/import/core/internal/array/operations.d$($n$):        instantiated from here: `typeCheck!(true, string, string, "+=")`
    alias check = typeCheck!(true, T, scalarizedExp); // must support all scalar ops
                  ^
$p:druntime/import/object.d$($n$):        instantiated from here: `arrayOp!(string[], string[], "+=")`
    alias _arrayOp = arrayOp!Args;
                     ^
fail_compilation/fail_arrayop3b.d(23):        instantiated from here: `_arrayOp!(string[], string[], "+=")`
    s2[] += s1[];
         ^
---
*/
void test11376()
{
    string[] s1;
    string[] s2;
    s2[] += s1[];
}
