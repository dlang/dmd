struct S {
	int opApply(Dg)(scope Dg dg)
	{
		return dg(1);
	}
}

int main()
{
	foreach(int i; S())
	{
		return i;
	}

	return 0;
}
