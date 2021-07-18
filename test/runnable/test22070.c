// https://issues.dlang.org/show_bug.cgi?id=22070

int printf(const char *, ...);

char(*var)[4] = &"123";

char test()
{
   char(*bar)[4] = &"456";
   return (*bar)[1];
}

int main()
{
    if ((*var)[2] != '3')
        return 1;
    if (test() != '5')
        return 1;
    return 0;
}

