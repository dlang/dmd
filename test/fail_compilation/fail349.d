
int f()     { return 1; }
int f(int n){ return 2; }

auto testf()
{
	return &f;
}

void main()
{
	auto t = testf();
}
