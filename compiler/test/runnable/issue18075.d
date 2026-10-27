/*
REQUIRED_ARGS: -checkaction=C -inline
PERMUTE_ARGS:
RUN_FAILS:
RUN_OUTPUT:
---
$r:.*check\(&x\) \|\| 3 - 3.*$
---
*/

// https://github.com/dlang/dmd/issues/18075

bool check(int* p) { return *p == 1; }

void main()
{
    int x;
    assert(check(&x) || 3 - 3);
}
