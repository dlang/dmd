// https://issues.dlang.org/show_bug.cgi?id=22070

int printf(const char *, ...);

char(*var)[4] = &"123";

char test()
{
   char(*bar)[4] = &"456";
   return (*bar)[1];
}

_Static_assert(test() == '5', "in");

char test2()
{
   char(*bar)[4] = &"456";
   return 1[*bar];
}

_Static_assert(test2() == '5', "in");

int main()
{
    if ((*var)[2] != '3')
        return 1;
    if (test() != '5')
        return 1;
    if (test2() != '5')
        return 1;
    return 0;
}

