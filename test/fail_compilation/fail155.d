
struct S
{
    int i;
    union
    {	int x;
	int y;
    }
    int j;
}

S s = S( 1, 2, 3, 4 );

void main()
{
}
