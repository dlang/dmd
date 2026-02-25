// https://issues.dlang.org/show_bug.cgi?id=22573
// core.sys.windows.objbase functions should be @nogc nothrow
version (Windows):
@nogc nothrow:
import core.sys.windows.objbase;
