
void main()
{
    int i = 2;
    switch (i)
    {
	case 1: .. case 300:
	    i = 5;
	    break;
    }
    if (i != 5)
	assert(0);
}
