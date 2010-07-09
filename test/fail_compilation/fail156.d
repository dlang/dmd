
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
    S s = S( 1, 5 );
    assert(s.i == 1);
    assert(s.x == 5);
    assert(s.y == 5);
    assert(s.j == 3);
    assert(s.k == 4);

    static S t = S( 1, 6, 6 );
    assert(t.i == 1);
    assert(t.x == 6);
    assert(t.y == 6);
    assert(t.j == 3);
    assert(t.k == 4);
}
