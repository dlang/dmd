// https://issues.dlang.org/show_bug.cgi?id=3004
// REQUIRED_ARGS: -ignore -v

extern(C) int printf(char*, ...);

pragma(GNU_attribute, flatten)
void test() { printf("Hello GNU world!\n".dup.ptr); }
