
int bar(int i)
{
    assert(i < 0, "message");
    foreach_reverse (k, v; "hello")
    {
	i <<= 1;
	if (k == 2)
	    break;
	i += v;
    }
    return i;
}

void main()
{
    static b = bar(7);
    printf("b = %d, %d\n", b, bar(7));
    assert(b == 674);
}
