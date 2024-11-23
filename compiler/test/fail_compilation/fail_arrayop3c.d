/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
----
$p:druntime/import/core/internal/array/operations.d$($n$): Error: static assert:  "Binary op `*=` not supported for types `int*` and `int*`."
                    static assert(0,
                    ^
$p:druntime/import/core/internal/array/operations.d$($n$):        instantiated from here: `typeCheck!(true, int*, int*, "*=")`
    alias check = typeCheck!(true, T, scalarizedExp); // must support all scalar ops
                  ^
$p:druntime/import/object.d$($n$):        instantiated from here: `arrayOp!(int*[], int*[], "*=")`
    alias _arrayOp = arrayOp!Args;
                     ^
fail_compilation/fail_arrayop3c.d(23):        instantiated from here: `_arrayOp!(int*[], int*[], "*=")`
    pa1[] *= pa2[];
          ^
----
*/
void test11376()
{
    int*[] pa1;
    int*[] pa2;
    pa1[] *= pa2[];
}
