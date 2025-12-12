// DISABLED: win32 win64

#include <complex.h>

void foo() {
    double *a;
    double _Complex *b;
    double _Complex zden;
    double c, d;
    zden = c > d? b[0]: a[0];
}
