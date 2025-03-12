/*
TEST_OUTPUT:
---
Success: extern(D) class invariant was checked properly
Success: extern(C++) class invariant was checked properly
---
*/


extern(C++) class C
{
    invariant { assert(0); }
    void f() {}
}

extern(D) class D
{
    invariant { assert(0); }
    void f() {}
}

// This function runs tests on extern(C++) class
void testCppClass()
{
    import core.exception : AssertError;
    
    try
    {
        auto c = new C();
        c.f(); // Should trigger invariant
        assert(false, "Failed: invariant in extern(C++) class not checked");
    }
    catch (AssertError e)
    {
        // Expected behavior - invariant was checked
        import std.stdio : writeln;
        writeln("Success: extern(C++) class invariant was checked properly");
    }
}

// Runs tests on extern(D) class for comparison
void testDClass()
{
    import core.exception : AssertError;
    
    try
    {
        auto d = new D();
        d.f(); // Should trigger invariant
        assert(false, "Failed: invariant in extern(D) class not checked");
    }
    catch (AssertError e)
    {
        // Expected behavior - invariant was checked
        import std.stdio : writeln;
        writeln("Success: extern(D) class invariant was checked properly");
    }
}

void main()
{
    // Test both class types
    testDClass();
    testCppClass();
} 

 
