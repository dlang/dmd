// https://github.com/dlang/dmd/issues/23021
// getOverloads indexed result .mangleof caused assertion failure

class A { void func() const {} }
static assert(__traits(getOverloads, A, "func")[0].mangleof.length > 0);
