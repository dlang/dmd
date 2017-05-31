static immutable uint[] OneToTen = [1,2,3,4,5,6,7,8,9,10];

const(uint[]) SliceOf1to10(uint lwr, uint upr)
{
    return OneToTen[lwr .. upr];
}

const(uint)[] testConcat()
{
    return SliceOf1to10(0,4) ~ SliceOf1to10(7,9);
}

static assert(testConcat == [1,2,3,4,8,9]);
static assert(SliceOf1to10(2,8) == [3u, 4u, 5u, 6u, 7u, 8u]);
static assert(SliceOf1to10(1,10) == [2,3u, 4u, 5u, 6u, 7u, 8u,9,10]);
