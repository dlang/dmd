// https://github.com/dlang/dmd/issues/20423
#include <stdarg.h>
#include <stddef.h>
#include <assert.h>

void foo(double * pm, ...) {
    va_list ap;
    double * targ;
    va_start(ap, pm);
    for (int i=1; ; i++) {
        va_arg(ap, int);
        targ = va_arg(ap, double*);
        if (targ == NULL) {
            break;
        }
    }
    va_end(ap);
}
