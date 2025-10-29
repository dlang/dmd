// https://issues.dlang.org/show_bug.cgi?id=24419

typedef enum {
    #define R0 _RAX
    _RAX,
} reg;


int number = 5;
#define num number;


int function()
{
    return 9;
}
#define func function

//https://github.com/dlang/dmd/issues/20478
// similar issue

#define A 1
#define B A
#define C (A)
#define D (B)

//https://github.com/dlang/dmd/issues/20194

#define test_func(x, y) (x + y)
#define ABOLD test_func(2,5)
#define test test_func(5,4)
