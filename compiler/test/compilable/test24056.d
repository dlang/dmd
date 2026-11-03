// https://github.com/dlang/dmd/issues/24056

class C {}
bool f() { C c = new C; return c && true; }
bool g() { C c = new C; return c || false; }
bool h() { C c; return c || false; }

static assert(f());
static assert(g());
static assert(!h());

// https://github.com/dlang/dmd/issues/24173
bool i() { int[] a = [1]; return a && true; }
bool j() { int[] a = []; return a || false; }

// https://github.com/dlang/dmd/issues/24174
bool k() { int v; int delegate() dg = () => v; return dg && true; }
bool l() { int[int] aa = [1: 1]; return aa && true; }

// https://github.com/dlang/dmd/issues/24175
bool m() { int[int] aa = [1: 1]; aa.remove(1); if (aa) return true; return false; }

static assert(i());
static assert(!j());
static assert(k());
static assert(l());
static assert(m());
