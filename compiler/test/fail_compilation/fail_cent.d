void main()
{
    cent c = cast(cent)1.5;
    float f = cast(float)c;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail_cent.d(3): Error: conversion between `double` and `cent` is not supported yet
fail_compilation/fail_cent.d(4): Error: conversion between `cent` and `float` is not supported yet
---
*/
