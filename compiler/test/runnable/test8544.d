// EXECUTE_ARGS: foo bar doo
// PERMUTE_ARGS:
import core.stdc.string : strlen;
import core.runtime;

void main(string[] args)
{
    string[] dArgs = Runtime.args;
    CArgs cArgs = Runtime.cArgs;

    assert(dArgs.length && cArgs.argc);  // ensure we've passed some args
    assert(dArgs.length == cArgs.argc);

    const cArg = cArgs.argv[1][0 .. strlen(cArgs.argv[1])];
    assert(dArgs[1] == cArg);
    assert(args[1] == cArg);
}
