import core.stdcpp.allocator;

extern(C++) struct MyStruct
{
    int* a;
    double* b;
    MyStruct* c;
}

extern(C++) MyStruct cpp_alloc(int sz);
extern(C++) void cpp_free(ref MyStruct s, int sz);

unittest
{
    // alloc in C++, delete in D (small)
    MyStruct s = cpp_alloc(42);
    allocator!int().deallocate(s.a, 42);
    allocator!double().deallocate(s.b, 42);
    allocator!MyStruct().deallocate(s.c, 42);

    // alloc in C++, delete in D (big)
    s = cpp_alloc(8193);
    allocator!int().deallocate(s.a, 8193);
    allocator!double().deallocate(s.b, 8193);
    allocator!MyStruct().deallocate(s.c, 8193);

    // alloc in D, delete in C++ (small)
    s.a = allocator!int().allocate(43);
    s.b = allocator!double().allocate(43);
    s.c = allocator!MyStruct().allocate(43);
    cpp_free(s, 43);

    // alloc in D, delete in C++ (big)
    s.a = allocator!int().allocate(8194);
    s.b = allocator!double().allocate(8194);
    s.c = allocator!MyStruct().allocate(8194);
    cpp_free(s, 8194);
}
