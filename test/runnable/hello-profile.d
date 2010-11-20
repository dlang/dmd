// PERMUTE_ARGS: 
// REQUIRED_ARGS: -profile
// POST_SCRIPT: runnable/extra-files/hello-profile-postscript.sh

module hello;

extern(C)
{
    int printf(const char*, ...);
    int trace_setlogfilename(string name);
    int trace_setdeffilename(string name);
}

void showargs(char[][] args)
{
    printf("hello world\n");
    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
	printf("args[%d] = '%.*s'\n", i, args[i].length, args[i].ptr);
}

int main(char[][] args)
{
    trace_setlogfilename("test_results/runnable/hello-profile.d.trace.log");
    trace_setdeffilename("test_results/runnable/hello-profile.d.trace.def");

    showargs(args);

    return 0;
}

