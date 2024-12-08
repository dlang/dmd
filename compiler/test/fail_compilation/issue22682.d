/* TEST_OUTPUT:
---
fail_compilation/issue22682.d(24): Error: `pragma(mangle)` must be attached to a declaration
    pragma(mangle) {}
    ^
fail_compilation/issue22682.d(25): Error: `pragma(mangle)` takes a single argument that must be a string literal
    pragma(mangle) static int i0;
    ^
fail_compilation/issue22682.d(26): Error: `string` expected for pragma mangle argument, not `(0)` of type `int`
    pragma(mangle, 0) static int i1;
                   ^
fail_compilation/issue22682.d(26): Error: `pragma(mangle)` takes a single argument that must be a string literal
    pragma(mangle, 0) static int i1;
    ^
fail_compilation/issue22682.d(27): Error: `pragma(mangle)` must be attached to a declaration
    pragma(mangle);
    ^
---
 */
module issue22682;

void main()
{
    pragma(mangle) {}
    pragma(mangle) static int i0;
    pragma(mangle, 0) static int i1;
    pragma(mangle);
}
