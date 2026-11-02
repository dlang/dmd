// https://github.com/dlang/dmd/issues/24117

pragma(inline, false)
bool f(int x) { return cast(ushort)(x << 31) != 0; }

void main()
{
    assert(!f(1));
}
