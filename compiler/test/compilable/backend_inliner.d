/*
REQUIRED_ARGS: -O -inline
https://issues.dlang.org/show_bug.cgi?id=23857
backend inliner takes too long on recursive function call

This test doesn't need a timeout, since it would trip up an assert in dmd/backend/go.d:
```
if (++iter > 200)
{   assert(iter < iterationLimit);      // infinite loop check
    break;
}
```
*/

int f(int[] a, int u)
{
    return (a.ptr[u] < 0) ? u : (a.ptr[u] = f(a, a.ptr[u]));
}

void main()
{
    f([], 0);
    f([], 0);
}
