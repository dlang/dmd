// https://github.com/dlang/dmd/issues/24359

// (x << n) + c was compiled as a two LEA multiply by 1 << (n & 31)

__gshared int zero;
ulong opaque(ulong v) { return v + zero; }

void main()
{
    assert((opaque(1) << 36) + 1 == 0x10_0000_0001UL);
    assert((opaque(1) << 37) + 1 == 0x20_0000_0001UL);
    assert((opaque(1) << 38) + 1 == 0x40_0000_0001UL);
}
