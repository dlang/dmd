// PERMUTE_ARGS:

// postfix attributes not playing well with auto return type

int test1() pure nothrow { return 1; }
auto test2() pure nothrow { return 1; }
auto ref test3() pure nothrow { return 1; }