/* REQUIRED_ARGS: -verrors=spec
TEST_OUTPUT:
---
(spec:1) fail_compilation/test17380spec.d(14): Error: cannot resolve identifier `ThisTypeDoesNotExistsAndCrahesTheCompiler`
(spec:1) fail_compilation/test17380spec.d(14): Error: no property 'ThisTypeDoesNotExistsAndCrahesTheCompiler' for type 'Uint128'
fail_compilation/test17380spec.d(14): Error: undefined identifier `ThisTypeDoesNotExistsAndCrahesTheCompiler`
---
 */

struct Int128
{
    Uint128 opCast()
    {
        return ThisTypeDoesNotExistsAndCrahesTheCompiler;
    }
    alias opCast this;
}

struct Uint128
{
    Int128 opCast() { return Int128.init; }
    alias opCast this;
}
