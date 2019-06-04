/* TEST_OUTPUT:
---
fail_compilation/b6227.d(16): Error: Comparison between different enumeration types `X` and `Y`; If this behavior is intended consider using `std.conv.asOriginalType`
fail_compilation/b6227.d(16):        while evaluating: `static assert(!(cast(X)0 != cast(Y)0))`
fail_compilation/b6227.d(17): Error: Comparison between different enumeration types `X` and `Y`; If this behavior is intended consider using `std.conv.asOriginalType`
fail_compilation/b6227.d(17):        while evaluating: `static assert(cast(X)0 == cast(Y)0)`
---
*/
enum X {
    O,
    R
}
enum Y {
    U
}
static assert(!(X.O != Y.U));
static assert( (X.O == Y.U));
