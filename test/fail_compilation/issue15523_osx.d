// DISABLED: linux freebsd openbsd netbsd dragonflybsd solaris win32 win64
/* TEST_OUTPUT:
---
fail_compilation/issue15523_osx.d(7): Error: variable `issue15523_osx.x` C++ `thread_local` is unsupported for this target
---
*/
extern(C++) int x;
