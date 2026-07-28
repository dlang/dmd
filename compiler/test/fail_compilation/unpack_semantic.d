/*
REQUIRED_ARGS: -preview=tuples
TEST_OUTPUT:
---
fail_compilation/unpack_semantic.d(18): Error: right hand side of unpack declaration must resolve to a tuple or expression sequence, not `int[]`
fail_compilation/unpack_semantic.d(19): Error: incompatible number of components for unpack declaration (`2` vs. `3`)
fail_compilation/unpack_semantic.d(22): Error: cannot specify `static` for individual components of an unpack declaration
fail_compilation/unpack_semantic.d(23): Error: cannot specify `enum` for individual components of an unpack declaration
fail_compilation/unpack_semantic.d(26): Error: cannot implicitly convert expression `3.0F` of type `float` to `int`
fail_compilation/unpack_semantic.d(27): Error: cannot implicitly convert expression `7` of type `int` to `void*`
---
*/

alias Seq(A...) = A;

void main()
{
    auto (a, b) = [1, 2];
    (int c, int d) = Seq!(3, 4, 5);

    // check individual storage classes
    (auto g, static h) = Seq!(8, 9);
    (int i, enum j) = Seq!(10, 11);

    // element type error
    (int p,) = Seq!3F;
    (int q, void* r) = Seq!(6, 7);
}
