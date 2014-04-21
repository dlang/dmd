// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/fail12558.d(16): Warning: catch statement without an exception specification is deprecated; use catch(Throwable) for old behavior
fail_compilation/fail12558.d(21): Warning: catch statement without an exception specification is deprecated; use catch(Throwable) for old behavior
---
*/

void main()
{
    auto handler = () { };

    try {
        assert(0);
    } catch
        handler();

    try {
        assert(0);
    } catch {
        handler();
    }

    version (none)
    {
        try {
            assert(0);
        } catch  // should not emit diagnostics
            handler();

        try {
            assert(0);
        } catch {  // ditto
            handler();
        }
    }
}
