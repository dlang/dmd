// DISABLED: win linux freebsd dragonflybsd netbsd

pragma(framework, "CoreFoundation");

struct __CFArray; //try to call some CF functions with arrays
alias CFArrayRef = __CFArray*;
alias CFIndex = long;

extern(C) CFArrayRef CFArrayCreate(void* allocator, const void** values, long numValues, void* cbs);
extern(C) CFIndex CFArrayGetCount(CFArrayRef theArray);
extern(C) const(void *) CFArrayGetValueAtIndex(CFArrayRef theArray, CFIndex idx);

void main()
{

    ulong[5] array = [1,2,3,4,5];
    auto cfa = CFArrayCreate(null, cast(void**)array.ptr, array.length, null);
    const length = CFArrayGetCount(cfa);
    assert(length == array.length);
    foreach (i, x; array)
    {
        assert(x == cast(ulong) CFArrayGetValueAtIndex(cfa, i));
    }
}
