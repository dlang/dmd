
void main()
{
    int x;
    immutable(int)* p = &x;
    *p = 3;
}
