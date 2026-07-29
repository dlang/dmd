// https://github.com/dlang/dmd/issues/23367
// Tests for sparse array literal optimization: copyLiteral now preserves
// CONSTANT encoding (null elements + basis) instead of expanding to dense.
// Most sparse-array code paths are already covered by existing CTFE tests;
// this test covers the novel paths specific to the implementation.

// ============================================================
// Dynamic array resize filling with array-typed default values.
// The resize copies old elements (which may be null in sparse arrays)
// and fills new slots with the default element.
// ============================================================
alias f = {
    int[1][] pieces = [];
    pieces.length = 2;
    return pieces;
};
static assert(f() == [[0], [0]]);

alias g = {
    int[1][] pieces = [];
    pieces.length = 3;
    pieces[1] = [42];
    return pieces;
};
static assert(g() == [[0], [42], [0]]);

// Larger resize: grow from empty to many elements
static int testLargeGrow()
{
    int[2][] pieces = [];
    pieces.length = 1000;
    pieces[0] = [1, 2];
    pieces[999] = [3, 4];
    return pieces[0][0] + pieces[0][1] +
           pieces[999][0] + pieces[999][1] +
           pieces[500][0];
}
static assert(testLargeGrow() == 1 + 2 + 3 + 4 + 0);

// ============================================================
// Concatenation of two sparse arrays that each have a basis.
// ============================================================
static int testCatSparse()
{
    int[500] a = 1;
    int[500] b = 2;
    auto c = a ~ b;
    return c[0] + c[250] + c[499] + c[500] + c[750] + c[999];
}
static assert(testCatSparse() == 1 + 1 + 1 + 2 + 2 + 2);
