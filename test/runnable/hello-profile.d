// PERMUTE_ARGS:
// REQUIRED_ARGS: -profile
// POST_SCRIPT: runnable/extra-files/hello-profile-postscript.sh
// EXECUTE_ARGS: ${RESULTS_DIR}/runnable

module hello;

extern(C)
{
    int printf(const char*, ...);
    int trace_setlogfilename(string name);
    int trace_setdeffilename(string name);
}

void showargs(string[] args)
{
    printf("hello world\n");
    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
        printf("args[%d] = '%.*s'\n", i, args[i].length, args[i].ptr);
}

int main(string[] args)
{
    trace_setlogfilename(args[1] ~ "/hello-profile.d.trace.log");
    trace_setdeffilename(args[1] ~ "/hello-profile.d.trace.def");

    showargs(args);

    return 0;
}

