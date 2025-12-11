#ifndef _MSC_VER
#include <complex.h>
#endif

void foo() {
#ifndef _MSC_VER
    double *a;
    double complex *b;
    double complex zden;
    double c, d;
    zden = c > d? b[0]: a[0];
#endif
}
