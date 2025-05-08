// https://github.com/dlang/dmd/issues/21241
enum {aValue=1};
static int foo(void){
    return aValue;
}

int getA(void){
    return foo();
}
