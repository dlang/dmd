import etc.linux.memoryerror;
import core.atomic : atomicLoad;
import core.stdc.stdio : fprintf, stderr;

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
    fprintf(atomicLoad(stderr), "success.\n");
}
