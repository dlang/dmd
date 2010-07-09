
template Vector(T)
{
	int x;

	class Vector
	{
	}
}


	struct Sorter
	{
	}

	void Vector_test_int()
	{
		alias Vector!(int).Vector		vector_t;
		vector_t v;
		Sorter	sorter;
		v.sort_with!(int)(sorter);
	}
