struct BigInt1
{
    int[] dara;

    bool opEquals(const ref BigInt1 rhs) const  // -> stored in TypeInfo_Struct.xopEquals
    {
        return true;
    }
    bool opEquals(T)(T rhs) const
    {
        return false;
    }

    int opCmp(const ref BigInt1 rhs) const      // stored in TypeInfo_Struct.xopCmp
    {
        return 0;
    }
    int opCmp(T)(T rhs) const
    {
        return 1;
    }
}

struct BigInt2
{
    int[] dara;

    bool opEquals(const ref BigInt2 rhs) const  // stored in TypeInfo_Struct.xopEquals
    {
        return true;
    }

    int opCmp(const ref BigInt2 rhs) const      // stored in TypeInfo_Struct.xopCmp
    {
        return 0;
    }
}

struct BigInt3
{
    int[] dara;

    bool opEquals(T)(T rhs) const   // stored in TypeInfo_Struct.xopEquals
    {
        return true;
    }

    int opCmp(T)(T rhs) const       // stored in TypeInfo_Struct.xopCmp
    {
        return 0;
    }
}
