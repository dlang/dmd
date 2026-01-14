// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
---
*/
void main()
{
    enum var = true;
    @var string[] list = ["A", "B", "C"];

    // Also test explicitly with @(value) syntax
    @(1) int[] list2 = [1, 2, 3];
}
