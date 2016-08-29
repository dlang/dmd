void main()
{
	static assert(!__ctfe, "main should never be called at ctfe");
}

bool ctfeFun()
{
	static assert(__ctfe, "ctfeFun should only be used at ctfe");
	return __ctfe;
}

static assert(ctfeFun());

void test()
{
    static if (__ctfe) {}
    enum a = __ctfe ? "a" : "b";
    static int b = __ctfe * 2;
    int[__ctfe] sarr;
}

