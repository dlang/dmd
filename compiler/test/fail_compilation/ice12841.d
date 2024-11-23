/*
TEST_OUTPUT:
---
fail_compilation/ice12841.d(27): Error: cannot take address of expression `taskPool().amap(Args...)(Args args)` because it is not an lvalue
    auto dg = &(taskPool.amap!"a.result()");
                        ^
fail_compilation/ice12841.d(28): Error: cannot take address of template `amap(Args...)(Args args)`, perhaps instantiate it first
    auto fp = &(TaskPool.amap!"a.result()");
                        ^
---
*/

@property TaskPool taskPool() @trusted { return new TaskPool; }

final class TaskPool
{
    template amap(functions...)
    {
        auto amap(Args...)(Args args)
        {
        }
    }
}

void main()
{
    auto dg = &(taskPool.amap!"a.result()");
    auto fp = &(TaskPool.amap!"a.result()");
}
