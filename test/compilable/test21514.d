// https://issues.dlang.org/show_bug.cgi?id=21514
// DISABLED: win32 win64

extern(C++) cdouble cpp_cadd1(cdouble c) { return c + 1; }
extern(C++) creal cpp_cadd1l(creal c) { return c + 1; }

cdouble cadd1(cdouble c) { return cpp_cadd1(c); }
creal cadd1(creal c) { return cpp_cadd1l(c); }
