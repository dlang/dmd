// PERMUTE_ARGS:
// REQUIRED_ARGS: -o-

/***************************************************/
// 6719

pragma(msg, __traits(compiles, mixin("(const(A))[0..0]")));
