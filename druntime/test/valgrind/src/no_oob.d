// Out-of-bounds access (within the same block).

void main()
{
    auto arr = new ubyte[4];
    arr.ptr[5] = 2;
}
