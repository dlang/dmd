/*
TEST_OUTPUT:
---
fail_compilation/ice16575.d(17): Error: parameter `a` of the `extern(C++) ice16575.t11` function cannot be of type `char[]`
fail_compilation/ice16575.d(18): Error: parameter `a` of the `extern(C++) ice16575.t21` function cannot be of type `char[42]`
fail_compilation/ice16575.d(19): Error: parameter `a` of the `extern(C++) ice16575.t31` function cannot be of type `char[char]`
fail_compilation/ice16575.d(20): Error: parameter `a` of the `extern(C++) ice16575.t41` function cannot be of type `extern (C++) void delegate()`
fail_compilation/ice16575.d(21): Error: parameter of the `extern(C++) ice16575.t12` function cannot be of type `char[]`
fail_compilation/ice16575.d(22): Error: parameter of the `extern(C++) ice16575.t22` function cannot be of type `char[42]`
fail_compilation/ice16575.d(23): Error: parameter of the `extern(C++) ice16575.t32` function cannot be of type `char[char]`
fail_compilation/ice16575.d(24): Error: parameter of the `extern(C++) ice16575.t42` function cannot be of type `extern (C++) void delegate()`
---
*/

extern(C++)
{
    void t11(char[] a){}
    void t21(char[42] a){}
    void t31(char[char] a){}
    void t41(void delegate() a){}
    void t12(char[]){}
    void t22(char[42]){}
    void t32(char[char]){}
    void t42(void delegate()){}
}

void main() {}
