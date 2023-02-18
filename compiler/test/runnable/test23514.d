// REQUIRED_ARGS: -O
// https://issues.dlang.org/show_bug.cgi?id=23514

enum offset = 0xFFFF_FFFF_0000_0000UL;

void main()
{
    size_t voffset = offset;
    assert((cast(size_t)&main + voffset) == (cast(size_t)&main + offset));
}
