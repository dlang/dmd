// DISABLED: win linux freebsd openbsd netbsd dragonflybsd hurd
// REQUIRED_ARGS: -os=linux
// If clang is invoked improperly as a preprocessor,
// then this will fail to compile and link due to `__check` being undefined.
// If clang is invoked properly as a preprocessor then this will succeed
// as clang won't attempt to compile nor link the file.

// https://github.com/dlang/dmd/issues/23356

int main(void)
{
    __check(1);
    return 0;
}
