// https://github.com/dlang/dmd/issues/20152

static int inited;
static void init(void);

int api(void)
{
    if (!inited)
        init();
    return inited;
}

static void init(void)
{
    inited = 1;
}
