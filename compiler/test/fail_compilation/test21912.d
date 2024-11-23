/*
PERMUTE_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test21912.d(52): Error: function `test21912.escapeParam` is `@nogc` yet allocates closure for `escapeParam()` with the GC
Dg escapeParam(int i)
   ^
fail_compilation/test21912.d(54):        delegate `test21912.escapeParam.__lambda_L54_C21` closes over variable `i`
    return identity(() => i);
                    ^
fail_compilation/test21912.d(52):        `i` declared here
Dg escapeParam(int i)
                   ^
fail_compilation/test21912.d(57): Error: function `test21912.escapeAssign` is `@nogc` yet allocates closure for `escapeAssign()` with the GC
Dg escapeAssign(int i, return scope Dg dg)
   ^
fail_compilation/test21912.d(59):        delegate `test21912.escapeAssign.__lambda_L59_C10` closes over variable `i`
    dg = () => i;
         ^
fail_compilation/test21912.d(57):        `i` declared here
Dg escapeAssign(int i, return scope Dg dg)
                    ^
fail_compilation/test21912.d(68): Error: function `test21912.escapeAssignRef` is `@nogc` yet allocates closure for `escapeAssignRef()` with the GC
ref Dg escapeAssignRef(int i, return ref scope Dg dg)
       ^
fail_compilation/test21912.d(70):        delegate `test21912.escapeAssignRef.__lambda_L70_C10` closes over variable `i`
    dg = () => i;
         ^
fail_compilation/test21912.d(68):        `i` declared here
ref Dg escapeAssignRef(int i, return ref scope Dg dg)
                           ^
fail_compilation/test21912.d(79): Error: function `test21912.escapeParamInferred` is `@nogc` yet allocates closure for `escapeParamInferred()` with the GC
Dg escapeParamInferred(int i)
   ^
fail_compilation/test21912.d(81):        delegate `test21912.escapeParamInferred.__lambda_L81_C29` closes over variable `i`
    return identityInferred(() => i);
                            ^
fail_compilation/test21912.d(79):        `i` declared here
Dg escapeParamInferred(int i)
                           ^
---
*/
@nogc:

alias Dg = @nogc int delegate();

Dg identity(return scope Dg dg)
{
    return dg;
}

Dg escapeParam(int i)
{
    return identity(() => i);
}

Dg escapeAssign(int i, return scope Dg dg)
{
    dg = () => i;
    return dg;
}

ref Dg identityR(return ref scope Dg dg)
{
    return dg;
}

ref Dg escapeAssignRef(int i, return ref scope Dg dg)
{
    dg = () => i;
    return dg;
}

auto identityInferred(Dg dg)
{
    return dg;
}

Dg escapeParamInferred(int i)
{
    return identityInferred(() => i);
}
