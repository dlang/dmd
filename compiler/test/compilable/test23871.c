// https://issues.dlang.org/show_bug.cgi?id=23871

extern void foo() __attribute((noreturn));

typedef void (*fp_t)();
extern void bar(fp_t __attribute((noreturn)));
