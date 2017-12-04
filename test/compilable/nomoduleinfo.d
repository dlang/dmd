/* REQUIRED_ARGS: -Irunnable/extrafiles -nomoduleinfo
*/

version(Linux)
{
    extern(C) void _d_dso_registry();
}

extern(C) void main() { }
