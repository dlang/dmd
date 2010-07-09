void main()
{
    int i = 0;

    void fn()
    {
	asm
	{
	    naked;
	    lea EAX, i;
	    mov [EAX], 42;
	    ret;
	}
    }
    fn();
    printf( "i = %d\n", i );
}

