
struct S
{
    align(1)
    {
        short x1;
        int y1;
        long z1;

        align(default)
        {
            short x;
            int y;
            long z;
        }
    }
}

void main()
{
    static assert(S.x1.alignof == 1);
    static assert(S.y1.alignof == 1);
    static assert(S.z1.alignof == 1);

    static assert(S.x.alignof == 2);
    static assert(S.y.alignof == 4);
    static assert(S.z.alignof == 8);
}
