/*
TEST_OUTPUT:
---
fail_compilation/cppvar.d(26): Error: variable `cppvar.funcLiteral` cannot have `extern(C++)` linkage because it is `static`
extern(C++) bool[3] funcLiteral = () { bool[3] a; return a; };
                    ^
fail_compilation/cppvar.d(26):        perhaps declare it as `__gshared` instead
fail_compilation/cppvar.d(28): Error: variable `cppvar.threadLocalVar` cannot have `extern(C++)` linkage because it is `static`
extern(C++) int threadLocalVar;
                ^
fail_compilation/cppvar.d(28):        perhaps declare it as `__gshared` instead
fail_compilation/cppvar.d(29): Error: variable `cppvar.staticVar` cannot have `extern(C++)` linkage because it is `static`
extern(C++) static int staticVar;
                       ^
fail_compilation/cppvar.d(29):        perhaps declare it as `__gshared` instead
fail_compilation/cppvar.d(30): Error: variable `cppvar.sharedVar` cannot have `extern(C++)` linkage because it is `shared`
extern(C++) shared int sharedVar;
                       ^
fail_compilation/cppvar.d(30):        perhaps declare it as `__gshared` instead
fail_compilation/cppvar.d(32): Error: delegate `cppvar.__lambda_L32_C46` cannot return type `bool[3]` because its linkage is `extern(C++)`
extern(C++) __gshared bool[3] gfuncLiteral = () { bool[3] a; return a; };
                                             ^
---
*/
// Line 10 starts here
extern(C++) bool[3] funcLiteral = () { bool[3] a; return a; };
// Line 20 starts here
extern(C++) int threadLocalVar;
extern(C++) static int staticVar;
extern(C++) shared int sharedVar;
// Line 30 starts here
extern(C++) __gshared bool[3] gfuncLiteral = () { bool[3] a; return a; };
