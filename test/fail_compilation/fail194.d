import core.vararg;

void bar(int i, ...) { }

void foo() { }
void foo(int) { }

void main()
{
    //bar(1, cast(void function())&foo);
    bar(1, &foo);
}
