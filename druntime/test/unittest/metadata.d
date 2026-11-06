module metadata;

import core.runtime : Runtime, UnitTestResult;

int[] calls;
unittest { calls ~= 1; }
struct Aggregate
{
    unittest { calls ~= 2; }
}
unittest { calls ~= 3; }
struct Instance(T)
{
    unittest { calls ~= cast(int) T.sizeof; }
}
Instance!int intInstance;
Instance!long longInstance;
class LocalClass {}

shared static this()
{
    // Leave execution to main so it can compare the wrapper with discovery.
    Runtime.extendedModuleUnitTester = () => UnitTestResult(0, 0, true, false);
}

void main()
{
    ModuleInfo* info;
    foreach (candidate; ModuleInfo)
        if (candidate.name == "metadata")
            info = candidate;
    assert(info !is null);
    assert(info.name == "metadata");
    assert(info.localClasses.length == 1);
    assert(info.importedModules.length != 0);
    version (unittest)
    {
        auto tests = info.unitTests;
        assert(tests.length == 5);
        alias aggregateTest = __traits(getUnitTests, Aggregate)[0];
        assert(tests[1].func == &aggregateTest);
        static assert(!__traits(compiles, tests[0] = null));
        static assert(!__traits(compiles, tests[0].name = "changed"));
        immutable expectedNames = [
            "__unittest_L6_C1",
            "__unittest_L9_C5",
            "__unittest_L11_C1",
            "__unittest_L14_C5_1",
            "__unittest_L14_C5_2",
        ];
        foreach (i, test; tests)
        {
            assert(test.size == UnitTestInfo.sizeof);
            assert(test.func !is null);
            assert(test.name == expectedNames[i]);
            test.func();
        }
        auto individualCalls = calls.dup;
        assert(individualCalls.length == 5);
        assert(individualCalls[0 .. 3] == [1, 2, 3]);
        calls = null;
        auto wrapper = info.unitTest;
        wrapper();
        assert(calls == individualCalls);
    }
    else
    {
        assert(info.unitTests.length == 0);
        assert(info.unitTest is null);
    }

    // Legacy ModuleInfo records need no trailing metadata to be queried.
    ModuleInfo legacy;
    assert(legacy.unitTests.length == 0);
}
