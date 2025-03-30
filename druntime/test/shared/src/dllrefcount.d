
import core.sys.windows.dll;
import core.runtime;

void main()
{
    auto kernel32 = Runtime.loadLibrary("kernel32.dll");
    assert(kernel32);
    int refcnt = dll_getRefCount(kernel32);
    assert(refcnt == -1);

    auto imagehlp = Runtime.loadLibrary("imagehlp.dll");
    assert(imagehlp);
    refcnt = dll_getRefCount(imagehlp);
    assert(refcnt == 1);

    Runtime.unloadLibrary(imagehlp);
    refcnt = dll_getRefCount(imagehlp);
    assert(refcnt == -2);
}
