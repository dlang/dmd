
void main()
{
    int x;
    invariant(int)* p = &x;
    *p = 3;
}
