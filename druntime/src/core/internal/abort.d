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
        // currently depends on wasi-libc being linked in to provide these "syscalls"
        // TODO: detach this from wasi-libc
        alias ushort __wasi_errno_t;
        alias int __wasi_fd_t;
        alias size_t __wasi_size_t;

        extern(C) struct __wasi_ciovec_t {
            const(ubyte)* buf;
            __wasi_size_t buf_len;
        }

        extern(C) __wasi_errno_t
        __wasi_fd_write(__wasi_fd_t fd,
                        const __wasi_ciovec_t *iovs,
                        size_t iovs_len, __wasi_size_t *retptr0) @nogc nothrow;

        static void writeStr(scope const(char)[][] m...) @nogc nothrow @trusted
        {
            foreach (s; m) {
                __wasi_ciovec_t iovec;
                __wasi_size_t ret;
                iovec.buf = cast(const(ubyte)*)s.ptr;
                iovec.buf_len = s.length;
                cast(void)__wasi_fd_write(2, &iovec, 1, &ret);
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

        extern(C) void streams_output_stream_drop_own(streams_own_output_stream_t handle) @nogc nothrow;
        extern(C) streams_borrow_output_stream_t streams_borrow_output_stream(streams_own_output_stream_t handle) @nogc nothrow;
        extern(C) stderr_own_output_stream_t stderr_get_stderr() @nogc nothrow;
        extern(C) void io_error_error_drop_own(io_error_own_error_t handle) @nogc nothrow;
        extern(C) void streams_stream_error_free(streams_stream_error_t *ptr) @nogc nothrow;
        extern(C) bool streams_method_output_stream_blocking_write_and_flush(streams_borrow_output_stream_t self, wasip2_list_u8_t *contents, streams_stream_error_t *err) @nogc nothrow;

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
