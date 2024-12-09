/*
PERMUTE_ARGS:
REQUIRED_ARGS: -verrors=spec
TEST_OUTPUT:
---
(spec:1) compilable/verrors_spec.d(15): Error: cannot implicitly convert expression `& i` of type `int*` to `int`
    bool b = __traits(compiles, {p = &i;});
                                     ^
---
*/

void foo(int i)
{
    int p;
    bool b = __traits(compiles, {p = &i;});
}
