// https://github.com/dlang/dmd/issues/20831
#include "assert.h"

int* p;

#define IMPL() \
f()\
{\
    assert(p);\
    assert(0);\
}

void IMPL()

void main(void) {}
