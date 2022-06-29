void main()
{
	alias AA = int[string];
	// aa is not ref
	void test(AA aa)
	{
		aa[""] = 0;
	}
	auto aa = new AA();
	auto ab = new int[string];
	auto ac = new typeof(aa);
	test(aa);
	test(ab);
	test(ac);
	assert(aa.length);
	assert(ab.length);
	assert(ac.length);
}
