// https://github.com/dlang/dmd/issues/24075

int f() { int x = -8; uint y = 2; x >>= y; return x; }
long g() { long x = -8; ulong y = 2; x >>= y; return x; }

static assert(f() == -2);
static assert(g() == -2);

void main()
{
    assert(f() == -2);
    assert(g() == -2);
}
