// REQUIRED_ARGS: -de -o-

int* gInt;

ref int* getTheIntPtr(string str = "Hello") {
    assert(str !is null);
    return gInt;
}

void unittest_() {
    int x;
    getTheIntPtr = &x;
    getTheIntPtr = null; // oops, assertion failure
}
