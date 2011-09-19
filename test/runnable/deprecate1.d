// REQUIRED_ARGS: -d

// Test cases using deprecated features
module deprecate1;

import core.stdc.stdio : printf;

template func19( T )
{
    typedef T function () fp = &erf;
    T erf()
    {
	printf("erf()\n");
	return T.init;
    }
}

alias func19!( int ) F19;

F19.fp tc;

void test19()
{
    printf("tc = %p\n", tc);
    assert(tc() == 0);
}

/******************************************/

int main()
{
    test19();
    return 0;
}
