// PERMUTE_ARGS:

struct Node(T)
{
    T _val;
}

void foo()
{
    static struct Foo
    {
        Node!Foo* node;
    }
}
