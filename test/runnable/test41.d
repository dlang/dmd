// EXTRA_SOURCES: imports/test41a.d
// PERMUTE_ARGS: -inline -g -O

import imports.test41a;
import core.exception;

int main()
{
    try
    {
        int x = foo();
        return 1;
    }
    catch (AssertError e)
    {
    }

    try
    {
        int x = func!(void)();
        return 1;
    }
    catch (AssertError e)
    {
    }

    return 0;
}

