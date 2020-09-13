// REQUIRED_ARGS: -preview=nosharedaccess

ref shared(int) f(return shared ref int y)
{
    return y;
}
