/* TEST_OUTPUT:
---
fail_compilation/scopeerror.d(11): Error: scope variable p may not be returned
---
 */



int* test(scope int* p) @safe
{
    return p;
}
