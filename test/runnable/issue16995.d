// REQUIRED_ARGS: -unittest
// COMPILE_SEPARATELY
// EXTRA_SOURCES: imports/module_with_tests.d

import imports.module_with_tests;
import core.exception: AssertError;

shared static this()
{
    import core.runtime: Runtime;
    Runtime.moduleUnitTester = () => true;
}

void main()
{
    import module_with_tests;
    foreach(i, ut; __traits(getUnitTests, module_with_tests)) {
        try
        {
            ut();
            assert(i == 0, "2nd unittest should fail");
        }
        catch(AssertError e)
        {
            assert(i == 1, "Only 2nd unittest should fail");
        }
    }
}
