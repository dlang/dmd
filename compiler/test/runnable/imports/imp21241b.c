// https://github.com/dlang/dmd/issues/21241
enum {bValue=2};
static int foo(void){
    return bValue;
}

int getB(void){
    return foo();
}
