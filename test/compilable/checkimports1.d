// This test was first created to verify -transition=checkimiports and -revert=import compiler flags
// After they were deprecated this test passed due to the `lines` being local to `C`.
// `imports.diag12598a` contains a `public struct lines { }`, but the lookup resolution prefers the
// local `string[] lines` and therefore compiles.

class C
{
    void f()
    {
        import imports.diag12598a;
        lines ~= "";
    }

    string[] lines;
}
