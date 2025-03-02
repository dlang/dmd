import std.stdio;

struct Test
{
    void opCall() if false
    {
        // No return needed since the method is now void
    }
}

void main()
{
    auto instance = Test(); // This should be interpreted as a constructor call
    writeln("Test instance created successfully.");
}
