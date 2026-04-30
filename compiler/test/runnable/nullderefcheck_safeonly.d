// REQUIRED_ARGS: -check=nullderef=safeonly
// PERMUTE_ARGS:

// Test that -check=nullderef=safeonly enables null checks only in @safe functions

struct Struct
{
    int field;
}

// @safe function: null deref check should fire
@safe void safeDereference()
{
    Struct* ptr;
    int val = ptr.field; // should throw
}

// @system function: null deref check should NOT fire (would segfault instead)
// We can't test the @system case at runtime without crashing, so we just
// verify the @safe case works correctly.

void main()
{
    // @safe null deref should be caught
    try
    {
        safeDereference();
        assert(0, "expected null dereference error");
    }
    catch (Error e)
    {
        // expected
    }
}
