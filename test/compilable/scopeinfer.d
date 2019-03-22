// PERMUTE_ARGS: -dip1000

// Mangling should be the same with or without inference of `return scope`

@safe:

auto foo(void* p) { return 0; }
static assert(typeof(foo).mangleof == "FNaNbNiNfPvZi");

auto bar(void* p) { return p; }
static assert(typeof(bar).mangleof == "FNaNbNiNfPvZQd");

