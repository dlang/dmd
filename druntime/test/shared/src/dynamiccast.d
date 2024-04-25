class C : Exception
{
    this() { super(""); }
}

version (DLL)
{
    version (Windows)
    {
        import core.sys.windows.dll;
        mixin SimpleDllMain;
    }

    pragma(mangle, "foo")
    export Object foo(Object o)
    {
        assert(cast(C) o);
        return new C;
    }

    pragma(mangle, "bar")
    export void bar(void function() f)
    {
        import core.stdc.stdio : fopen, fclose;
        bool caught;
        try
            f();
        catch (C e)
            caught = true;
        assert(caught);

        // verify we've actually got to the end, because for some reason we can
        // end up exiting with code 0 when throwing an exception
        fclose(fopen("dynamiccast_endbar", "w"));
        throw new C;
    }
}
else
{
    T getFunc(T)(const(char)* sym)
    {
        import core.runtime : Runtime;
        import utils : dllExt;

        version (Windows)
        {
            import core.sys.windows.winbase : GetProcAddress;
            return cast(T) Runtime.loadLibrary("dynamiccast." ~ dllExt)
                .GetProcAddress(sym);
        }
        else version (Posix)
        {
            import core.sys.posix.dlfcn : dlsym;
            return cast(T) Runtime.loadLibrary("./dynamiccast." ~ dllExt)
                .dlsym(sym);
        }
        else static assert(0);
    }

    // Returns the path to the executable's directory (null-terminated).
    string getThisExeDir(string arg0)
    {
        char[] buffer = arg0.dup;
        assert(buffer.length);
        for (size_t i = buffer.length - 1; i > 0; --i)
        {
            if (buffer[i] == '/' || buffer[i] == '\\')
            {
                buffer[i] = 0;
                return cast(string) buffer[0 .. i];
            }
        }
        return null;
    }

    version (DigitalMars) version (Win64) version = NoExceptions;
    version (SharedRuntime) version (DigitalMars) version (Win32) version = NoExceptions;

    void main(string[] args)
    {
        import core.stdc.stdio : fopen, fclose, remove;

        const exeDir = getThisExeDir(args[0]);
        if (exeDir.length)
        {
            version (Windows)
            {
                import core.sys.windows.winbase : SetCurrentDirectoryA;
                SetCurrentDirectoryA(exeDir.ptr);
            }
            else
            {
                import core.sys.posix.unistd : chdir;
                chdir(exeDir.ptr);
            }
        }

        remove("dynamiccast_endmain");
        remove("dynamiccast_endbar");

        C c = new C;

        auto o = getFunc!(Object function(Object))("foo")(c);
        assert(cast(C) o);

        version (NoExceptions)
        {
            // FIXME: apparent crash & needs more work, see https://github.com/dlang/druntime/pull/2874
            fclose(fopen("dynamiccast_endbar", "w"));
        }
        else
        {
            bool caught;
            try
                getFunc!(void function(void function()))("bar")(
                    { throw new C; });
            catch (C e)
                caught = true;
            assert(caught);
        }

        // verify we've actually got to the end, because for some reason we can
        // end up exiting with code 0 when throwing an exception
        fclose(fopen("dynamiccast_endmain", "w"));
    }
}
