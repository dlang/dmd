// REQUIRED_ARGS: -O
// PERMUTE_ARGS:
// https://github.com/dlang/dmd/issues/24113

byte shrByte()
{
    byte x = -1;
    x >>>= 1;
    return x;
}

short shrShort()
{
    short x = -1;
    x >>>= 1;
    return x;
}

int shrInt()
{
    int x = -1;
    x >>>= 1;
    return x;
}

void main()
{
    assert(shrByte() == 0x7F);
    assert(shrShort() == 0x7FFF);
    assert(shrInt() == 0x7FFF_FFFF);
}
