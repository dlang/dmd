// https://issues.dlang.org/show_bug.cgi?id=22592

int printf(const char *s, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test %d\n", line);
        exit(1);
    }
}

int testfn(void);

typedef struct config_s {
   short field;
} config;

static const config table[10] = {
    {0}, {4}, {5}, {6}, {4}, {8}, {16}, {32}, {128}, {258}
};

int testfn()
{
    return table[6].field;
}

int main()
{
    assert(testfn() == 16, 1);
    return 0;
}
