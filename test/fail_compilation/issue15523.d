// DISABLED: osx
// REQUIRED_ARGS: -extern-std=c++98
/* TEST_OUTPUT:
---
fail_compilation/issue15523.d(9): Error: variable `issue15523.x` C++ `thread_local` variables are not supported in C++98 compatibiity mode
fail_compilation/issue15523.d(9):        use `-extern-std=c++11` or higher
---
*/
extern(C++) int x;
