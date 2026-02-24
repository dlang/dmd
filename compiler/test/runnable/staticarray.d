void main()
{
	int[3] arr1 = [1,2,3];
	int[$] arr2 = [1,2,3];
	assert(arr1.length == 3);
	assert(arr2.length == 3);
	static assert(arr2.length == 3);
	assert(arr1 == arr2);

	int[$] arr3 = [10] ~ [20];
	assert(arr3.length == 2);
	assert(arr3[0] == 10);
	assert(arr3[1] == 20);
	static assert(arr3.length == 2);

	int[$][$] arr4 = [[10], [10]];
	assert(arr4.length == 2);
	assert(arr4[0].length == 1);
	static assert(arr4.length == 2);
	static assert(arr4[0].length == 1);

	int[$] arr5 = 3;
	assert(arr5.length == 1);
	assert(arr5[0] == 3);
	static assert(arr5.length == 1);

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

	float[$] arr10 = 3.0f;
	assert(arr10.length == 1);
	assert(arr10[0] == 3.0f);
	static assert(arr10.length == 1);
}
