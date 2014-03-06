
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
