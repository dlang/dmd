/*
TEST_OUTPUT:
---
fail_compilation/trait_loc_err.d(20): Error: can only get the location of a symbol, not `trait_loc_err`
    __traits(getLocation, __traits(parent, main));
    ^
fail_compilation/trait_loc_err.d(21): Error: can only get the location of a symbol, not `core.stdc`
    __traits(getLocation, __traits(parent, core.stdc.stdio));
    ^
fail_compilation/trait_loc_err.d(22): Error: can only get the location of a symbol, not `core.stdc.stdio`
    __traits(getLocation, core.stdc.stdio);
    ^
---
*/
module trait_loc_err;
import core.stdc.stdio;

void main()
{
    __traits(getLocation, __traits(parent, main));
    __traits(getLocation, __traits(parent, core.stdc.stdio));
    __traits(getLocation, core.stdc.stdio);
}
