// https://issues.dlang.org/show_bug.cgi?id=22016

/*
TEST_OUTPUT:
---
---
*/

enum E { one = 1 }
int i;
void gun(int n)
{
    return n == E.one ? ++i : (){}();
}

void main()
{
    gun(1);
    assert(i == 1);
}
