import std.stdio;

struct Test
{
    Test opCall() if false
    {
        return Test();
    }
}

void main()
{
    auto instance = Test(); // This should be interpreted as a constructor call
    writeln("Test instance created successfully.");
}
