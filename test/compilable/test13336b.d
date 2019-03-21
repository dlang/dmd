// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:
/* TEST_OUTPUT:
---
---
*/
int sx;
double sy;

ref f1(bool f)
{
    if (f)
        return sx;
    return sy;
}

ref f2(bool f)
{
    if (f)
        return sy;
    return sx;
}
