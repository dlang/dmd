import imports.test11745b;

shared static this()
{
        // Test that we can invoke all unittests, including private ones.
        assert(__traits(getUnitTests, imports.test11745b).length == 3);
        foreach(test; __traits(getUnitTests, imports.test11745b))
        {
                test();
        }
}
