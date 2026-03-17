void main()
{
	int[3] arr1 = [1,2,3];
	int[$] arr2 = [1,2,3];
	const(int)[$] arr13 = [1,2,3];
	assert(arr1.length == 3);
	assert(arr2.length == 3);
	assert(arr13.length == 3);
	static assert(arr2.length == 3);
	static assert(arr13.length == 3);
	static assert(is(typeof(arr13) == const(int)[3]));
	assert(arr1 == arr2);

	int[$] arr3 = [10] ~ [20];
	assert(arr3.length == 2);
	assert(arr3[0] == 10);
	assert(arr3[1] == 20);
	static assert(arr3.length == 2);

	int[$] arrConcatA = [2];
	int[$] arrConcatB = [2];
	int[$] arrConcatC = arrConcatA ~ arrConcatB;
	assert(arrConcatC.length == 2);
	assert(arrConcatC[0] == 2);
	assert(arrConcatC[1] == 2);
	static assert(arrConcatC.length == 2);
	static assert(is(typeof(arrConcatC) == int[2]));

	int[$][$] arr4 = [[10], [10]];
	assert(arr4.length == 2);
	assert(arr4[0].length == 1);
	static assert(arr4.length == 2);
	static assert(arr4[0].length == 1);

	static assert(!__traits(compiles,
	{
		int[$] arr5 = 3;
	}));

	int[$] arr6 = new int[2];
	assert(arr6.length == 2);

	int[N] arrn(size_t N)()
	{
	    int[N] res;
	    return res;
	}
	int[$] arr7 = arrn!(2)();
	assert(arr7.length == 2);
	static assert(arr7.length == 2);

	int[2][$] arr8 = [[1, 2], [3, 4], [5, 6]];
	assert(arr8.length == 3);
	assert(arr8[0].length == 2);
	static assert(arr8.length == 3);
	static assert(arr8[0].length == 2);

	int[$][$][$] arr9 = [[[1, 2]], [[3, 4]]];
	assert(arr9.length == 2);
	assert(arr9[0].length == 1);
	assert(arr9[0][0].length == 2);
	static assert(arr9.length == 2);
	static assert(arr9[0].length == 1);
	static assert(arr9[0][0].length == 2);

	static assert(!__traits(compiles,
	{
		float[$] arr10 = 3.0f;
	}));

	static assert(!__traits(compiles,
	{
		string[$] arr11 = "abc";
	}));

	char[$] arr12 = "abc";
	assert(arr12.length == 3);
	assert(arr12[0] == 'a');
	assert(arr12[1] == 'b');
	assert(arr12[2] == 'c');
}
