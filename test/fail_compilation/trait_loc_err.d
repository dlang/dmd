/*
TEST_OUTPUT:
---
fail_compilation/trait_loc_err.d(15): Error: can only get the location of a symbol, not `trait_loc_err`
fail_compilation/trait_loc_err.d(16): Error: can only get the location of a symbol, not `stdc`
fail_compilation/trait_loc_err.d(17): Error: `getLocation` accepts at most 2 parameters, not 3
fail_compilation/trait_loc_err.d(18): Error: The second parameter of `getOverloads` must have type `bool`, not `string`
---
*/
module trait_loc_err;
import core.stdc.stdio;

void main()
{
    __traits(getLocation, __traits(parent, main));
    __traits(getLocation, __traits(parent, core.stdc.stdio));
    __traits(getLocation, Type, true, 234);
    __traits(getLocation, Type, "Invalid");
}
struct Type
{

}
