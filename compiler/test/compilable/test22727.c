// https://issues.dlang.org/show_bug.cgi?id=22727

int fooc(int a) { return a; }

__stdcall int foostdcall(int a) { return a; }

int __stdcall foostdcall2(int a) { return a; }

#if _MSC_VER
int _stdcall foostdcall3(int a) { return a; } // test issue 24509
#endif

int __stdcall (*fp1)(int a) = &foostdcall;

int (__stdcall *fp2)(int a) = &foostdcall2;
