// https://issues.dlang.org/show_bug.cgi?id=22790

void test_static(int array[static 4]) {
    _Static_assert(sizeof(array) == sizeof(int*), "array must decay to pointer");
}

int main()
{
    int a[4];
    test_static(a);
    return 0;
}
