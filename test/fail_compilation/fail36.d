template t(int L)
{
int a;
// void foo(int b = t!(L).a) {} // correct
void foo(int b = t.a) {} // wrong
}

void func()
{
mixin t!(10);
}

