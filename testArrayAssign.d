uint[5] testArrayAssign()
{
    uint[5] arr = 12;
    arr[3] = 4;
    arr[0] = 1;
    return arr;
}

static immutable arr = testArrayAssign();
pragma(msg, arr);

static assert (arr == [1u, cast(ubyte)12u, cast(ubyte)12u, cast(ubyte)4u, cast(ubyte)12u]); 
