// REQUIRED_ARGS: -O -inline
// https://github.com/dlang/dmd/issues/24084

struct Mean(T)
{
    ulong count;
    T sum;

    F mean(F = T)() const
    {
        return cast(F) sum / cast(F) count;
    }

    void put()(T x)
    {
        ++count;
        sum += x;
    }
}

struct Variance(T)
{
    Mean!T accumulator;
    T squares;

    ulong count() const
    {
        return accumulator.count;
    }

    void put()(T x)
    {
        T delta = x;
        if (count > 0)
            delta -= accumulator.mean;

        accumulator.put(x);
        squares += delta * (x - accumulator.mean);
    }
}

// reduced version
int test()
{
    long count;
    long sum;
	if (count > 0)
		count = sum / count;
	return 1;
}

void main()
{
    Variance!ulong a;
    a.put(2UL);
    assert(a.count == 1 && a.squares == 0);

    test();
}
