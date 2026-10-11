#include "test23605.h"
#include <stdio.h>

int lastDeleteA;

A::~A()
{
    printf("A::~A() %d\n", i); // printf is required to trigger the crash
    lastDeleteA = i;
}

void deleteFromCpp(A *obj)
{
    delete obj;
}
