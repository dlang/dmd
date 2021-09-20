// https://issues.dlang.org/show_bug.cgi?id=22314

enum E {
    oldval __attribute__((deprecated)),
    newval
};
