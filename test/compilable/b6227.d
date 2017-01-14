/* TEST_OUTPUT:
---
compilable/b6227.d(17): Deprecation: Comparison between different enumeration types (got X and Y)
compilable/b6227.d(18): Deprecation: Comparison between different enumeration types (got X and Y)
---
*/
enum X {
    O,
    R
}
enum Y {
    U
}
static assert( (X.O == cast(const)X.O));
static assert( (X.O == X.O));
static assert( (X.O != X.R));
static assert(!(X.O != Y.U));
static assert( (X.O == Y.U));
