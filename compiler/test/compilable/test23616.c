// https://issues.dlang.org/show_bug.cgi?id=23616

// __has_extension is a clang feature:
// https://clang.llvm.org/docs/LanguageExtensions.html#has-feature-and-has-extension
#ifndef __has_extension
#define __has_extension(x) 0
#endif

#if __has_extension(gnu_asm)
void _hreset(int __eax)
{
    __asm__ ("hreset $0" :: "a"(__eax));
}
#endif
