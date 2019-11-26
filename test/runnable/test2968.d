// DISABLED: win linux freebsd dragonflybsd netbsd

struct __CFArray; //try to call some CF functions with strings
alias CFArrayRef = __CFArray*;
alias CFIndex = long;

extern(Objective-C) CFArrayRef CFArrayCreate(void* allocator, const void** values, long numValues, void* cbs);
extern(Objective-C) CFIndex CFArrayGetCount(CFArrayRef theArray);
extern(Objective-C) const(void *) CFArrayGetValueAtIndex(CFArrayRef theArray, CFIndex idx);

pragma(framework, "Foundation");

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
