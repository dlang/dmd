
void main()
{
    if(0) mixin("auto x = 2;");
    assert(x == 2);
}
