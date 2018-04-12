// REQUIRED_ARGS: -de
/* TEST_OUTPUT:
---
fail_compilation/fail17626.d(13): Deprecation: Assignment of `ptr` has no effect
fail_compilation/fail17626.d(21): Deprecation: Assignment of `f` has no effect
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17626
struct FuncPtr{
    void* ptr;
    this(void* ptr){
        ptr = ptr;
    }
}

struct Foo
{
    this(int f)
    {
        f = f; // oops
    }

    int f;

}
void test()
{
    auto foo = Foo(42);
}

// https://github.com/libmir/mir-algorithm/blob/f22937fe70970a220d970d27df1026becdf63f5a/source/mir/ndslice/sorting.d#L181
enum naive_est = 64;
enum size_t naive = 32 > naive_est ? 32 : naive_est;
