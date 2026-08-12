/*
REQUIRED_ARGS: -O
*/

struct Arr
{
    size_t len;
    int* ptr;

    size_t length() const { return len; }

    inout(int)[] opSlice(size_t a, size_t b) inout
    {
        assert(a <= b && b <= len);
        return ptr[a .. b];
    }

    alias opDollar = length;
}

int[] tail(Arr* p, size_t n)
{
    return (*p)[$ - n .. $];
}

void main()
{
    int[4] buf = [1, 2, 3, 4];
    auto a = Arr(3, buf.ptr);
    assert(tail(&a, 2) == [2, 3]);
}
