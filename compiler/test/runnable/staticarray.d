void main()
{
	int[3] arr1 = [1,2,3];
	int[$] arr2 = [1,2,3];
	assert(arr1.length == 3);
	assert(arr1.length == 3);
	static assert(arr2.length == 3);
	assert(arr1 == arr2);
}
