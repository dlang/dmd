int wrongcode3139(int x)
{
	switch (x)
        {
		case -6:
		;
		case -5:
		;
		case -4:
		;
		{
			return 3;
		}
		default:
		{
			return 4;
		}
	}
}
static assert(wrongcode3139(-5) == 3);
