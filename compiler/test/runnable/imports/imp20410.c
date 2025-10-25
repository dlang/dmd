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
