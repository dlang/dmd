// https://issues.dlang.org/show_bug.cgi?id=23708

// REQUIRED_ARGS: -preview=nosharedaccess

class Class {}
shared(Class) fun()
{
    static shared Class ret;
    return ret;
}
