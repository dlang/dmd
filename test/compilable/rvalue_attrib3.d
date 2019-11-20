// REQUIRED_ARGS: -preview=rvalueattribute

extern(C++) void func(@rvalue ref int);

version(Posix)
    static assert(func.mangleof == "_Z4funcOi");
else version (Win64)
    static assert(func.mangleof == "?func@@YAX$$QEAH@Z");
else version (Win32)
    static assert(func.mangleof == "?func@@YAX$$QAH@Z");
