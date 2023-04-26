// https://issues.dlang.org/show_bug.cgi?id=23616

#if __has_extension(gnu_asm)
void _hreset(int __eax)
{
    __asm__ ("hreset $0" :: "a"(__eax));
}
#endif
