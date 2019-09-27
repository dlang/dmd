// https://issues.dlang.org/show_bug.cgi?id=1760
/*
TEST_OUTPUT:
---
---
*/

int delegate() three()
{
	int a = 35;
	int b = 60;
	int c = 75;

    int getb(){ return b; }
    int geta(){ return a; }

    *(&c - 1) = 2;       // modify b, ensuring b is on stack
    assert(b == 2);
    return &geta;
}

void main()
{
	three();
}
