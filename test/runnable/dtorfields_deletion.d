// https://issues.dlang.org/show_bug.cgi?id=21989
// Permutations only need to check optimizations
// REQUIRED_ARGS: -g -debug
/*
RUN_OUTPUT:
---
Throwing from TestClass
~S()
Throwing from TestClass
~S()
Throwing from TestStruct
~S()
Throwing from TestStruct
~S()
END main
~S()
~S()
---
*/

import core.stdc.stdio : printf, puts;

@safe pure:

struct S
{
    pure:

    int x = 42;
    int y;

    this(int y)
    {
        debug printf("S(%d)\n", x);
        this.y = y;
    }

    this(this)
    {
        debug puts("S(this)");
        if (x != 42)
            assert(false);
    }

    ~this()
    {
        debug puts("~S()");
        if (x != 42)
        {
            debug puts("OH NO!");
            // *(cast(int*) 1234) = 1;
            assert(false);
        }
        x = 0; // omitting this makes "OH NO!" go away
    }
}

class CustomException : Exception
{
    this() pure
    {
        super("Custom");
    }
}

class TestClass
{
    S s;

    this() pure
    {
        debug puts("Throwing from TestClass");
        throw new CustomException();
    }
}

struct TestStruct
{
    S s;

    this(int) pure
    {
        debug puts("Throwing from TestStruct");
        throw new CustomException();
    }

    this(this)
    {
        debug puts("TestStruct(this)");
    }
}

void main()
{
    try
        new TestClass();
    catch (CustomException e) {}

    try
        scope t = new TestClass();
    catch (CustomException e) {}

    try
        new TestStruct(1);
    catch (CustomException e) {}

    try
        scope t = TestStruct(1);
    catch (CustomException e) {}

    // Temporaries never reach the array memory...
    /*
    try
        TestStruct[] arr = [TestStruct(1), TestStruct(2)];
    catch (CustomException e) {}
    */
    debug puts("END main");
}
