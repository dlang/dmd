// https://github.com/dlang/dmd/issues/22790

void test_static(int array[static 4]) {
    _Static_assert(sizeof(array) == sizeof(int*), "array must decay to pointer");
}

void f1 (int[static 1 + 1]);
// sizeof a fails with undefined identifier 'a' since previous parameters aren't in scope yet.
// void f2 (int a, int x[static sizeof(a)]);

void f1a (int a[static 2])
{
  int **b = &a;
  int *const *c = &a;
}

void f3a (int a[static const 2])
{
  int **b = &a;
  int *const *c = &a;
}

int main()
{
    int a[4];
    test_static(a);
    return 0;
}
