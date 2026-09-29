class C
{
public:
    C();
    virtual void f() = 0;
    int i;
};

C::C()
{
    i = 5;
}
