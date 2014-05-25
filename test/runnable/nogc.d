
extern(C) int printf(const char*, ...);

/***********************/

@nogc int test1()
{
    return 3;
}

/***********************/

int main()
{
    test1();

    printf("Success\n");
    return 0;
}
