module test10442;
import imports.test10442a;

struct T
{
    int x;
    void* p;
}

void main()
{
    // assumes enum RTInfo(T) = null
    assert(typeid(T).rtInfo == null); // ok
    assert(typeid(S).rtInfo == null); // fails
}
