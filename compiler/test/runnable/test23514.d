// REQUIRED_ARGS: -O
// https://issues.dlang.org/show_bug.cgi?id=23514

enum offset = 0xFFFF_FFFF_0000_0000UL;

void main()
{
    assert((cast(ulong)&main) != (cast(ulong)&main + offset));
}
