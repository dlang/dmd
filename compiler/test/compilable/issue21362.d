// https://github.com/dlang/dmd/issues/21362
// CTFE delegate-to-bool conversion causes ICE

bool f(void delegate() dg) { if (dg) return true; else return false; }
bool g(void function() fp) { return fp ? true : false; }

static assert(f({ }));
static assert(!f(null));
static assert(g(function void() {}));
