// EXTRA_SOURCES: imports/inline5_1.d
// EXTRA_FILES: imports/inline5_1.d imports/inline5_2.d
// REQUIRED_ARGS: -inline

// https://github.com/dlang/dmd/issues/23668

module inline5;

pragma(mangle, "dummyFunc") extern(D) void dummyFunc() {}

void parseMangledName(ref char[] result, const(char)[] buf) pure
{
    result ~= buf;
}

char[] reencodeMangled(return scope const(char)[] mangled) pure
{
    char[] result;
    parseMangledName(result, mangled);
    return result;
}
