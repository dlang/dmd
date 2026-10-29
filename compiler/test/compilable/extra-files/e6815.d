bool e(T)(T)
{
    f(true);
    return true;
}

void f(lazy bool) {}

bool e2(T)(T)
{
    return f2(true);
}

bool f2(lazy bool val) {
    return val();
}
