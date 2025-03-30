
// https://issues.dlang.org/show_bug.cgi?id=22758

void foo(unsigned* aData){
    unsigned s = (aData[0]) & 1;
}
