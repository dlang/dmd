// https://github.com/dlang/dmd/issues/24056

class C {}
bool f() { C c = new C; return c && true; }
bool g() { C c = new C; return c || false; }
bool h() { C c; return c || false; }

static assert(f());
static assert(g());
static assert(!h());
