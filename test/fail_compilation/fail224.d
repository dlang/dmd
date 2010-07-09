int gi;

class A
{
    int x = 42;

    void am()
    {
	static void f()
	{
	    class B
	    {
		void bm()
		{
		    gi = x;
		}
	    }

	    (new B).bm();
	}

	f();
    }
}

void main()
{
    (new A).am();
}


