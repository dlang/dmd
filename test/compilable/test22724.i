// https://issues.dlang.org/show_bug.cgi?id=22724
// https://docs.microsoft.com/en-us/cpp/preprocessor/pragma-directives-and-the-pragma-keyword?view=msvc-170

__pragma(pack(push, 8))

typedef unsigned int size_t;

// https://issues.dlang.org/show_bug.cgi?id=23206

__declspec(noreturn) void abra(void);
