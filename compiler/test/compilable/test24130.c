/*
 * DISABLED: freebsd32 freebsd64 linux32 linux64 osx32 osx64 win64 dragonflybsd openbsd
 */

// https://issues.dlang.org/show_bug.cgi?id=24130

void test(int ShiftCount, int Value)
{
#ifdef _MSC_VER
__asm    {
        mov     ecx, ShiftCount
        mov     eax, dword ptr [Value]
        mov     edx, dword ptr [Value+4]
        shrd    eax, edx, cl
        shr     edx, cl
    }
#endif
}
