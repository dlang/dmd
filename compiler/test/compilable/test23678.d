// https://github.com/dlang/dmd/issues/23678
// REQUIRED_ARGS: -betterC

struct S
{
    int value;

    this(int value)
    {
        this.value = value;
    }
}

S* place(S* result)
{
    return new(*result) S(42);
}
