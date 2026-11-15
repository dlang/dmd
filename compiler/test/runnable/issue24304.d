/*
REQUIRED_ARGS: -mcpu=native
PERMUTE_ARGS: -O -inline -release
*/

// merge with optimize.d later


ushort f(int n)
{
    ushort v = 1;
    for (uint i = 0; i < 1; i++)
        v = cast(ushort)(i & 0x10000);
    v >>>= n;
    return v;
}

void main()
{
    assert(f(1) == 0); // fails
}
