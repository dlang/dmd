#include <memory>

struct MyStruct
{
    int *a;
    double *b;
    MyStruct *c;
};

MyStruct cpp_alloc(int sz)
{
    MyStruct r;
    r.a = std::allocator<int>().allocate(sz);
    r.b = std::allocator<double>().allocate(sz);
    r.c = std::allocator<MyStruct>().allocate(sz);
    return r;
}

void cpp_free(MyStruct& s, int sz)
{
    std::allocator<int>().deallocate(s.a, sz);
    std::allocator<double>().deallocate(s.b, sz);
    std::allocator<MyStruct>().deallocate(s.c, sz);
}
