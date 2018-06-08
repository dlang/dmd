// https://issues.dlang.org/show_bug.cgi?id=15360

enum isErrorizable(T) = is(T == int);

void main()
{
    int a;
    if (isErrorizable!typeof(a))
    {}
}
