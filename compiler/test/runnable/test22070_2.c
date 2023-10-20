// https://issues.dlang.org/show_bug.cgi?id=22070

int printf(const char *, ...);

char(*var)[4] = &"123";
short(*var2)[2] = &(short[]){1, 2};

char test(void)
{
   char(*bar)[4] = &"456";
   return (*bar)[1];
}

_Static_assert(test() == '5', "in");

char test2(void)
{
   char(*bar)[4] = &"456";
   return 1[*bar];
}

_Static_assert(test2() == '5', "in");

short test3(void)
{
    short(*bar)[2] = &(short[]){1, 2};
    return (*bar)[1];
}

_Static_assert(test3() == 2, "");

char test4(void)
{
   register char(*bar)[4] = &"456";
   return 1[*bar];
}

_Static_assert(test4() == '5', "in");

int main()
{
    if ((*var)[2] != '3')
        return 1;
    if ((*var2)[1] != 2)
        return 1;
    if (test() != '5')
        return 1;
    if (test2() != '5')
        return 1;
    if (test3() != 2)
        return 1;
    if (test4() != '5')
        return 1;
    return test23055();
}

// https://issues.dlang.org/show_bug?id=23055

int *px = (int[1]){0};

int fn()
{
    int *p = (int[1]){0};
    *p = 7;
    return *p;
}

_Static_assert(fn() == 7, "");

int test23055()
{
    return (fn() != 7);
}
