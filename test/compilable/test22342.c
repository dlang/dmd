// https://issues.dlang.org/show_bug.cgi?id=22342

void func();
void booc(int);

void cooc(i)
int i;
{
}

void test()
{
    func(3);
    booc(3);
    cooc(1, 3);
}
