// https://issues.dlang.org/show_bug.cgi?id=19498
void main()
{
    import core.runtime;
    auto kernel32 = Runtime.loadLibrary("kernel32.dll");
    assert(kernel32);
    Runtime.unloadLibrary(kernel32);
}
