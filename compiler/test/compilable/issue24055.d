// https://github.com/dlang/dmd/issues/24055

int f() { int x = -5; uint y = 7; x /= y; return x; }
int g() { int x = -5; uint y = 7; x %= y; return x; }
int h() { int x = -1; x >>>= 1L; return x; }

static assert(f() == 613_566_755);
static assert(g() == 6);
static assert(h() == 2147483647);
