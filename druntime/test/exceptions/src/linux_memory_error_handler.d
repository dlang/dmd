import etc.linux.memoryerror;
import core.sys.posix.unistd : write;

void main()
{
    static if (is(registerMemoryErrorHandler))
    {
        int* getNull() {
            return null;
        }

        assert(registerMemoryErrorHandler());

        bool b;

        try
        {
            *getNull() = 42;
        }
        catch (NullPointerError)
        {
            b = true;
        }

        assert(b);

        b = false;

        try
        {
            *getNull() = 42;
        }
        catch (InvalidPointerError)
        {
            b = true;
        }

        assert(b);

        assert(deregisterMemoryErrorHandler());
    }
    // Avoid libc's shared stderr FILE* here; Alpine/musl crashes when this
    // low-level signal-handler test reaches it through atomicLoad(stderr).
    enum message = "success.\n";
    write(2, message.ptr, message.length);
}
