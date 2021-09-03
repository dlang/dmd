typedef signed int int32_t;
void exit(int);
int printf(const char *fmt, ...);
int32_t ret()
{
    int32_t init = (1 + 3);
    return init;
}

int main()
{
    int32_t retVal = ret();
    if(retVal != 4)
    {
        printf("ret() returned %s, expected 4\n", retVal);
        exit(1);
    }
    return 0;
}