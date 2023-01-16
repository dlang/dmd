/* REQUIRED_ARGS: -betterC
 */

// https://issues.dlang.org/show_bug.cgi?id=21492

int test(int i)
{
    switch (i)
    {
	case 0:
	    break;
	case 1:
	    if (__ctfe)
	    {
		{ int[] foo = [1]; }
	L3:
		i += 2;
	case 2:
		++i;
	    }
	    return i;
	default:
	    break;
    }
    goto L3;
}

extern (C)
int main()
{
    static assert(test(1) == 4);
    assert(test(2) == 3);
    return 0;
}
