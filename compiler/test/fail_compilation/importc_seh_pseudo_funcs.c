/* TEST_OUTPUT:
---
fail_compilation/importc_seh_pseudo_funcs.c(17): Error: undefined identifier `_exception_code`
fail_compilation/importc_seh_pseudo_funcs.c(17): Error: undefined identifier `_exception_info`
---
 */

// Deliberately unimplemented: the hardware-exception info they need isn't
// preserved by the time a fault becomes a catchable D exception.

int sehExceptionFilter(void *p, int code, void *info);

int f(void *p)
{
    __try {
        return 0;
    } __except( sehExceptionFilter(p, _exception_code(), _exception_info()) ) {
        return 1;
    }
}
