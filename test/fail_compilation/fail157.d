// REQUIRED_ARGS: -d

typedef int myint = 4;

struct S
{
    int i;
    union
    {	int x = 2;
	int y;
    }
    int j = 3;
    myint k;
}


void main()
{
    S s = S( 1, 5, 6 );
    assert(s.i == 1);
    assert(s.x == 5);
    assert(s.y == 5);
    assert(s.j == 3);
    assert(s.k == 4);
}
