module utils;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Windows)
    enum dllExt = "dll";
else version (Darwin)
    enum dllExt = "dylib";
else
    enum dllExt = "so";

// on some platforms, dlclose() is a no-op
version (Darwin)
    enum isDlcloseNoop = true; // since macOS ~10.12.6 if shared lib uses TLS: https://github.com/rust-lang/rust/issues/28794#issuecomment-368693049
else version (CRuntime_Musl)
    enum isDlcloseNoop = true; // https://wiki.musl-libc.org/functional-differences-from-glibc.html
else
    enum isDlcloseNoop = false;

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
