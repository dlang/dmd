// https://issues.dlang.org/show_bug.cgi?id=22875

typedef union value_u {
    void *p;
} value_t;

typedef struct data_s {
    void *p;
} data_t;

void fn()
{
    value_t a;
    const value_t b;
    // Error: cannot implicitly convert expression `b` of type `const(value_u)` to `value_u`
    a = b;
    data_t aa;
    const data_t bb;
    // Error: cannot implicitly convert expression `bb` of type `const(data_s)` to `data_s`
    aa = bb;
}
