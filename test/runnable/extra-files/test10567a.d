struct BigInt
{
    int[] dara;

    int opCmp(const ref BigInt rhs) const
    {
        return 0;
    }

    int opCmp(T)(T rhs) const
    {
        return 1;
    }
}
