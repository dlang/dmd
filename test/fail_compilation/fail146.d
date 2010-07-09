
int bar(int i)
{
    switch (i)
    {
	case 1:
	    i = 4;
	    break;
	case 8:
	    i = 3;
	    break;
    }
    return i;
}

void main()
{
    static b = bar(7);
    printf("b = %d, %d\n", b, bar(7));
    assert(b == 3);
}
