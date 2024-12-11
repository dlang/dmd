/* REQUIRED_ARGS: -verrors=spec
TEST_OUTPUT:
---
(spec:1) fail_compilation/test17380spec.d(23): Error: cannot resolve identifier `ThisTypeDoesNotExistAndCrashesTheCompiler`
        return ThisTypeDoesNotExistAndCrashesTheCompiler;
               ^
(spec:1) fail_compilation/test17380spec.d(23): Error: no property `ThisTypeDoesNotExistAndCrashesTheCompiler` for `this.opCast()` of type `test17380spec.Uint128`
        return ThisTypeDoesNotExistAndCrashesTheCompiler;
               ^
(spec:1) fail_compilation/test17380spec.d(28):        struct `Uint128` defined here
struct Uint128
^
fail_compilation/test17380spec.d(23): Error: undefined identifier `ThisTypeDoesNotExistAndCrashesTheCompiler`
        return ThisTypeDoesNotExistAndCrashesTheCompiler;
               ^
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
