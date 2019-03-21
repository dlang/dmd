/* TEST_OUTPUT:
---
---
*/
void main()
{
    shared int x;
    (cast() x) = 5;
    assert(x == 5);

    shared int x1;
    auto p = &(cast() x1);
}
