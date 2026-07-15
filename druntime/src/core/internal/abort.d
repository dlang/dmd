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
    } else version (WASIp2) {
        // currently depends on wasi-libc being linked in to provide these "syscalls"
        // TODO: detach this from wasi-libc
        extern(C) struct wasip2_list_u8_t {
            ubyte* ptr;
            size_t len;
        }
        extern(C) struct streams_own_output_stream_t {
            int __handle;
        }
        extern(C) struct streams_borrow_output_stream_t {
            int __handle;
        }
        alias streams_own_output_stream_t stderr_own_output_stream_t;
        extern(C) struct io_error_own_error_t {
            int __handle;
        }
        alias io_error_own_error_t streams_own_error_t;

        extern(C) struct streams_stream_error_t {
            ubyte tag;

            union Val {
                streams_own_error_t     last_operation_failed;
            }
            Val val;
        }

        pragma(mangle, "streams_output_stream_drop_own")
        extern(C) static void streams_output_stream_drop_own(streams_own_output_stream_t handle) @nogc nothrow;
        pragma(mangle, "streams_borrow_output_stream")
        extern(C) static streams_borrow_output_stream_t streams_borrow_output_stream(streams_own_output_stream_t handle) @nogc nothrow;
        pragma(mangle, "stderr_get_stderr")
        extern(C) static stderr_own_output_stream_t stderr_get_stderr() @nogc nothrow;
        pragma(mangle, "io_error_error_drop_own")
        extern(C) static void io_error_error_drop_own(io_error_own_error_t handle) @nogc nothrow;
        pragma(mangle, "streams_stream_error_free")
        extern(C) static void streams_stream_error_free(streams_stream_error_t *ptr) @nogc nothrow;
        pragma(mangle, "streams_method_output_stream_blocking_write_and_flush")
        extern(C) static bool streams_method_output_stream_blocking_write_and_flush(streams_borrow_output_stream_t self, wasip2_list_u8_t *contents, streams_stream_error_t *err) @nogc nothrow;

        static void writeStr(scope const(char)[][] m...) @nogc nothrow @trusted
        {
            auto stderr_own = stderr_get_stderr();
            scope(exit) streams_output_stream_drop_own(stderr_own);

            auto stderr = streams_borrow_output_stream(stderr_own);

            foreach (s; m) {
                wasip2_list_u8_t contents;
                contents.ptr = cast(ubyte*)s.ptr;
                contents.len = s.length;
                streams_stream_error_t err;
                bool success = streams_method_output_stream_blocking_write_and_flush(stderr, &contents, &err);
                if (!success) {
                    streams_stream_error_free(&err);
                }
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
