module object;

private alias extern(C) int function(char[][] args) nothrow MainFunc;
private extern (C) int _d_run_main(int argc, char** argv, MainFunc mainFunc) nothrow
{
    return mainFunc(null);
}
