#include <assert.h>

int *m = &(int){0};
int *p = &(int){8880};
int *q = &(int){9334};


int main()
{
    //global symbols
    assert(*m == 0);
    assert(*p == 8880);
    assert(*q == 9334);

    //local symbols
    int *a = &(int){0};
    int *b = &(int){55};
    int *c = &(int){90};
    assert(*a == 0);
    assert(*b == 55);
    assert(*c == 90);
    *b = 100;
    *c = 506;
    assert(*b == 100);
    assert(*c == 506);
    return 0;
}
