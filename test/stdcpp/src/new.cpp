#include <cstddef> // for size_t?
#include <new>

struct MyStruct
{
    int *a;
    double *b;
    MyStruct *c;
};

MyStruct cpp_new()
{
    MyStruct r;
    r.a = (int*)::operator new(sizeof(int));
    r.b = (double*)::operator new(sizeof(double));
    r.c = (MyStruct*)::operator new(sizeof(MyStruct));
    return r;
}

void cpp_delete(MyStruct& s)
{
    ::operator delete(s.a);
    ::operator delete(s.b);
    ::operator delete(s.c);
}

size_t defaultAlignment()
{
#if defined(__STDCPP_DEFAULT_NEW_ALIGNMENT__)
    return __STDCPP_DEFAULT_NEW_ALIGNMENT__;
#else
    return 0;
#endif
}

bool hasAlignedNew()
{
#if defined(__cpp_aligned_new)
    return !!__cpp_aligned_new;
#else
    return false;
#endif
}
