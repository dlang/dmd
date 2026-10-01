// https://github.com/dlang/dmd/issues/18481
// Static array variadic parameters are value types, returning by value is safe

int[2] f1(int[2] arr...) { return arr; }
int*[2] f2(int*[2] arr...) { return arr; }
