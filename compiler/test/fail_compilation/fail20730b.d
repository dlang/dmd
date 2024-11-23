/*
REQUIRED_ARGS: -verrors=spec -o-
TEST_OUTPUT:
---
(spec:1) fail_compilation/fail20730b.d-mixin-47(47): Error: C style cast illegal, use `cast(int)mod`
fail_compilation/fail20730b.d(30): Error: template `atomicOp` is not callable using argument types `!("+=")(shared(uint), int)`
        atomicOp!"+="(refs, 1);
                     ^
fail_compilation/fail20730b.d(45):        Candidate is: `atomicOp(string op, T, V1)(ref shared T val, V1 mod)`
  with `op = "+=",
       T = uint,
       V1 = int`
  must satisfy the following constraint:
`       __traits(compiles, mixin("(int)mod"))`
T atomicOp(string op, T, V1)(ref shared T val, V1 mod)
  ^
---
*/
void test20730()
{
    auto f = File().byLine;
}

struct File
{
    shared uint refs;

    this(this)
    {
        atomicOp!"+="(refs, 1);
    }

    struct ByLineImpl(Char)
    {
        File file;
        char[] line;
    }

    auto byLine()
    {
        return ByLineImpl!char();
    }
}

T atomicOp(string op, T, V1)(ref shared T val, V1 mod)
    // C-style cast causes raises a parser error whilst gagged.
    if (__traits(compiles, mixin("(int)mod")))
{
    return val;
}
