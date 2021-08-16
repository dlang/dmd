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
    T getFunc(T)(const(char)* sym, string thisExePath)
    {
        import core.runtime : Runtime;

        version (Windows)
        {
            import core.sys.windows.winbase : GetProcAddress;
            return cast(T) Runtime.loadLibrary("dynamiccast.dll")
                .GetProcAddress(sym);
        }
        else version (Posix)
        {
            import core.sys.posix.dlfcn : dlsym;
            import core.stdc.string : strrchr;

            auto name = thisExePath ~ '\0';
            const pathlen = strrchr(name.ptr, '/') - name.ptr + 1;
            name = name[0 .. pathlen] ~ "dynamiccast.so";
            return cast(T) Runtime.loadLibrary(name)
                .dlsym(sym);
        }
        else static assert(0);
    }

    version (DigitalMars) version (Win64) version = DMD_Win64;

    void main(string[] args)
    {
        import core.stdc.stdio : fopen, fclose, remove;

        remove("dynamiccast_endmain");
        remove("dynamiccast_endbar");

        C c = new C;

        auto o = getFunc!(Object function(Object))("foo", args[0])(c);
        assert(cast(C) o);

        version (DMD_Win64)
        {
            // FIXME: apparent crash & needs more work, see https://github.com/dlang/druntime/pull/2874
            fclose(fopen("dynamiccast_endbar", "w"));
        }
        else
        {
            bool caught;
            try
                getFunc!(void function(void function()))("bar", args[0])(
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
