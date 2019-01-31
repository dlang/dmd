// https://issues.dlang.org/show_bug.cgi?id=1870
// https://issues.dlang.org/show_bug.cgi?id=12790
string get()
{
    return "int x =\n        123;\r\n" ~
    q{
        int y;
        
        
        
        int z = x + y;};
}

void main()
{
    mixin(get());
}
