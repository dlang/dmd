/**
 * EXTRA_SOURCES: imports/nortti.d
 * REQUIRED_ARGS: -betterC -Irunnable/extra-files/miniRT -defaultlib= -release
 */

// Real test is in imports/nortti.d
import nortti;

// TODO: Make this optional for betterC? But then we disable exception handling?
version (Windows)
{
    extern(C) void _d_framehandler(void*) {}
}

/// extern(C) so we can run this with a minimal runtime
extern(C) int main()
{
    return testNORTTI();
}
