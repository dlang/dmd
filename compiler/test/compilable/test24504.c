// REQUIRED_ARGS: -os=windows -g
// DISABLED: osx
// This is disabled on macOS because ld complains about _main being undefined
// when clang attempts to preprocess the C file.

typedef enum
{
    HasIntAndUIntValuesInt = 0,
    HasIntAndUIntValuesUInt = 0x80000000
} HasIntAndUIntValues;
