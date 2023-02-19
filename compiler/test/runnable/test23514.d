// REQUIRED_ARGS: -m64 -O
// DISABLED: win32 linux32 freebsd32 osx32 netbsd32 dragonflybsd32
// https://issues.dlang.org/show_bug.cgi?id=23514

enum ulong offset = 0xFFFF_FFFF_0000_0000UL;

void main()
{
    ulong voffset = offset;
    assert((cast(ulong)&main + voffset) == (cast(ulong)&main + offset));
}
