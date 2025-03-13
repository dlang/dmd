/*
REQUIRED_ARGS: -betterC
*/
// Fix: https://github.com/dlang/dmd/issues/20924 (invariant not called on extern(C++) classes)

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
        return;
    }
    assert(0, "Invariant in extern(C++) class was not checked");
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
        return;
    }
    assert(0, "Invariant in extern(D) class was not checked");
}

void main()
{
    // Test both class types
    testDClass();
    testCppClass();
} 

 
