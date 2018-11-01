// https://issues.dlang.org/show_bug.cgi?id=1870
// https://issues.dlang.org/show_bug.cgi?id=12790
string get()
{
    return
    q{int x;
        int y;
        
        
        
        int z = x + y;};
}

void main()
{
    mixin(get());
}
