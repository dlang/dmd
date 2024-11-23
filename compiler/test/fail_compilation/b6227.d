/* TEST_OUTPUT:
---
fail_compilation/b6227.d(24): Error: comparison between different enumeration types `X` and `Y`; If this behavior is intended consider using `std.conv.asOriginalType`
static assert(!(X.O != Y.U));
                ^
fail_compilation/b6227.d(24):        while evaluating: `static assert(!(X.O != Y.U))`
static assert(!(X.O != Y.U));
^
fail_compilation/b6227.d(25): Error: comparison between different enumeration types `X` and `Y`; If this behavior is intended consider using `std.conv.asOriginalType`
static assert( (X.O == Y.U));
                ^
fail_compilation/b6227.d(25):        while evaluating: `static assert(X.O == Y.U)`
static assert( (X.O == Y.U));
^
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
