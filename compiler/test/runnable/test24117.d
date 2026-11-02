// https://github.com/dlang/dmd/issues/24117

bool f(int x) { return cast(ushort)(x << 31) != 0; }

void main()
{
    assert(!f(1));
}
