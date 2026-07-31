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

	auto[$] arrAuto = [1, 2];
	assert(arrAuto.length == 2);
	assert(arrAuto[0] == 1);
	assert(arrAuto[1] == 2);
	static assert(arrAuto.length == 2);
	static assert(is(typeof(arrAuto) == int[2]));

	auto[$] autoConcatA = [2];
	auto[$] autoConcatB = [2];
	auto[$] autoConcatC = autoConcatA ~ autoConcatB;
	assert(autoConcatC.length == 2);
	assert(autoConcatC[0] == 2);
	assert(autoConcatC[1] == 2);
	static assert(autoConcatC.length == 2);
	static assert(is(typeof(autoConcatC) == int[2]));

	auto[$][$] arrAutoNested = [[10, 11], [20, 21]];
	assert(arrAutoNested.length == 2);
	assert(arrAutoNested[0].length == 2);
	assert(arrAutoNested[1].length == 2);
	assert(arrAutoNested[0][0] == 10);
	assert(arrAutoNested[0][1] == 11);
	assert(arrAutoNested[1][0] == 20);
	assert(arrAutoNested[1][1] == 21);
	static assert(arrAutoNested.length == 2);
	static assert(arrAutoNested[0].length == 2);
	static assert(arrAutoNested[1].length == 2);
	static assert(is(typeof(arrAutoNested) == int[2][2]));

	auto[$][$] autoNestedConcatA = [[2]];
	auto[$][$] autoNestedConcatB = [[2]];
	auto[$][$] autoNestedConcatC = autoNestedConcatA ~ autoNestedConcatB;
	assert(autoNestedConcatC.length == 2);
	assert(autoNestedConcatC[0].length == 1);
	assert(autoNestedConcatC[1].length == 1);
	assert(autoNestedConcatC[0][0] == 2);
	assert(autoNestedConcatC[1][0] == 2);
	static assert(autoNestedConcatC.length == 2);
	static assert(autoNestedConcatC[0].length == 1);
	static assert(autoNestedConcatC[1].length == 1);
	static assert(is(typeof(autoNestedConcatC) == int[1][2]));

  // Standard array literals should remain dynamic arrays (slices)
	auto standardArr = [1, 2, 3];
	static assert(is(typeof(standardArr) == int[]));
	static assert(!is(typeof(standardArr) == int[3]));

	// String literals should remain immutable(char)[]
	auto standardStr = "hello";
	static assert(is(typeof(standardStr) == string));
	static assert(!is(typeof(standardStr) == char[5]));

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

	static assert(!__traits(compiles,
	{
		int[$] arr6 = new int[2];
	}));

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

	// sparse static array initializer: mixed null and non-null indices
	auto[$] sparse1 = [ 0, 2:2, 3];
	assert(sparse1.length == 4);
	assert(sparse1[0] == 0);
	assert(sparse1[1] == 0);
	assert(sparse1[2] == 2);
	assert(sparse1[3] == 3);
	static assert(sparse1.length == 4);

	// all-indexed (like [3:42]) with auto[$]
	auto[$] sparse2 = [ 3:42 ];
	assert(sparse2.length == 4);
	assert(sparse2[0] == 0);
	assert(sparse2[3] == 42);
	static assert(sparse2.length == 4);

	// float sparse: gaps filled with float.init (NaN)
	auto[$] sparse3 = [ 1.5, 3:3.5 ];
	assert(sparse3.length == 4);
	assert(sparse3[0] == 1.5);
	assert(sparse3[1] != sparse3[1]); // NaN
	assert(sparse3[3] == 3.5);

	// mixed types: element type is the common type (int + double → double)
	auto[$] sparse4 = [ 1, 3:3.5 ];
	assert(sparse4.length == 4);
	static assert(is(typeof(sparse4[0]) == double));
	assert(sparse4[0] == 1);
	assert(sparse4[1] != sparse4[1]); // double.init = NaN
	assert(sparse4[3] == 3.5);

	// nested sparse: outer gap filled with inner array default init
	auto[$][$] sparse5 = [[0, 1], 2:[1, 1]];
	assert(sparse5.length == 3);
	assert(sparse5[0] == [0, 1]);
	assert(sparse5[1] == [0, 0]);
	assert(sparse5[2] == [1, 1]);
	static assert(sparse5.length == 3);
	static assert(sparse5[0].length == 2);
	static assert(is(typeof(sparse5) == int[2][3]));

	// regression: auto without $ still produces AA
	auto aa = [3:42];
	assert(aa.length == 1);
	assert(aa[3] == 42);
	static assert(is(typeof(aa) == int[int]));
}
