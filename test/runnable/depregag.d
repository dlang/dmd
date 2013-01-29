// PERMUTE_ARGS: -dw
/* COMPILE_OUTPUT:
---
runnable/depregag.d(10): Deprecation: using * on an array is deprecated; use *(arr).ptr instead
---
*/
extern (C) int printf(char* msg, ...);
void main() {
    int[] arr;
    static if (is(typeof({ auto ptr = *arr; })))
        printf("*arr is still valid even if deprecated\n".dup.ptr);
    else
        assert(0, "*arr is not longer supported");
}
