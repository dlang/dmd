/*
TEST_OUTPUT:
---
fail_compilation/diag11756.d(23): Error: cannot read uninitialized variable `cnt` in CTFE
        (*cnt)--;   // error
          ^
fail_compilation/diag11756.d(42):        called from here: `foo.ptr2.opAssign(Ptr(& n))`
    foo.ptr2 = Ptr(&n);
             ^
fail_compilation/diag11756.d(47):        called from here: `test()`
static assert(test());
                  ^
fail_compilation/diag11756.d(47):        while evaluating: `static assert(test())`
static assert(test());
^
---
*/

struct Ptr
{
    void opAssign(Ptr other)
    {
        (*cnt)--;   // error
        cnt = other.cnt;
        (*cnt)++;
    }
    size_t *cnt;
}

union Foo
{
    size_t *ptr1;
    Ptr ptr2;
}

bool test()
{
    Foo foo;
    size_t cnt = 1;
    foo.ptr1 = &cnt;
    size_t n;
    foo.ptr2 = Ptr(&n);
    assert(cnt == 0);

    return true;
}
static assert(test());
