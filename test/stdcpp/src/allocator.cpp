#include <memory>

struct MyStruct
{
    int *a;
    double *b;
    MyStruct *c;
};

MyStruct cpp_alloc()
{
    MyStruct r;
    r.a = std::allocator<int>().allocate(42);
    r.b = std::allocator<double>().allocate(42);
    r.c = std::allocator<MyStruct>().allocate(42);
    return r;
}

void cpp_free(MyStruct& s)
{
    std::allocator<int>().deallocate(s.a, 43);
    std::allocator<double>().deallocate(s.b, 43);
    std::allocator<MyStruct>().deallocate(s.c, 43);
}
