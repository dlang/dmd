// REQUIRED_ARGS: -betterC
// POST_SCRIPT: runnable/extra-files/test17868-postscript.sh ${RESULTS_DIR}/runnable/test17868.d.out.2
import core.stdc.stdio;

extern(C):

pragma(crt_constructor)
void init()
{
    puts("init");
}

pragma(crt_destructor)
void fini2()
{
    puts("fini");
}

pragma(crt_constructor)
void foo()
{
    puts("init");
}

pragma(crt_destructor)
void bar()
{
    puts("fini");
}

int main()
{
    puts("main");
    return 0;
}
