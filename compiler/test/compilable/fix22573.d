// https://issues.dlang.org/show_bug.cgi?id=22573
// core.sys.windows.objbase functions should be @nogc nothrow
version (Windows):
import core.sys.windows.objbase;

// Verify that COM functions which do not execute user-supplied code are @nogc nothrow
// by calling them from a @nogc nothrow context.  The following are intentionally
// excluded because they may invoke user D code (which may allocate via the GC):
//   CoGetClassObject, CoFreeLibrary, CoCreateInstance, CoCreateInstanceEx,
//   DllGetClassObject, and anything else accepting LPUNKNOWN / IUnknown*.
@nogc nothrow void testNogcNothrow()
{
    CoInitialize(null);
    CoInitializeEx(null, 0);
    CoUninitialize();
    CoGetCurrentProcess();
    CoRevokeMallocSpy();
    CoRevokeClassObject(0);
    CoCreateGuid(null);
    CoFileTimeNow(null);
    CoTaskMemAlloc(0);
    CoTaskMemFree(null);
    CoTaskMemRealloc(null, 0);
    CoAddRefServerProcess();
    CoReleaseServerProcess();
    CoResumeClassObjects();
    CoSuspendClassObjects();
    DllCanUnloadNow();
}
