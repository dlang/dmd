// https://issues.dlang.org/show_bug.cgi?id=23217

typedef struct {
 int a,b,c;
} code;

const code array[2] = { {96,7,0}, {0,8,80} };
const code distfix[2] = { {22,5,193},{64,5,0} };
