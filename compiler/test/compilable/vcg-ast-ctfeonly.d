/*
REQUIRED_ARGS: -vcg-ast -o-
PERMUTE_ARGS:
OUTPUT_FILES: compilable/vcg-ast-ctfeonly.d.cg
TEST_OUTPUT_FILE: extra-files/vcg-ast-ctfeonly.d.cg
*/

// Template instances that are never code generated, such as `@__ctfe` functions,
// and whatever they instantiated, are left out of the codegen AST.

module vcg_ast_ctfeonly;

int twice(int x)
{
    return x * 2;
}

int ctfeOnly(T)(T x) @__ctfe
{
    return helper!T(x);
}

int helper(T)(T x)
{
    return twice(x) + 1;
}

int atRuntime(T)(T x)
{
    return twice(x);
}

enum e = ctfeOnly!int(1);

int main()
{
    return atRuntime!int(e);
}
