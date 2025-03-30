// Out-of-bounds access (SENTINEL).

void main()
{
    auto arr = new ubyte[4];
    arr.ptr[-1] = 42;
}
