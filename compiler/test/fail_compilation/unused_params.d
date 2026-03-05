// REQUIRED_ARGS: -w -preview=warnunusedparams -o-

/*
TEST_OUTPUT:
---
fail_compilation/unused_params.d(21): Warning: function parameter `x` is never used
fail_compilation/unused_params.d(21): Warning: function parameter `y` is never used
fail_compilation/unused_params.d(24): Warning: function parameter `x` is never used
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/

// No warning for used parameter
void used(int x) { auto z = x + 1; }

// No warning for cast(void)suppression
void suppressed(int x) { cast(void)x; }

// Warn for unused named parameters
void unused(int x, int y) {}

// No warning for unnamed parameter, warn for named
void partial(int x, int) {}

// No warning when no body
interface I
{
    void iface(int x);
}
