module core.internal.abort;

/*
 * Use instead of assert(0, msg), since this does not print a message for -release compiled
 * code, and druntime is -release compiled.
 */
void abort(scope string msg, scope string filename = __FILE__, size_t line = __LINE__) @nogc nothrow @safe
{
    import core.stdc.stdlib : c_abort = abort;
    // use available OS system calls to print the message to stderr
    version (Posix)
    {
        import core.sys.posix.unistd: write;
        static void writeStr(scope const(char)[][] m...) @nogc nothrow @trusted
        {
            foreach (s; m)
                write(2, s.ptr, s.length);
        }
    }
    else version (Windows)
    {
        import core.sys.windows.winbase : GetStdHandle, STD_ERROR_HANDLE, WriteFile, INVALID_HANDLE_VALUE;
        auto h = (() @trusted => GetStdHandle(STD_ERROR_HANDLE))();
        if (h == INVALID_HANDLE_VALUE)
        {
            // attempt best we can to print the message

            /* Note that msg is scope.
             * assert() calls _d_assert_msg() calls onAssertErrorMsg() calls _assertHandler() but
             * msg parameter isn't scope and can escape.
             * Give up and use our own immutable message instead.
             */
            assert(0, "Cannot get stderr handle for message");
        }
        void writeStr(scope const(char)[][] m...) @nogc nothrow @trusted
        {
            foreach (s; m)
            {
                assert(s.length <= uint.max);
                WriteFile(h, s.ptr, cast(uint)s.length, null, null);
            }
        }
    }
    else version (WASIp1) {
        import core.sys.wasi.p1 : CIOVec, fdWrite;

        static void writeStr(scope const(char)[][] m...) @nogc nothrow @trusted
        {
            foreach (s; m) {
                CIOVec[1] iovecs;
                size_t bytesWritten;
                iovecs[0].buf = cast(const(ubyte)*)s.ptr;
                iovecs[0].bufLen = s.length;
                cast(void)fdWrite(2, iovecs[], bytesWritten);
            }
        }
    }
    else version (WASIp2)
    {
        import core.sys.wasi.p2.cli.stderr.imports : getStderr;
        import core.sys.wasi.wit_common : witFree, witList;
        static void writeStr(scope const(char)[][] m...) @nogc nothrow @trusted
        {
            auto stderr = getStderr();
            scope(exit) stderr.drop;

            foreach (s; m) {
                auto result = stderr.blockingWriteAndFlush((cast(const(ubyte)[])s).witList);
                scope(exit) result.witFree;

                // ignore errors
            }
        }
    }
    else
        static assert(0, "Unsupported OS");

    import core.internal.string;
    UnsignedStringBuf strbuff = void;

    // write an appropriate message, then abort the program
    writeStr("Aborting from ", filename, "(", line.unsignedToTempString(strbuff), ") ", msg);
    c_abort();
}
