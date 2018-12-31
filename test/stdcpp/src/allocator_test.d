import core.stdcpp.allocator;

extern(C++) struct MyStruct
{
    int* a;
    double* b;
    MyStruct* c;
}

extern(C++) MyStruct cpp_alloc();
extern(C++) void cpp_free(ref MyStruct s);

unittest
{
    // alloc in C++, delete in D
    MyStruct s = cpp_alloc();
    allocator!int().deallocate(s.a, 42);
    allocator!double().deallocate(s.b, 42);
    allocator!MyStruct().deallocate(s.c, 42);

    // alloc in D, delete in C++
    s.a = allocator!int().allocate(43);
    s.b = allocator!double().allocate(43);
    s.c = allocator!MyStruct().allocate(43);
    cpp_free(s);
}
