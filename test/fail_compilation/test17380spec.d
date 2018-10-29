/* REQUIRED_ARGS: -verrors=spec
TEST_OUTPUT:
---
fail_compilation/test17380spec.d(12): Error: undefined identifier `ThisTypeDoesNotExistAndCrashesTheCompiler`
---
 */

struct Int128
{
    Uint128 opCast()
    {
        return ThisTypeDoesNotExistAndCrashesTheCompiler;
    }
    alias opCast this;
}

struct Uint128
{
    Int128 opCast() { return Int128.init; }
    alias opCast this;
}
