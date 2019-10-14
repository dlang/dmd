// REQUIRED_ARGS: -preview=rvaluetype

extern(C++) struct S
{
    this(@rvalue ref S);
}

version(Posix)
    static assert(S.__ctor.mangleof == "_ZN1SC2EOS_");
else version(Win32)
    static assert(S.__ctor.mangleof == "??0S@@QAE@$$QAU0@@Z");
else version(Win64)
    static assert(S.__ctor.mangleof == "??0S@@QEAA@$$QEAU0@@Z");
