static __thread struct { int a; } var;

inline int* get(void)
{
    return &var.a;
}

inline void set(void)
{
    var.a = 0;
}
