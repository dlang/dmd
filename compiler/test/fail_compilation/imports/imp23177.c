// https://github.com/dlang/dmd/issues/23177

typedef int(*fp)();

int run(fp fn)
{
    return fn();
}
