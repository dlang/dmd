// https://github.com/dlang/dmd/issues/24021

struct S { int x; bool opEquals(S) const { return true; } }
bool f() { return [S(1)] == [S(2)]; }
static assert(f());

struct N { int x; bool opEquals(N) const { return false; } }
bool g() { return [N(1)] != [N(1)]; }
static assert(g());

class C { override bool opEquals(Object) const { return true; } }
bool h() { return [new C] == [new C]; }
static assert(h());
