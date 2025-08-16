// Test __attribute__((aligned))
// Same as _Alignas, but (silently) accepted in all places
typedef __attribute__((aligned(4))) int sun;

__attribute__((aligned(8))) int mercury();

void venus()
{
    register __attribute__((aligned(8))) int x;
}

void earth(__attribute__((aligned(4))) int x)
{
}

void mars(x)
__attribute__((aligned(4))) int x;
{
}

struct B
{
    __attribute__((aligned(4))) int bf : 3;
    __attribute__((aligned(8))) int : 0;
};

struct S
{
    __attribute__((aligned(1))) __attribute__((aligned(_Alignof(int)))) int x;
    __attribute__((aligned(1))) __attribute__((aligned(16))) int y;
    __attribute__((aligned(1))) int z;
};

int main()
{
    __attribute__((aligned(1))) __attribute__((aligned(_Alignof(int)))) int x;
    __attribute__((aligned(1))) __attribute__((aligned(16))) int y;
    __attribute__((aligned(1))) int z;
}
