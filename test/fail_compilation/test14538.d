// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/test14538.d(19): Error: cannot implicitly convert expression `x ? this.fCells[x].code : ' '` of type `dchar` to `Cell`
---
*/

struct Cell
{
    dchar code;
    alias code this;
}

struct Row
{
    Cell[] fCells;
    Cell opIndex(size_t x) { return x ? fCells[x] : ' '; }
}
