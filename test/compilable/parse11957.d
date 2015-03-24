// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

extern(C++) class C
{
    void x() {}
}

void main()
{
    extern(C++) class D : C
    {
        override void x() {}
    }
}
