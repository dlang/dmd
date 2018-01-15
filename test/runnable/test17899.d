module test17899;

int setme = 0;
void delegate() bar1 = (){ setme = 1;};

__gshared void delegate() bar2 = (){ setme = 2;};

void main()
{
    assert(setme == 0);
    bar1();
    assert(setme == 1);
    bar2();
    assert(setme == 2);
}
