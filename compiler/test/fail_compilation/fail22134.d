// https://issues.dlang.org/show_bug.cgi?id=22134
/* REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail22134.d(14): Deprecation: `this.arr[i]` has no effect
        return arr[i];
                  ^
---
*/
struct StackBuffer
{
    auto opIndex(size_t i)
    {
        return arr[i];
    }

private:
    void[] arr;
}
