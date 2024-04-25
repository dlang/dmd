module utils;

version (Windows)
    enum dllExt = "dll";
else version (darwin)
    enum dllExt = "dylib";
else
    enum dllExt = "so";

void loadSym(T)(void* handle, ref T val, const char* mangle)
{
    version (Windows)
    {
        import core.sys.windows.winbase : GetProcAddress;
        val = cast(T) GetProcAddress(handle, mangle);
    }
    else
    {
        import core.sys.posix.dlfcn : dlsym;
        val = cast(T) dlsym(handle, mangle);
    }
}
