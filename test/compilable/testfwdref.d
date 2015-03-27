// PERMUTE_ARGS:

/***************************************************/
// 12152

class A12152
{
    alias Y = B12152.X;
}

class B12152 : A12152
{
    alias int X;
}

static assert(is(A12152.Y == int));
