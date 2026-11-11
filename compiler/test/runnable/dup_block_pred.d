// REQUIRED_ARGS: -O
// https://github.com/dlang/dmd/issues/24268

struct S { int[10] x; }

__gshared int result;
bool pred() { return true; }
void sink(bool b, S* s) { result = b; }

void test(int v)
{
    S s;
    switch (v)
    {
        case 1: if (pred()) goto L; return;
        case 3:
        L:
            sink(false, &s);
            return;
        case 5: { int dead = v + 3; } goto L;
        default: break;
    }
}

void main()
{
    test(1);
    assert(result == 0);
}
