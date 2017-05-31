uint getLength()
{
    int[] localArr;
    int[] localArr2 = [];
    localArr.length = 6;
    return cast(uint)localArr.length;
}

static assert(getLength() == 6);
