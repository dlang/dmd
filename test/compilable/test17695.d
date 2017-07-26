// REQUIRED_ARGS: -O
// PERMUTE_ARGS:
// DISABLE: win32 osx32 linux32 freebsd32

void bug(__vector(ubyte[16]) a)
{
    auto b = -a;
}
