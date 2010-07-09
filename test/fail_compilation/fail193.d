
void foo() { }
void foo(int) { }

void main()
{
    //void function(int) fp = &foo;
    auto fp = &foo;
    fp(1);
}
