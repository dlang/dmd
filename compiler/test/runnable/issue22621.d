// Test for Issue 22621
// Destructor should not be called on uninitialized overlapped field

int dtorCalls = 0;

struct D
{
    int magic = 0xC0FFEE;

    ~this() @safe
    {
        // d's destructor should NOT be called,
        // while dd's destructor should be called.
        dtorCalls++;
        assert(magic == 0xC0FFEE, "Destructor called on uninitialized field!");
    }
}

struct SUS
{
    union {
        struct {
            D d;
        }
        uint b;
    }
    D dd;
}

void main()
{
    {
        // Initialize only 'b', not 'd'
        // Without the fix, d's destructor would be called on garbage memory
        SUS sus = SUS(b:0xDEADBEEF);
    }

    // Just dd's destructor should be called, so dtorCalls should be 1
    assert(dtorCalls == 1, "Destructor was incorrectly called!");
}
