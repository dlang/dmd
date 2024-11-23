/* https://issues.dlang.org/show_bug.cgi?id=19520
TEST_OUTPUT:
---
fail_compilation/fail19520.d(29): Error: incompatible types for `(Empty) is (Empty)`: cannot use `is` with types
    static assert(Empty is Empty);
                  ^
fail_compilation/fail19520.d(29):        while evaluating: `static assert((Empty) is (Empty))`
    static assert(Empty is Empty);
    ^
fail_compilation/fail19520.d(30): Error: incompatible types for `(WithSym) is (WithSym)`: cannot use `is` with types
    static assert(WithSym is WithSym);
                  ^
fail_compilation/fail19520.d(30):        while evaluating: `static assert((WithSym) is (WithSym))`
    static assert(WithSym is WithSym);
    ^
fail_compilation/fail19520.d(31): Error: incompatible types for `(Empty) is (Empty)`: cannot use `is` with types
    assert(Empty is Empty);
           ^
fail_compilation/fail19520.d(32): Error: incompatible types for `(WithSym) is (WithSym)`: cannot use `is` with types
    assert(WithSym is WithSym);
           ^
---
*/
struct Empty { }
struct WithSym { int i; }

void test()
{
    static assert(Empty is Empty);
    static assert(WithSym is WithSym);
    assert(Empty is Empty);
    assert(WithSym is WithSym);
}
