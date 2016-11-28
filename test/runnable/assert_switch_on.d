// REQUIRED_ARGS: -release -assert=on

import core.exception;

void main ()
{
    // If asserts are off => assert(0) leads to a SEGV
    // If they are on => The exception is caught as expected
    try { assert(0); }
    catch (AssertError e) return;

    assert(0);
}
