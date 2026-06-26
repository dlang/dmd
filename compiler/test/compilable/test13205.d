void foo(int[8]) {}

void main()
{
    int[100] a;
    int j = 20;
    int[8] b = a[j .. j + 8];
    foo(a[j .. j + 8]);
    foo(b);
}
