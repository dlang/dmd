
void foo()
{
    auto a = "abc";
    immutable char[3] b = "abc";
    //const char[3] b = "abc";
    b[1] = 'd';
}
