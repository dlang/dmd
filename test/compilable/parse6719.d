// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

pragma(msg, __traits(compiles, mixin("(const(A))[0..0]")));
