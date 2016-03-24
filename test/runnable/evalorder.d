extern(C) int printf(const char*, ...);

void test14040()
{
    uint[] values = [0, 1, 2, 3, 4, 5, 6, 7];
    uint offset = 0;

    auto a1 = values[offset .. offset += 2];
    if (a1 != [0, 1] || offset != 2)
        assert(0);

    uint[] fun()
    {
        offset += 2;
        return values;
    }
    auto a2 = fun()[offset .. offset += 2];
    if (a2 != [4, 5] || offset != 6)
        assert(0);

    // Also test an offset of type size_t such that it is used
    // directly without any implicit conversion in the slice expression.
    size_t offset_szt = 0;
    auto a3 = values[offset_szt .. offset_szt += 2];
    if (a3 != [0, 1] || offset_szt != 2)
        assert(0);
}

/******************************************/

int main()
{
    test14040();

    printf("Success\n");
    return 0;
}
